module Sessions
  class FindOrCreate
    OPEN_STATUSES = %w[pending_start active awaiting_patient processing].freeze

    def self.call(parsed_event:)
      new(parsed_event: parsed_event).call
    end

    def initialize(parsed_event:)
      @parsed_event = parsed_event
    end

    def call
      inbound_message = inbound_messages.first
      return nil unless inbound_message

      whatsapp_account = find_whatsapp_account(inbound_message)
      return nil unless whatsapp_account

      practice = whatsapp_account.practice
      patient_phone_e164 = inbound_message[:patient_phone_e164]
      return nil if patient_phone_e164.blank?

      open_session = practice.intake_sessions
        .where(whatsapp_account: whatsapp_account, patient_phone_e164: patient_phone_e164, status: OPEN_STATUSES)
        .order(updated_at: :desc)
        .first
      return open_session if open_session

      flow = practice.intake_flows.status_published.order(published_at: :desc, created_at: :desc).first ||
        practice.intake_flows.order(created_at: :desc).first
      return nil unless flow

      initiator = pick_initiator(practice)
      return nil unless initiator

      practice.intake_sessions.create!(
        intake_flow: flow,
        whatsapp_account: whatsapp_account,
        initiated_by_user: initiator,
        patient_phone_e164: patient_phone_e164,
        patient_display_name: inbound_message[:patient_display_name].presence || patient_phone_e164,
        status: :active,
        language: flow.default_language,
        started_at: inbound_message[:provider_timestamp]
      )
    end

    private

    def inbound_messages
      @inbound_messages ||= Whatsapp::InboundEventExtractor.call(parsed_event: @parsed_event)
    end

    def find_whatsapp_account(inbound_message)
      account_id = @parsed_event[:whatsapp_account_id] || @parsed_event["whatsapp_account_id"]
      return WhatsappAccount.find_by(id: account_id) if account_id.present?

      WhatsappAccount.find_by(phone_number_id: inbound_message[:phone_number_id])
    end

    def pick_initiator(practice)
      practice.users.where(active: true, role: User.roles[:owner]).first ||
        practice.users.where(active: true, role: User.roles[:admin]).first ||
        practice.users.where(active: true).order(:id).first
    end
  end
end
