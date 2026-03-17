module Admin
  class FlowEditorPresenter
    GroupFields = Struct.new(:group, :fields, keyword_init: true)

    attr_reader :flow

    def initialize(flow:)
      @flow = flow
    end

    def completion_recipients_text
      Array(flow.completion_email_recipients_json).join(", ")
    end

    def grouped_fields
      fields = flow.intake_fields.includes(:intake_field_group).where(active: true)
      grouped = fields.group_by(&:intake_field_group)
      grouped.map do |group, fields|
        next if group&.archived?

        GroupFields.new(group: group, fields: fields.sort_by(&:ask_priority))
      end.compact.sort_by { |entry| [ entry.group&.position || 9_999, entry.group&.label.to_s ] }
    end

    def extraction_policy
      return "disabled" if flow.intake_fields.none?(&:extraction_enabled)
      return "enabled" if flow.intake_fields.all?(&:extraction_enabled)

      "mixed"
    end
  end
end
