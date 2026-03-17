module Conversation
  class GenerateReply
    def self.call(intake_session_id:)
      new(intake_session_id: intake_session_id).call
    end

    def initialize(intake_session_id:)
      @intake_session_id = intake_session_id
    end

    def call
      # TODO: Combine deterministic prompt context with AI phrasing service.
      {
        status: :stubbed,
        intake_session_id: @intake_session_id,
        reply_text: nil
      }
    end
  end
end
