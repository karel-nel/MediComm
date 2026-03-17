module Sessions
  class Complete
    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      return { status: :skipped } if @intake_session.blank?

      outstanding = Fields::ComputeOutstanding.call(intake_session: @intake_session)
      completed = outstanding[:missing_fields].empty? && outstanding[:clarification_fields].empty?

      if completed
        @intake_session.update!(
          status: :awaiting_staff_review,
          completed_at: @intake_session.completed_at || Time.current
        )
      elsif @intake_session.status_active? || @intake_session.status_processing?
        @intake_session.update!(status: :awaiting_patient)
      end

      @intake_session.intake_events.create!(
        event_type: "session_state_recomputed",
        payload_json: {
          status: @intake_session.status,
          missing_fields_count: outstanding[:missing_fields].size,
          clarification_fields_count: outstanding[:clarification_fields].size
        }
      )

      { status: :ok, intake_session_id: @intake_session.id, intake_session_status: @intake_session.status }
    end
  end
end
