module Conversation
  class BuildN8nRequest
    def self.call(intake_session:, source_message:)
      new(intake_session: intake_session, source_message: source_message).call
    end

    def initialize(intake_session:, source_message:)
      @intake_session = intake_session
      @source_message = source_message
    end

    def call
      {
        session_id: intake_session.id,
        practice_id: intake_session.practice_id,
        source_message_id: source_message.provider_message_id
      }
    end

    private

    attr_reader :intake_session, :source_message
  end
end
