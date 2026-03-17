class ExtractAttachmentTextJob < ApplicationJob
  sidekiq_options queue: "extraction"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    Attachments::RunExtraction.call(attachment_id: normalized_payload.fetch(:attachment_id))

    # TODO: emit extraction events and enqueue field candidate extraction.
  end
end
