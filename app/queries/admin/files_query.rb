module Admin
  class FilesQuery
    attr_reader :practice, :params

    def initialize(practice:, params:)
      @practice = practice
      @params = params
    end

    def results
      scoped = practice.intake_attachments.includes(:intake_session, :intake_message)
      scoped = filter_search(scoped)
      scoped = filter_status(scoped)
      scoped.order(created_at: :desc)
    end

    private

    def filter_search(scope)
      return scope if params[:q].blank?

      term = "%#{params[:q].to_s.downcase.strip}%"
      scope.joins(:intake_session).where(
        "LOWER(intake_attachments.file_name) LIKE :term OR LOWER(intake_attachments.mime_type) LIKE :term OR LOWER(intake_sessions.patient_display_name) LIKE :term",
        term: term
      )
    end

    def filter_status(scope)
      return scope if params[:processing_status].blank?

      scope.where(processing_status: params[:processing_status])
    end
  end
end
