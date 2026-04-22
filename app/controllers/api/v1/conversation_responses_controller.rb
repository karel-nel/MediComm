class Api::V1::ConversationResponsesController < Api::V1::BaseController
  before_action :set_intake_session

  def create
    payload = conversation_response_payload

    job_id = ApplyN8nConversationResponseJob.perform_async(
      {
        intake_session_id: @intake_session.id,
        payload: payload
      }
    )

    render json: {
      status: "accepted",
      accepted_at: Time.current.iso8601,
      intake_session_id: @intake_session.id,
      job: {
        id: job_id,
        queue: "conversation"
      },
      practice: {
        id: @intake_session.practice_id,
        name: @intake_session.practice.name,
        slug: @intake_session.practice.slug,
        timezone: @intake_session.practice.timezone
      },
      flow: {
        id: @intake_session.intake_flow.id,
        name: @intake_session.intake_flow.name,
        flow_type: @intake_session.intake_flow.flow_type,
        default_language: @intake_session.intake_flow.default_language,
        tone_preset: @intake_session.intake_flow.tone_preset,
        allow_skip_by_default: @intake_session.intake_flow.allow_skip_by_default
      },
      session: {
        id: @intake_session.id,
        status: @intake_session.status,
        language: @intake_session.language,
        patient_phone_e164: @intake_session.patient_phone_e164,
        patient_display_name: @intake_session.patient_display_name,
        external_reference: @intake_session.external_reference
      },
      received_payload: {
        source_message_id: payload["source_message_id"] || payload[:source_message_id],
        candidate_fields_count: Array(payload["candidate_fields"] || payload[:candidate_fields]).size,
        has_reply_text: payload.dig("reply", "text").present? || payload.dig(:reply, :text).present?
      },
      state: state_payload,
      callbacks: {
        conversation_state_path: "/api/v1/intake_sessions/#{@intake_session.id}/conversation_state",
        conversation_response_path: "/api/v1/intake_sessions/#{@intake_session.id}/conversation_response"
      }
    }, status: :accepted
  end

  private

  def set_intake_session
    @intake_session = IntakeSession
      .includes(:practice, :intake_flow)
      .find(params[:id])
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

  def state_payload
    state = Fields::ComputeOutstanding.call(intake_session: @intake_session)
    recommendation = Conversation::SelectNextAsk.call(intake_session: @intake_session)

    {
      completed_fields: state[:completed_fields],
      missing_fields: state[:missing_fields],
      needs_clarification: state[:clarification_fields],
      cluster_warnings: state[:cluster_warnings],
      allowed_next_asks: state[:allowed_next_asks],
      next_ask_batches: state[:next_ask_batches],
      question_clusters: state[:question_clusters],
      recommended_next_ask: recommendation,
      next_question_batch: next_question_batch_payload(recommendation)
    }
  end

  def next_question_batch_payload(recommendation)
    return nil if recommendation.blank?

    generated_reply = Conversation::GenerateReply.call(intake_session_id: @intake_session.id)

    {
      mode: recommendation[:mode],
      cluster_key: recommendation[:cluster_key],
      field_keys: Array(recommendation[:field_keys]),
      fields: Array(recommendation[:fields]),
      suggested_reply_text: generated_reply[:reply_text]
    }
  end
end
