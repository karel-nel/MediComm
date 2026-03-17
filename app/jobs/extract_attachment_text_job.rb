class ExtractAttachmentTextJob < ApplicationJob
  queue_as :extraction

  # @param attachment_id [Integer]
  def perform(attachment_id:)
    Attachments::RunExtraction.call(attachment_id: attachment_id)

    # TODO: emit extraction events and enqueue field candidate extraction.
  end
end
