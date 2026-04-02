class DownloadWhatsappMediaJob < ApplicationJob
  sidekiq_options queue: "media"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    attachment = IntakeAttachment.find(normalized_payload.fetch(:attachment_id))
    inline = ActiveModel::Type::Boolean.new.cast(normalized_payload[:inline])

    result = Attachments::DownloadFromMeta.call(
      attachment_id: attachment.id,
      media_id: normalized_payload[:media_id],
      whatsapp_account_id: normalized_payload[:whatsapp_account_id]
    )

    if result[:status] == :ok && result[:temp_path].present?
      attachment.update!(
        processing_status: "downloaded",
        byte_size: result[:byte_size] || attachment.byte_size
      )

      attachment.intake_session.intake_events.create!(
        event_type: "attachment_downloaded",
        payload_json: {
          intake_attachment_id: attachment.id,
          media_id: normalized_payload[:media_id].to_s,
          temp_path: result[:temp_path].to_s,
          byte_size: attachment.byte_size
        }
      )

      next_payload = {
        attachment_id: attachment.id,
        source_path: result[:temp_path],
        content_type: result[:content_type],
        inline: inline
      }

      if inline
        StoreAttachmentJob.new.perform(next_payload)
      else
        StoreAttachmentJob.perform_async(next_payload)
      end
    else
      attachment.update!(processing_status: "download_failed")

      attachment.intake_session.intake_events.create!(
        event_type: "attachment_download_failed",
        payload_json: {
          intake_attachment_id: attachment.id,
          media_id: normalized_payload[:media_id].to_s,
          error: result[:error].to_s.truncate(500)
        }
      )
    end
  end
end
