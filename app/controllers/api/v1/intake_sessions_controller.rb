class Api::V1::IntakeSessionsController < Api::V1::BaseController
  before_action :set_intake_session

  def conversation_state
    state = Fields::ComputeOutstanding.call(intake_session: @intake_session)
    latest_message = @intake_session.intake_messages.reorder(created_at: :desc).first

    render json: {
      session: {
        id: @intake_session.id,
        status: @intake_session.status,
        patient_phone_e164: @intake_session.patient_phone_e164,
        language: @intake_session.language
      },
      flow: {
        id: @intake_session.intake_flow.id,
        name: @intake_session.intake_flow.name,
        tone_preset: @intake_session.intake_flow.tone_preset
      },
      state: {
        completed_fields: state[:completed_fields],
        missing_fields: state[:missing_fields],
        needs_clarification: state[:clarification_fields],
        allowed_next_asks: state[:allowed_next_asks]
      },
      latest_message: latest_message_payload(latest_message),
      recent_transcript: transcript_payload,
      instructions: {
        do_not_ask_completed_fields: true,
        do_not_change_business_rules: true,
        reply_naturally: true
      }
    }
  end

  private

  def set_intake_session
    @intake_session = IntakeSession
      .includes(:intake_flow)
      .find(params[:id])
  end

  def latest_message_payload(latest_message)
    return nil unless latest_message

    {
      provider_message_id: latest_message.provider_message_id,
      type: latest_message.message_type,
      text: latest_message.text_body
    }
  end

  def transcript_payload
    @intake_session.intake_messages
      .reorder(created_at: :desc)
      .limit(10)
      .reverse
      .map do |message|
        {
          direction: message.direction,
          type: message.message_type,
          text: message.text_body.to_s,
          provider_message_id: message.provider_message_id
        }
      end
  end
end
