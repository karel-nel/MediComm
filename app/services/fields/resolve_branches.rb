require "set"

module Fields
  class ResolveBranches
    TRUSTED_STATUSES = %w[complete inferred].freeze
    TRUE_VALUES = %w[true t yes y 1].freeze
    FALSE_VALUES = %w[false f no n 0].freeze

    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      flow_fields = active_flow_fields
      values_by_key = resolved_values_by_key(flow_fields)
      base_active_keys = visible_field_keys(flow_fields, values_by_key)
      branch_overrides = branch_visibility_overrides(flow_fields, values_by_key)

      active_keys = base_active_keys
        .merge(branch_overrides[:activate])
        .subtract(branch_overrides[:deactivate])

      skipped_keys = skipped_field_keys(flow_fields, active_keys: active_keys, values_by_key: values_by_key)
      active_keys.subtract(skipped_keys)

      active_fields = flow_fields.select { |field| active_keys.include?(field.key) }

      {
        active_fields: active_fields,
        active_field_ids: active_fields.map(&:id),
        active_field_keys: active_fields.map(&:key),
        skipped_field_keys: ordered_keys(flow_fields, skipped_keys),
        hidden_field_keys: ordered_keys(flow_fields, flow_fields.map(&:key).to_set - active_keys - skipped_keys)
      }
    end

    private

    def active_flow_fields
      @active_flow_fields ||= @intake_session.intake_flow
        .intake_fields
        .active
        .includes(:intake_field_group)
        .order(:ask_priority)
        .to_a
    end

    def resolved_values_by_key(flow_fields)
      return {} if flow_fields.blank?

      field_ids = flow_fields.map(&:id)
      field_key_by_id = flow_fields.index_by(&:id).transform_values(&:key)
      latest_by_field_id = {}

      @intake_session.intake_field_values
        .where(intake_field_id: field_ids, superseded_by_id: nil)
        .order(:created_at)
        .each do |field_value|
          latest_by_field_id[field_value.intake_field_id] = field_value
        end

      latest_by_field_id.each_with_object({}) do |(field_id, field_value), result|
        next unless TRUSTED_STATUSES.include?(field_value.status.to_s)

        value = field_value.canonical_value_text.to_s.strip
        key = field_key_by_id[field_id]
        result[key] = value if key.present? && value.present?
      end
    end

    def visible_field_keys(flow_fields, values_by_key)
      flow_fields.each_with_object(Set.new) do |field, active_keys|
        next unless group_visible?(field, values_by_key)
        next unless field_visible?(field, values_by_key)

        active_keys << field.key
      end
    end

    def group_visible?(field, values_by_key)
      group_rules = normalize_hash(field.intake_field_group&.visibility_rules_json)
      return true if group_rules.blank?

      evaluate_rule_set(group_rules, values_by_key)
    end

    def field_visible?(field, values_by_key)
      rules = normalize_hash(field.branching_rules_json)
      return true if rules.blank?

      if rules.key?("visible_if")
        evaluate_rule_set(rules["visible_if"], values_by_key)
      elsif rules.key?("hidden_if")
        !evaluate_rule_set(rules["hidden_if"], values_by_key)
      elsif rules.key?("conditions")
        evaluate_rule_set(rules, values_by_key)
      else
        true
      end
    end

    def branch_visibility_overrides(flow_fields, values_by_key)
      activate_keys = Set.new
      deactivate_keys = Set.new

      flow_fields.each do |field|
        rules = normalize_hash(field.branching_rules_json)
        on_complete_rules = normalize_action_rules(rules["on_complete"] || rules[:on_complete])

        on_complete_rules.each do |rule|
          condition = rule["if"] || rule[:if]
          matched = condition.blank? ? true : evaluate_rule_set(condition, values_by_key)
          actions = matched ? (rule["then"] || rule[:then]) : (rule["else"] || rule[:else])
          apply_actions(actions, activate_keys: activate_keys, deactivate_keys: deactivate_keys)
        end
      end

      {
        activate: activate_keys,
        deactivate: deactivate_keys
      }
    end

    def skipped_field_keys(flow_fields, active_keys:, values_by_key:)
      flow_fields.each_with_object(Set.new) do |field, skipped_keys|
        next unless active_keys.include?(field.key)
        next unless field_skip_applies?(field, values_by_key)

        skipped_keys << field.key
      end
    end

    def field_skip_applies?(field, values_by_key)
      rules = normalize_hash(field.skip_rules_json)
      return false if rules.blank?

      if rules.key?("skip_if")
        evaluate_conditions(
          conditions: normalize_conditions(rules["skip_if"]),
          operator: logical_operator(rules["operator"]),
          values_by_key: values_by_key
        )
      elsif rules.key?("if")
        evaluate_rule_set(rules["if"], values_by_key)
      elsif rules.key?("conditions")
        evaluate_rule_set(rules, values_by_key)
      else
        false
      end
    end

    def apply_actions(raw_actions, activate_keys:, deactivate_keys:)
      normalize_action_rules(raw_actions).each do |actions|
        action_map = normalize_hash(actions)
        next if action_map.blank?

        keys_for(action_map, "activate_field", "activate_fields", "show_field", "show_fields").each do |key|
          activate_keys << key
        end
        keys_for(action_map, "deactivate_field", "deactivate_fields", "hide_field", "hide_fields", "skip_field", "skip_fields").each do |key|
          deactivate_keys << key
        end
      end
    end

    def keys_for(action_map, *names)
      names.flat_map do |name|
        raw_value = action_map[name] || action_map[name.to_sym]
        normalize_field_key_list(raw_value)
      end
    end

    def normalize_action_rules(raw_actions)
      case raw_actions
      when nil
        []
      when Array
        raw_actions.filter_map { |item| item.respond_to?(:to_h) ? item.to_h : nil }
      when Hash
        [ raw_actions ]
      else
        []
      end
    end

    def evaluate_rule_set(rule_set, values_by_key)
      case rule_set
      when Array
        evaluate_conditions(
          conditions: normalize_conditions(rule_set),
          operator: :all,
          values_by_key: values_by_key
        )
      when Hash
        normalized = normalize_hash(rule_set)
        return false if normalized.blank?

        if condition_hash?(normalized)
          evaluate_condition(normalized, values_by_key)
        elsif normalized.key?("skip_if")
          evaluate_conditions(
            conditions: normalize_conditions(normalized["skip_if"]),
            operator: logical_operator(normalized["operator"]),
            values_by_key: values_by_key
          )
        elsif normalized.key?("conditions")
          evaluate_conditions(
            conditions: normalize_conditions(normalized["conditions"]),
            operator: logical_operator(normalized["operator"]),
            values_by_key: values_by_key
          )
        elsif normalized.key?("if")
          evaluate_rule_set(normalized["if"], values_by_key)
        else
          false
        end
      else
        false
      end
    end

    def evaluate_conditions(conditions:, operator:, values_by_key:)
      return true if conditions.empty?

      evaluations = conditions.map { |condition| evaluate_condition(condition, values_by_key) }
      operator == :any ? evaluations.any? : evaluations.all?
    end

    def evaluate_condition(condition, values_by_key)
      normalized = normalize_hash(condition)
      return false if normalized.blank?

      if normalized.key?("conditions") || normalized.key?("skip_if")
        return evaluate_rule_set(normalized, values_by_key)
      end

      field_key = normalized["field_key"].to_s
      return false if field_key.blank?

      operation = (normalized["op"] || normalized["operator"]).to_s.downcase.presence || "present"
      expected = normalized.key?("value") ? normalized["value"] : normalized["values"]
      actual = values_by_key[field_key]

      case operation
      when "present", "exists"
        actual.present?
      when "blank", "missing", "absent", "not_present"
        actual.blank?
      when "eq", "equals", "==", "is"
        compare_scalar(actual, expected)
      when "neq", "not_equals", "!=", "is_not"
        !compare_scalar(actual, expected)
      when "in"
        compare_list(expected).include?(normalize_text(actual))
      when "not_in"
        !compare_list(expected).include?(normalize_text(actual))
      when "contains"
        contains?(actual, expected)
      when "not_contains"
        !contains?(actual, expected)
      when "contains_any"
        contains_any?(actual, expected)
      when "not_contains_any"
        !contains_any?(actual, expected)
      when "starts_with"
        normalize_text(actual).start_with?(normalize_text(expected))
      when "ends_with"
        normalize_text(actual).end_with?(normalize_text(expected))
      when "true", "truthy", "yes"
        truthy_value?(actual)
      when "false", "falsy", "no"
        falsey_value?(actual)
      when "gt", ">"
        numeric_compare(actual, expected) == :gt
      when "gte", ">=", "at_least"
        [ :gt, :eq ].include?(numeric_compare(actual, expected))
      when "lt", "<"
        numeric_compare(actual, expected) == :lt
      when "lte", "<=", "at_most"
        [ :lt, :eq ].include?(numeric_compare(actual, expected))
      when "matches", "regex"
        regex_matches?(actual, expected)
      else
        false
      end
    end

    def compare_scalar(actual, expected)
      normalize_text(actual) == normalize_text(expected)
    end

    def contains?(actual, expected)
      needle = normalize_text(expected)
      return false if needle.blank?

      normalize_text(actual).include?(needle)
    end

    def contains_any?(actual, expected)
      haystack = normalize_text(actual)
      needles = compare_list(expected)
      return false if haystack.blank? || needles.empty?

      needles.any? { |needle| haystack.include?(needle) }
    end

    def regex_matches?(actual, expected)
      pattern = expected.to_s
      return false if pattern.blank?

      Regexp.new(pattern).match?(actual.to_s)
    rescue RegexpError
      false
    end

    def numeric_compare(actual, expected)
      actual_number = Float(actual.to_s)
      expected_number = Float(expected.to_s)
      return :eq if actual_number == expected_number
      return :gt if actual_number > expected_number

      :lt
    rescue ArgumentError, TypeError
      :invalid
    end

    def logical_operator(raw_operator)
      raw_operator.to_s.downcase == "any" ? :any : :all
    end

    def condition_hash?(value)
      return false unless value.is_a?(Hash)

      value.key?("field_key") || value.key?(:field_key)
    end

    def normalize_conditions(raw_conditions)
      Array(raw_conditions).filter_map do |condition|
        normalized = normalize_hash(condition)
        normalized.presence
      end
    end

    def normalize_field_key_list(raw_value)
      Array(raw_value)
        .map(&:to_s)
        .map(&:strip)
        .reject(&:blank?)
    end

    def compare_list(raw_value)
      Array(raw_value)
        .map { |value| normalize_text(value) }
        .reject(&:blank?)
    end

    def truthy_value?(value)
      normalized = normalize_text(value)
      return false if normalized.blank?
      return true if TRUE_VALUES.include?(normalized)
      return false if FALSE_VALUES.include?(normalized)

      ActiveModel::Type::Boolean.new.cast(value) == true
    end

    def falsey_value?(value)
      normalized = normalize_text(value)
      return false if normalized.blank?
      return true if FALSE_VALUES.include?(normalized)
      return false if TRUE_VALUES.include?(normalized)

      ActiveModel::Type::Boolean.new.cast(value) == false
    end

    def normalize_text(value)
      value.to_s.strip.downcase
    end

    def ordered_keys(flow_fields, keys_set)
      keys = keys_set.to_set
      flow_fields.filter_map do |field|
        field.key if keys.include?(field.key)
      end
    end

    def normalize_hash(value)
      value.respond_to?(:to_h) ? value.to_h.stringify_keys : {}
    end
  end
end
