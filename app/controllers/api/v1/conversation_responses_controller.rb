class Api::V1::ConversationResponsesController < Api::V1::BaseController
  before_action :set_intake_session

  def create
    ApplyN8nConversationResponseJob.perform_async(
      {
        intake_session_id: @intake_session.id,
        payload: conversation_response_payload
      }
    )

    render json: { status: "accepted" }, status: :accepted
  end

  private

  def set_intake_session
    @intake_session = IntakeSession.find(params[:id])
  end

  def conversation_response_payload
    raw_payload = params.to_unsafe_h
    nested_payload = raw_payload["conversation_response"] || raw_payload[:conversation_response]
    return nested_payload.to_h if nested_payload.present?

    raw_payload.except(
      "controller",
      "action",
      "id",
      "intake_session_id"
    )
  end
end
