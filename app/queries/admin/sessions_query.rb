module Admin
  class SessionsQuery
    attr_reader :practice, :params

    def initialize(practice:, params:)
      @practice = practice
      @params = params
    end

    def results
      scoped = base_scope
      scoped = filter_search(scoped)
      scoped = filter_status(scoped)
      scoped = filter_flow(scoped)
      scoped = filter_confidence(scoped)
      scoped
        .includes(
          :session_review,
          :initiated_by_user,
          :intake_field_values,
          intake_flow: :intake_fields
        )
        .order(updated_at: :desc)
    end

    private

    def base_scope
      practice.intake_sessions
    end

    def filter_search(scope)
      return scope if params[:q].blank?

      term = "%#{params[:q].to_s.strip.downcase}%"
      scope.where(
        "LOWER(patient_display_name) LIKE :term OR LOWER(patient_phone_e164) LIKE :term OR LOWER(COALESCE(external_reference, '')) LIKE :term",
        term: term
      )
    end

    def filter_status(scope)
      return scope if params[:status].blank?
      return scope unless IntakeSession.statuses.key?(params[:status].to_s)

      scope.where(status: IntakeSession.statuses.fetch(params[:status].to_s))
    end

    def filter_flow(scope)
      return scope if params[:flow_id].blank?

      scope.where(intake_flow_id: params[:flow_id])
    end

    def filter_confidence(scope)
      return scope if params[:confidence].blank?

      aggregated = scope.left_joins(:intake_field_values).group("intake_sessions.id")

      confidence = params[:confidence].to_s
      ids =
        if confidence == "high"
          aggregated.having("COALESCE(AVG(intake_field_values.confidence), 0) >= 0.85").pluck("intake_sessions.id")
        elsif confidence == "medium"
          aggregated.having("COALESCE(AVG(intake_field_values.confidence), 0) >= 0.6 AND COALESCE(AVG(intake_field_values.confidence), 0) < 0.85").pluck("intake_sessions.id")
        elsif confidence == "low"
          aggregated.having("COALESCE(AVG(intake_field_values.confidence), 0) < 0.6").pluck("intake_sessions.id")
        else
          return scope
        end

      scope.where(id: ids)
    end
  end
end
