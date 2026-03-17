module Admin
  class BillingSummary
    attr_reader :practice

    def initialize(practice:)
      @practice = practice
    end

    def plan_name
      "Growth"
    end

    def monthly_fee
      2499
    end

    def included_sessions
      300
    end

    def current_sessions
      practice.intake_sessions.where(created_at: Time.current.beginning_of_month..Time.current).count
    end

    def additional_sessions
      [ current_sessions - included_sessions, 0 ].max
    end

    def estimated_additional_cost
      additional_sessions * 6
    end

    def estimated_total
      monthly_fee + estimated_additional_cost
    end
  end
end
