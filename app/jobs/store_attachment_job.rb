class StoreAttachmentJob < ApplicationJob
  queue_as :media

  # @param attachment_id [Integer]
  # @param source_path [String, nil]
  def perform(attachment_id:, source_path: nil)
    Attachments::StoreToS3.call(attachment_id: attachment_id, source_path: source_path)

    # TODO: enqueue ExtractAttachmentTextJob after durable storage is confirmed.
  end
end
