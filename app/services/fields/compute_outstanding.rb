module Fields
  class ComputeOutstanding
    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      flow_fields = @intake_session.intake_flow.intake_fields.active.order(:ask_priority)
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

      {
        completed_fields: completed_fields,
        missing_fields: missing_fields.uniq,
        clarification_fields: clarification_fields.uniq,
        allowed_next_asks: (clarification_fields + missing_fields).uniq
      }
    end

    private

    def latest_unsuperseded_values(flow_fields)
      scope = @intake_session.intake_field_values
        .where(intake_field_id: flow_fields.select(:id), superseded_by_id: nil)
        .order(:created_at)

      scope.each_with_object({}) do |value, acc|
        acc[value.intake_field_id] = value
      end
    end
  end
end
