class SendCompletionEmailJob < ApplicationJob
  sidekiq_options queue: "notifications"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    Exports::BuildCompletionEmail.call(intake_session_id: normalized_payload.fetch(:intake_session_id))

    # TODO: deliver via ActionMailer once template + recipients are finalized.
  end
end
