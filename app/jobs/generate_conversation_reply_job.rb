class GenerateConversationReplyJob < ApplicationJob
  sidekiq_options queue: "conversation"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    Conversation::GenerateReply.call(intake_session_id: normalized_payload.fetch(:intake_session_id))
  end
end
