module Fields
  class ApplyCandidates
    def self.call(intake_session:, candidate_fields:, source_message: nil, applied_by: nil)
      new(
        intake_session: intake_session,
        candidate_fields: candidate_fields,
        source_message: source_message,
        applied_by: applied_by
      ).call
    end

    def initialize(intake_session:, candidate_fields:, source_message: nil, applied_by: nil)
      @intake_session = intake_session
      @candidate_fields = Array(candidate_fields)
      @source_message = source_message
      @applied_by = applied_by
    end

    def call
      flow_fields_by_key = @intake_session.intake_flow.intake_fields.active.index_by(&:key)
      rejected_keys = []
      applied_values = []

      IntakeFieldValue.transaction do
        @candidate_fields.each do |candidate|
          candidate_hash = candidate.respond_to?(:to_h) ? candidate.to_h : {}
          field_key = (candidate_hash[:key] || candidate_hash["key"]).to_s
          field = flow_fields_by_key[field_key]

          unless field
            rejected_keys << field_key
            next
          end

          normalized_value = (candidate_hash[:value] || candidate_hash["value"]).to_s.strip
          next if normalized_value.blank?

          confidence = normalize_confidence(candidate_hash[:confidence] || candidate_hash["confidence"])
          status = confidence >= 0.8 ? :complete : :candidate
          latest_value = latest_active_value(field)

          if latest_value&.canonical_value_text.to_s.strip == normalized_value &&
              latest_value&.status.to_s == status.to_s
            applied_values << latest_value
            next
          end

          new_value = @intake_session.intake_field_values.create!(
            intake_field: field,
            source_message: @source_message,
            canonical_value_text: normalized_value,
            status: status,
            confidence: confidence
          )

          latest_value&.update!(superseded_by: new_value)

          @intake_session.intake_events.create!(
            event_type: "field_candidate_applied",
            payload_json: {
              intake_field_id: field.id,
              intake_field_key: field.key,
              intake_field_value_id: new_value.id,
              source_message_id: @source_message&.provider_message_id,
              confidence: confidence,
              source: (candidate_hash[:source] || candidate_hash["source"]).presence || "n8n",
              applied_by: @applied_by
            }
          )

          applied_values << new_value
        end
      end

      {
        status: :ok,
        intake_session_id: @intake_session.id,
        applied_count: applied_values.size,
        rejected_keys: rejected_keys.uniq
      }
    end

    private

    def latest_active_value(field)
      @intake_session.intake_field_values
        .where(intake_field: field, superseded_by_id: nil)
        .order(created_at: :desc)
        .first
    end

    def normalize_confidence(raw_confidence)
      value = raw_confidence.to_f
      return 1.0 if value > 1.0
      return 0.0 if value < 0.0

      value
    end
  end
end
