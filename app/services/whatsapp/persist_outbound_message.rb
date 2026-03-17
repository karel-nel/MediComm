module Whatsapp
  class PersistOutboundMessage
    def self.call(intake_session:, reply_text:, provider_response:, source_message_id: nil)
      new(
        intake_session: intake_session,
        reply_text: reply_text,
        provider_response: provider_response,
        source_message_id: source_message_id
      ).call
    end

    def initialize(intake_session:, reply_text:, provider_response:, source_message_id: nil)
      @intake_session = intake_session
      @reply_text = reply_text
      @provider_response = provider_response || {}
      @source_message_id = source_message_id
    end

    def call
      intake_session.intake_messages.create!(
        direction: :outbound,
        provider_message_id: provider_response[:provider_message_id].presence,
        message_type: "text",
        text_body: reply_text
      ).tap do |message|
        intake_session.intake_events.create!(
          event_type: "outbound_message_persisted",
          payload_json: {
            intake_message_id: message.id,
            source_message_id: source_message_id,
            provider_response: provider_response
          }
        )
      end
    end

    private

    attr_reader :intake_session, :provider_response, :reply_text, :source_message_id
  end
end
