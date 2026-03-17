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
      # TODO: Acquire row lock, append messages/events, and coordinate extraction/reply pipeline.
      { status: :stubbed, session_id: @session&.id }
    end
  end
end
