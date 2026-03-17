module Sessions
  class Complete
    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      # TODO: Mark session complete based on resolved required fields and enqueue notifications.
      { status: :stubbed, intake_session_id: @intake_session&.id }
    end
  end
end
