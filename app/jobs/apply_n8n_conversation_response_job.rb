class ApplyN8nConversationResponseJob < ApplicationJob
  sidekiq_options queue: "conversation"

  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    intake_session = IntakeSession.find(normalized_payload.fetch(:intake_session_id))
    Conversation::ApplyN8nResponse.call(
      intake_session: intake_session,
      payload: normalized_payload[:payload]
    )
  end
end
