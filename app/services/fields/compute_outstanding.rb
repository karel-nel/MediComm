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
      unresolved_field_keys = []

      flow_fields.each do |field|
        field_value = latest_values[field.id]

        if field_value.blank?
          unresolved_field_keys << field.key
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
          unresolved_field_keys << field.key
          clarification_fields << field.key
          missing_fields << field.key if field.required?
        when "missing", "rejected", "skipped"
          unresolved_field_keys << field.key
          missing_fields << field.key if field.required?
        else
          unresolved_field_keys << field.key
          missing_fields << field.key if field.required?
        end
      end

      allowed_next_asks = (clarification_fields + missing_fields).uniq
      next_ask_batches = build_next_ask_batches(
        flow_fields: flow_fields,
        allowed_next_asks: allowed_next_asks,
        unresolved_field_keys: unresolved_field_keys.uniq
      )

      {
        completed_fields: completed_fields,
        missing_fields: missing_fields.uniq,
        clarification_fields: clarification_fields.uniq,
        skipped_fields: Array(branch_state[:skipped_field_keys]),
        cluster_warnings: build_cluster_warnings(flow_fields),
        allowed_next_asks: allowed_next_asks,
        next_ask_batches: next_ask_batches,
        question_clusters: next_ask_batches
      }
    end

    private

    def build_next_ask_batches(flow_fields:, allowed_next_asks:, unresolved_field_keys:)
      return [] if allowed_next_asks.blank?

      field_by_key = flow_fields.index_by(&:key)
      field_position_by_key = flow_fields.map(&:key).each_with_index.to_h
      linked_graph = build_linked_graph(flow_fields)
      allowed_set = allowed_next_asks.to_set
      unresolved_set = unresolved_field_keys.to_set
      consumed_keys = Set.new

      allowed_next_asks.each_with_object([]) do |field_key, batches|
        next if consumed_keys.include?(field_key)

        field = field_by_key[field_key]
        next if field.blank?

        connected_keys = connected_component_for(field_key, linked_graph)
        batch_field_keys = connected_keys
          .select { |key| allowed_set.include?(key) || unresolved_set.include?(key) }
          .sort_by { |key| field_position_by_key[key] || 999_999 }
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

    def build_linked_graph(flow_fields)
      graph = Hash.new { |hash, key| hash[key] = Set.new }

      flow_fields.each do |field|
        graph[field.key]

        linked_field_keys_for(field).each do |linked_key|
          graph[field.key] << linked_key
          graph[linked_key] << field.key
        end
      end

      graph
    end

    def connected_component_for(start_key, graph)
      return [ start_key ] unless graph.key?(start_key)

      visited = Set.new
      queue = [ start_key ]

      until queue.empty?
        key = queue.shift
        next if visited.include?(key)

        visited << key
        queue.concat(graph[key].to_a)
      end

      visited.to_a
    end

    def build_cluster_warnings(flow_fields)
      field_by_key = flow_fields.index_by(&:key)
      warnings = []

      flow_fields.each do |field|
        field.linked_field_keys.each do |linked_key|
          linked_field = field_by_key[linked_key]

          if linked_field.blank?
            warnings << {
              type: "orphan_link",
              field_key: field.key,
              linked_field_key: linked_key,
              message: "#{field.key} links to #{linked_key}, but that field is not active in the current flow context."
            }
            next
          end

          next if linked_field.linked_field_keys.include?(field.key)

          warnings << {
            type: "one_way_link",
            field_key: field.key,
            linked_field_key: linked_key,
            message: "#{field.key} links to #{linked_key}, but #{linked_key} does not link back."
          }
        end
      end

      warnings.uniq
    end

    def linked_field_keys_for(field)
      field.linked_field_keys
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
