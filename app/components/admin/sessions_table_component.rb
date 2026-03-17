module Admin
  class SessionsTableComponent < ViewComponent::Base
    def initialize(sessions:)
      @sessions = sessions
    end

    private

    def confidence_bucket(session)
      confidences = latest_field_values_for(session).filter_map(&:confidence)
      return "missing" if confidences.empty?

      average = confidences.sum / confidences.length
      return "high" if average >= 0.85
      return "medium" if average >= 0.6

      "low"
    end

    def progress_ratio(session)
      required_fields = session.intake_flow.intake_fields.select(&:required)
      return 0.0 if required_fields.empty?

      latest = latest_field_values_for(session).index_by(&:intake_field_id)
      completed = required_fields.count { |field| latest[field.id]&.status_complete? }
      completed.to_f / required_fields.count
    end

    def progress_label(session)
      required_fields = session.intake_flow.intake_fields.select(&:required)
      return "No required fields" if required_fields.empty?

      latest = latest_field_values_for(session).index_by(&:intake_field_id)
      completed = required_fields.count { |field| latest[field.id]&.status_complete? }
      "#{completed}/#{required_fields.count}"
    end

    def missing_summary(session)
      required_fields = session.intake_flow.intake_fields.select(&:required)
      return "No required fields" if required_fields.empty?

      latest = latest_field_values_for(session).index_by(&:intake_field_id)
      missing_count = required_fields.count { |field| !latest[field.id]&.status_complete? }
      return "Complete" if missing_count.zero?

      "#{missing_count} missing"
    end

    def latest_field_values_for(session)
      session.intake_field_values.group_by(&:intake_field_id).values.map { |values| values.max_by(&:created_at) }
    end
  end
end
