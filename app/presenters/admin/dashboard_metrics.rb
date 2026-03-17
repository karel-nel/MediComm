module Admin
  class DashboardMetrics
    attr_reader :practice

    def initialize(practice:)
      @practice = practice
    end

    def total_sessions
      practice.intake_sessions.count
    end

    def awaiting_review_sessions
      practice.intake_sessions.status_awaiting_staff_review.count
    end

    def completed_sessions
      practice.intake_sessions.status_completed.count
    end

    def active_flows
      practice.intake_flows.status_published.count
    end

    def recent_queue(limit: 5)
      practice
        .intake_sessions
        .includes(:session_review, :intake_flow, :initiated_by_user, :intake_field_values)
        .order(updated_at: :desc)
        .limit(limit)
    end

    def recent_activity(limit: 6)
      IntakeEvent
        .joins(:intake_session)
        .where(intake_session: { practice_id: practice.id })
        .includes(:intake_session)
        .order(created_at: :desc)
        .limit(limit)
    end

    def channel_health
      account = practice.whatsapp_accounts.active.first
      return { status: "Disconnected", detail: "No active WhatsApp channel configured." } unless account

      { status: "Healthy", detail: "#{account.display_phone_number} connected" }
    end
  end
end
