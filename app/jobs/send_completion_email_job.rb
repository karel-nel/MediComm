class SendCompletionEmailJob < ApplicationJob
  queue_as :notifications

  # @param intake_session_id [Integer]
  def perform(intake_session_id:)
    Exports::BuildCompletionEmail.call(intake_session_id: intake_session_id)

    # TODO: deliver via ActionMailer once template + recipients are finalized.
  end
end
