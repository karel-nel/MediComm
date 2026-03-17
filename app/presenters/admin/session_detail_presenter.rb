module Admin
  class SessionDetailPresenter
    FieldState = Struct.new(
      :field,
      :field_value,
      :value_text,
      :status,
      :confidence,
      :source_message,
      :source_attachment,
      keyword_init: true
    )

    GroupState = Struct.new(:group, :label, :fields, keyword_init: true)

    attr_reader :intake_session

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def progress_ratio
      return 0 if required_fields.empty?

      completed_required_fields.count.to_f / required_fields.count
    end

    def progress_percentage
      (progress_ratio * 100).round
    end

    def completion_label
      "#{completed_required_fields.count}/#{required_fields.count} required fields complete"
    end

    def missing_required_fields
      required_fields.reject { |field| latest_value_for(field)&.status_complete? }
    end

    def missing_summary
      return "No required fields missing" if missing_required_fields.empty?

      "#{missing_required_fields.count} required fields still missing"
    end

    def overall_confidence
      confidences = latest_values.values.filter_map(&:confidence)
      return nil if confidences.empty?

      confidences.sum / confidences.length
    end

    def field_groups
      grouped = intake_session
        .intake_flow
        .intake_fields
        .includes(:intake_field_group)
        .group_by(&:intake_field_group)

      grouped.map do |group, fields|
        GroupState.new(
          group: group,
          label: group&.label || "Ungrouped Fields",
          fields: fields.sort_by(&:ask_priority).map { |field| build_field_state(field) }
        )
      end.sort_by { |state| [ state.group&.position || 9999, state.label ] }
    end

    def messages
      intake_session.intake_messages
    end

    def attachments
      intake_session.intake_attachments
    end

    def events
      intake_session.intake_events
    end

    private

    def required_fields
      @required_fields ||= intake_session.intake_flow.intake_fields.select(&:required)
    end

    def completed_required_fields
      required_fields.select { |field| latest_value_for(field)&.status_complete? }
    end

    def latest_values
      @latest_values ||= intake_session
        .intake_field_values
        .group_by(&:intake_field_id)
        .transform_values { |values| values.max_by(&:created_at) }
    end

    def latest_value_for(field)
      latest_values[field.id]
    end

    def build_field_state(field)
      value = latest_value_for(field)
      FieldState.new(
        field: field,
        field_value: value,
        value_text: value&.canonical_value_text.presence || "Not captured yet",
        status: value&.status || "missing",
        confidence: value&.confidence,
        source_message: value&.source_message,
        source_attachment: value&.source_attachment
      )
    end
  end
end
