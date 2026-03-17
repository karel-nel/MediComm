class GenerateConversationReplyJob < ApplicationJob
  queue_as :conversation

  # @param intake_session_id [Integer]
  def perform(intake_session_id:)
    Conversation::GenerateReply.call(intake_session_id: intake_session_id)
  end
end
