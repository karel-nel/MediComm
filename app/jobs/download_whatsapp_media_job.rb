class DownloadWhatsappMediaJob < ApplicationJob
  queue_as :media

  # @param attachment_id [Integer]
  def perform(attachment_id:)
    Attachments::DownloadFromMeta.call(attachment_id: attachment_id)

    # TODO: enqueue StoreAttachmentJob with returned temp artifact metadata.
  end
end
