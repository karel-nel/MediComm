class SendWhatsappMessageJob < ApplicationJob
  sidekiq_options queue: "conversation"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    Whatsapp::SendMessage.call(
      intake_session_id: normalized_payload.fetch(:intake_session_id),
      message_body: normalized_payload.fetch(:message_body)
    )
  end
end
