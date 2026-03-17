module Sessions
  class LockAndProcess
    def self.call(session:, parsed_event:)
      new(session: session, parsed_event: parsed_event).call
    end

    def initialize(session:, parsed_event:)
      @session = session
      @parsed_event = parsed_event
    end

    def call
      return { status: :skipped, reason: :missing_session } if @session.blank?

      relevant_messages = inbound_messages.select do |message|
        message[:phone_number_id].to_s == @session.whatsapp_account.phone_number_id.to_s &&
          message[:patient_phone_e164].to_s == @session.patient_phone_e164.to_s
      end
      return { status: :skipped, reason: :no_messages } if relevant_messages.empty?

      trigger_results = []

      @session.with_lock do
        relevant_messages.each do |message_data|
          persistence_result = Whatsapp::PersistInboundMessage.call(
            intake_session: @session,
            message_data: message_data
          )

          next if persistence_result[:duplicate]

          trigger_payload = Conversation::BuildN8nRequest.call(
            intake_session: @session,
            source_message: persistence_result[:message]
          )

          trigger_result = N8n::TriggerConversationAgent.call(
            payload: trigger_payload,
            intake_session: @session
          )

          @session.intake_events.create!(
            event_type: trigger_result[:status] == :ok ? "n8n_triggered" : "n8n_trigger_failed",
            payload_json: trigger_result.merge(source_message_id: persistence_result[:message].provider_message_id)
          )

          trigger_results << trigger_result
        end

        @session.update!(status: :active) if @session.status_pending_start?
      end

      { status: :processed, session_id: @session.id, triggers: trigger_results }
    end

    private

    def inbound_messages
      @inbound_messages ||= Whatsapp::InboundEventExtractor.call(parsed_event: @parsed_event)
    end
  end
end
