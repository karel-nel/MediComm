module Conversation
  class SelectNextAsk
    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      # TODO: Choose deterministic next question from outstanding fields + branch state.
      nil
    end
  end
end
