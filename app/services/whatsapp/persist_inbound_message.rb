module Whatsapp
  class PersistInboundMessage
    def self.call(intake_session:, message_data:)
      new(intake_session: intake_session, message_data: message_data).call
    end

    def initialize(intake_session:, message_data:)
      @intake_session = intake_session
      @message_data = message_data
    end

    def call
      existing_message = IntakeMessage.find_by(provider_message_id: provider_message_id)
      return duplicate_result(existing_message) if existing_message

      message = nil
      IntakeMessage.transaction do
        message = intake_session.intake_messages.create!(
          direction: :inbound,
          provider_message_id: provider_message_id,
          message_type: message_data[:message_type],
          text_body: message_data[:text_body].presence,
          created_at: message_data[:provider_timestamp],
          updated_at: message_data[:provider_timestamp]
        )

        intake_session.intake_events.create!(
          event_type: "inbound_message_persisted",
          payload_json: {
            intake_message_id: message.id,
            provider_message_id: provider_message_id,
            from_wa_id: message_data[:from_wa_id],
            patient_phone_e164: message_data[:patient_phone_e164],
            raw_change: message_data[:raw_change],
            raw_message: message_data[:raw_message]
          }
        )
      end

      { created: true, duplicate: false, message: message }
    end

    private

    attr_reader :intake_session, :message_data

    def duplicate_result(existing_message)
      intake_session.intake_events.create!(
        event_type: "inbound_message_duplicate",
        payload_json: {
          provider_message_id: provider_message_id,
          existing_intake_message_id: existing_message.id
        }
      )
      { created: false, duplicate: true, message: existing_message }
    end

    def provider_message_id
      message_data[:provider_message_id].to_s
    end
  end
end
