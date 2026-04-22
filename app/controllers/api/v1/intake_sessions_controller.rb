class Api::V1::IntakeSessionsController < Api::V1::BaseController
  before_action :set_intake_session

  def conversation_state
    state = Fields::ComputeOutstanding.call(intake_session: @intake_session)
    latest_message = @intake_session.intake_messages.reorder(created_at: :desc).first

    recommendation = Conversation::SelectNextAsk.call(intake_session: @intake_session)

    render json: {
      practice: {
        id: @intake_session.practice.id,
        name: @intake_session.practice.name,
        slug: @intake_session.practice.slug,
        timezone: @intake_session.practice.timezone,
        contact_email: @intake_session.practice.contact_email,
        status: @intake_session.practice.status
      },
      session: {
        id: @intake_session.id,
        status: @intake_session.status,
        patient_phone_e164: @intake_session.patient_phone_e164,
        patient_display_name: @intake_session.patient_display_name,
        external_reference: @intake_session.external_reference,
        language: @intake_session.language,
        started_at: @intake_session.started_at&.iso8601,
        completed_at: @intake_session.completed_at&.iso8601
      },
      flow: {
        id: @intake_session.intake_flow.id,
        name: @intake_session.intake_flow.name,
        flow_type: @intake_session.intake_flow.flow_type,
        status: @intake_session.intake_flow.status,
        default_language: @intake_session.intake_flow.default_language,
        tone_preset: @intake_session.intake_flow.tone_preset,
        allow_skip_by_default: @intake_session.intake_flow.allow_skip_by_default,
        completion_email_enabled: @intake_session.intake_flow.completion_email_enabled,
        completion_email_recipients: Array(@intake_session.intake_flow.completion_email_recipients_json)
      },
      state: {
        completed_fields: state[:completed_fields],
        missing_fields: state[:missing_fields],
        needs_clarification: state[:clarification_fields],
        cluster_warnings: state[:cluster_warnings],
        allowed_next_asks: state[:allowed_next_asks],
        next_ask_batches: state[:next_ask_batches],
        question_clusters: state[:question_clusters],
        recommended_next_ask: recommendation,
        next_question_batch: next_question_batch_payload(recommendation)
      },
      latest_message: latest_message_payload(latest_message),
      recent_transcript: transcript_payload,
      callbacks: {
        conversation_state_path: "/api/v1/intake_sessions/#{@intake_session.id}/conversation_state",
        conversation_response_path: "/api/v1/intake_sessions/#{@intake_session.id}/conversation_response"
      },
      instructions: {
        deterministic_rules_owned_by_rails: true,
        do_not_ask_completed_fields: true,
        ask_linked_fields_as_batch_when_available: true,
        prefer_clustered_questions: true,
        use_next_question_batch_as_source_of_truth: true,
        do_not_change_business_rules: true,
        reply_naturally: true
      }
    }
  end

  private

  def set_intake_session
    @intake_session = IntakeSession
      .includes(:practice, :intake_flow)
      .find(params[:id])
  end

  def latest_message_payload(latest_message)
    return nil unless latest_message

    {
      provider_message_id: latest_message.provider_message_id,
      type: latest_message.message_type,
      text: latest_message.text_body,
      direction: latest_message.direction,
      created_at: latest_message.created_at&.iso8601
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
          provider_message_id: message.provider_message_id,
          created_at: message.created_at&.iso8601
        }
      end
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
