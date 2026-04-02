require "set"

module Fields
  class ComputeOutstanding
    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      branch_state = Fields::ResolveBranches.call(intake_session: @intake_session)
      flow_fields = Array(branch_state[:active_fields])
      latest_values = latest_unsuperseded_values(flow_fields)

      completed_fields = []
      missing_fields = []
      clarification_fields = []

      flow_fields.each do |field|
        field_value = latest_values[field.id]

        if field_value.blank?
          missing_fields << field.key if field.required?
          next
        end

        case field_value.status.to_s
        when "complete", "inferred"
          if field_value.canonical_value_text.present?
            completed_fields << {
              key: field.key,
              value: field_value.canonical_value_text,
              confidence: field_value.confidence.to_f,
              status: field_value.status
            }
          elsif field.required?
            missing_fields << field.key
          end
        when "needs_clarification", "candidate"
          clarification_fields << field.key
          missing_fields << field.key if field.required?
        when "missing", "rejected", "skipped"
          missing_fields << field.key if field.required?
        else
          missing_fields << field.key if field.required?
        end
      end

      allowed_next_asks = (clarification_fields + missing_fields).uniq

      {
        completed_fields: completed_fields,
        missing_fields: missing_fields.uniq,
        clarification_fields: clarification_fields.uniq,
        skipped_fields: Array(branch_state[:skipped_field_keys]),
        allowed_next_asks: allowed_next_asks,
        next_ask_batches: build_next_ask_batches(flow_fields: flow_fields, allowed_next_asks: allowed_next_asks)
      }
    end

    private

    def build_next_ask_batches(flow_fields:, allowed_next_asks:)
      return [] if allowed_next_asks.blank?

      field_by_key = flow_fields.index_by(&:key)
      allowed_set = allowed_next_asks.to_set
      consumed_keys = Set.new

      allowed_next_asks.each_with_object([]) do |field_key, batches|
        next if consumed_keys.include?(field_key)

        field = field_by_key[field_key]
        next if field.blank?

        linked_keys = linked_field_keys_for(field)
        batch_field_keys = ([ field_key ] + linked_keys)
          .uniq
          .select { |key| allowed_set.include?(key) }
        batch_field_keys = [ field_key ] if batch_field_keys.empty?

        consumed_keys.merge(batch_field_keys)

        batches << {
          batch_key: batch_field_keys.first,
          group_key: field.intake_field_group&.key,
          group_label: field.intake_field_group&.label,
          field_keys: batch_field_keys,
          fields: batch_field_keys.filter_map do |key|
            linked_field = field_by_key[key]
            next if linked_field.blank?

            {
              key: linked_field.key,
              label: linked_field.label,
              field_type: linked_field.field_type,
              required: linked_field.required
            }
          end
        }
      end
    end

    def linked_field_keys_for(field)
      rules = field.branching_rules_json.presence || {}
      raw_keys = rules["linked_field_keys"] || rules[:linked_field_keys] || []
      Array(raw_keys).map(&:to_s).reject(&:blank?)
    end

    def latest_unsuperseded_values(flow_fields)
      field_ids = flow_fields.map(&:id)
      return {} if field_ids.empty?

      scope = @intake_session.intake_field_values
        .where(intake_field_id: field_ids, superseded_by_id: nil)
        .order(:created_at)

      scope.each_with_object({}) do |value, acc|
        acc[value.intake_field_id] = value
      end
    end
  end
end
