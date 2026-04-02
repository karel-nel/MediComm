class StoreAttachmentJob < ApplicationJob
  sidekiq_options queue: "media"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    attachment = IntakeAttachment.find(normalized_payload.fetch(:attachment_id))
    inline = ActiveModel::Type::Boolean.new.cast(normalized_payload[:inline])

    result = Attachments::StoreToS3.call(
      attachment_id: normalized_payload.fetch(:attachment_id),
      source_path: normalized_payload[:source_path],
      content_type: normalized_payload[:content_type]
    )

    if result[:status] == :ok
      attachment.intake_session.intake_events.create!(
        event_type: "attachment_stored_local",
        payload_json: {
          intake_attachment_id: attachment.id,
          storage_key: result[:s3_key].to_s,
          byte_size: attachment.byte_size
        }
      )

      next_payload = {
        attachment_id: attachment.id,
        inline: inline
      }

      if inline
        ExtractAttachmentTextJob.new.perform(next_payload)
      else
        ExtractAttachmentTextJob.perform_async(next_payload)
      end
    else
      attachment.update!(processing_status: "store_failed")

      attachment.intake_session.intake_events.create!(
        event_type: "attachment_store_failed",
        payload_json: {
          intake_attachment_id: attachment.id,
          error: result[:error].to_s.truncate(500)
        }
      )
    end
  end
end
