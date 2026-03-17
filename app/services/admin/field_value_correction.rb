module Admin
  class FieldValueCorrection
    attr_reader :intake_session, :field_value, :reviewer, :params

    def initialize(intake_session:, field_value:, reviewer:, params:)
      @intake_session = intake_session
      @field_value = field_value
      @reviewer = reviewer
      @params = params
    end

    def call
      ActiveRecord::Base.transaction do
        corrected = intake_session.intake_field_values.create!(
          intake_field: field_value.intake_field,
          source_message: field_value.source_message,
          source_attachment: field_value.source_attachment,
          canonical_value_text: params[:canonical_value_text],
          status: params[:status],
          confidence: field_value.confidence,
          verified_by_user: verified? ? reviewer : nil
        )

        field_value.update!(superseded_by: corrected)

        IntakeEvent.create!(
          intake_session: intake_session,
          event_type: "field_value_corrected",
          payload_json: {
            intake_field_id: field_value.intake_field_id,
            previous_value_id: field_value.id,
            corrected_value_id: corrected.id,
            corrected_by_user_id: reviewer.id,
            corrected_at: Time.current.iso8601
          }
        )

        corrected
      end
    end

    private

    def verified?
      ActiveModel::Type::Boolean.new.cast(params[:verified])
    end
  end
end
