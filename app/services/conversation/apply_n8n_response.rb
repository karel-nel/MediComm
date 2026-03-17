module Conversation
  class ApplyN8nResponse
    FALLBACK_REPLY = "Thank you, we received your message and will continue shortly.".freeze
    MAX_REPLY_LENGTH = 1_000

    def self.call(intake_session:, payload:)
      new(intake_session: intake_session, payload: payload).call
    end

    def initialize(intake_session:, payload:)
      @intake_session = intake_session
      @payload = payload || {}
    end

    def call
      source_message_id = source_message_id_from_payload
      return duplicate_result if duplicate_response?(source_message_id)

      source_message = source_message_id.present? ? @intake_session.intake_messages.find_by(provider_message_id: source_message_id) : nil

      apply_result = Fields::ApplyCandidates.call(
        intake_session: @intake_session,
        candidate_fields: Array(@payload["candidate_fields"] || @payload[:candidate_fields]),
        source_message: source_message,
        applied_by: "n8n"
      )

      reply_text = validate_reply_text(@payload.dig("reply", "text") || @payload.dig(:reply, :text))
      send_result = Whatsapp::SendMessage.call(intake_session_id: @intake_session.id, message_body: reply_text)

      outbound_message = Whatsapp::PersistOutboundMessage.call(
        intake_session: @intake_session,
        reply_text: reply_text,
        provider_response: send_result,
        source_message_id: source_message_id
      )

      Sessions::Complete.call(intake_session: @intake_session)

      @intake_session.intake_events.create!(
        event_type: "n8n_response_applied",
        payload_json: {
          source_message_id: source_message_id,
          applied_count: apply_result[:applied_count],
          rejected_keys: apply_result[:rejected_keys],
          outbound_message_id: outbound_message.id,
          send_status: send_result[:status]
        }
      )

      {
        status: :ok,
        intake_session_id: @intake_session.id,
        applied_count: apply_result[:applied_count],
        outbound_message_id: outbound_message.id,
        send_status: send_result[:status]
      }
    end

    private

    def source_message_id_from_payload
      (@payload["source_message_id"] || @payload[:source_message_id]).to_s.presence
    end

    def duplicate_response?(source_message_id)
      return false if source_message_id.blank?

      @intake_session.intake_events.where(event_type: "n8n_response_applied")
        .where("payload_json ->> 'source_message_id' = ?", source_message_id)
        .exists?
    end

    def duplicate_result
      { status: :duplicate, intake_session_id: @intake_session.id }
    end

    def validate_reply_text(raw_reply_text)
      text = raw_reply_text.to_s.strip
      text = FALLBACK_REPLY if text.blank?
      text = text.truncate(MAX_REPLY_LENGTH)
      text
    end
  end
end
