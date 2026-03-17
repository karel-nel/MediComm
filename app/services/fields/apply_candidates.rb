module Fields
  class ApplyCandidates
    def self.call(intake_session_id:)
      new(intake_session_id: intake_session_id).call
    end

    def initialize(intake_session_id:)
      @intake_session_id = intake_session_id
    end

    def call
      # TODO: Upsert IntakeFieldValue candidates, supersede stale values, emit audit events.
      { status: :stubbed, intake_session_id: @intake_session_id }
    end
  end
end
