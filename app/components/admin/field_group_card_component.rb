module Admin
  class FieldGroupCardComponent < ViewComponent::Base
    def initialize(group_state:, intake_session:)
      @group_state = group_state
      @intake_session = intake_session
    end

    private

    def confidence_bucket(confidence)
      return "missing" if confidence.nil?
      return "high" if confidence >= 0.85
      return "medium" if confidence >= 0.6

      "low"
    end

    def editable?(field_state)
      field_state.field_value.present?
    end
  end
end
