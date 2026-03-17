module Whatsapp
  class SendMessage
    def self.call(intake_session_id:, message_body:)
      new(intake_session_id: intake_session_id, message_body: message_body).call
    end

    def initialize(intake_session_id:, message_body:)
      @intake_session_id = intake_session_id
      @message_body = message_body
    end

    def call
      # TODO: Integrate with WhatsApp Cloud API outbound send endpoint.
      {
        status: :stubbed,
        intake_session_id: @intake_session_id,
        message_preview: @message_body.to_s.truncate(80),
        provider_message_id: nil
      }
    end
  end
end
