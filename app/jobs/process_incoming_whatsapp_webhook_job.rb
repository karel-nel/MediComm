class ProcessIncomingWhatsappWebhookJob < ApplicationJob
  queue_as :webhooks

  # @param parsed_event [Hash] normalized payload from Whatsapp::WebhookParser
  def perform(parsed_event:)
    session = Sessions::FindOrCreate.call(parsed_event: parsed_event)
    Sessions::LockAndProcess.call(session: session, parsed_event: parsed_event)

    # TODO: fan out media download / field extraction jobs once parsing and routing are real.
  end
end
