class SendWhatsappMessageJob < ApplicationJob
  queue_as :conversation

  # @param intake_session_id [Integer]
  # @param message_body [String]
  def perform(intake_session_id:, message_body:)
    Whatsapp::SendMessage.call(intake_session_id: intake_session_id, message_body: message_body)
  end
end
