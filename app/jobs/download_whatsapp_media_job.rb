class DownloadWhatsappMediaJob < ApplicationJob
  sidekiq_options queue: "media"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    Attachments::DownloadFromMeta.call(attachment_id: normalized_payload.fetch(:attachment_id))

    # TODO: enqueue StoreAttachmentJob with returned temp artifact metadata.
  end
end
