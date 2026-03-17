class StoreAttachmentJob < ApplicationJob
  sidekiq_options queue: "media"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    Attachments::StoreToS3.call(
      attachment_id: normalized_payload.fetch(:attachment_id),
      source_path: normalized_payload[:source_path]
    )

    # TODO: enqueue ExtractAttachmentTextJob after durable storage is confirmed.
  end
end
