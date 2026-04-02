class ExtractAttachmentTextJob < ApplicationJob
  sidekiq_options queue: "extraction"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    attachment = IntakeAttachment.find(normalized_payload.fetch(:attachment_id))
    result = Attachments::RunExtraction.call(attachment_id: attachment.id)
    inline = ActiveModel::Type::Boolean.new.cast(normalized_payload[:inline])

    if result[:status] == :ok
      attachment.update!(processing_status: "processed")

      attachment.intake_session.intake_events.create!(
        event_type: "attachment_extracted",
        payload_json: {
          intake_attachment_id: attachment.id,
          extracted_text_chars: result[:extracted_text].to_s.length,
          has_extracted_text: result[:extracted_text].present?
        }
      )

      if result[:extracted_text].present?
        next_payload = { intake_session_id: attachment.intake_session_id }

        if inline
          ExtractFieldCandidatesJob.new.perform(next_payload)
        else
          ExtractFieldCandidatesJob.perform_async(next_payload)
        end
      end
    else
      attachment.update!(processing_status: "extraction_failed")

      attachment.intake_session.intake_events.create!(
        event_type: "attachment_extraction_failed",
        payload_json: {
          intake_attachment_id: attachment.id,
          error: result[:error].to_s.truncate(500)
        }
      )
    end
  end
end
