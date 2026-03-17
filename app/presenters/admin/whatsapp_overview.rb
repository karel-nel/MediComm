module Admin
  class WhatsappOverview
    attr_reader :practice

    def initialize(practice:)
      @practice = practice
    end

    def accounts
      practice.whatsapp_accounts.order(:created_at)
    end

    def active_account
      accounts.find(&:active?)
    end

    def health_label
      active_account.present? ? "Healthy" : "Disconnected"
    end

    def status_note
      return "No active WhatsApp account configured for this practice." unless active_account

      "Connected as #{active_account.display_phone_number} (#{active_account.business_account_name})"
    end

    def recent_session_count
      practice.intake_sessions.where(created_at: 24.hours.ago..Time.current).count
    end
  end
end
