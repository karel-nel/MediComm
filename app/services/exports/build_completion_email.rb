module Exports
  class BuildCompletionEmail
    def self.call(intake_session_id:)
      new(intake_session_id: intake_session_id).call
    end

    def initialize(intake_session_id:)
      @intake_session_id = intake_session_id
    end

    def call
      # TODO: Build structured completion summary payload for mailer delivery.
      {
        status: :stubbed,
        intake_session_id: @intake_session_id,
        subject: nil,
        body: nil
      }
    end
  end
end
