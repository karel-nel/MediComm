module Whatsapp
  class PersistInboundMessage
    def self.call(intake_session:, message_data:, enqueue_attachment_jobs: true)
      new(
        intake_session: intake_session,
        message_data: message_data,
        enqueue_attachment_jobs: enqueue_attachment_jobs
      ).call
    end

    def initialize(intake_session:, message_data:, enqueue_attachment_jobs: true)
      @intake_session = intake_session
      @message_data = message_data
      @enqueue_attachment_jobs = enqueue_attachment_jobs
    end

    def call
      existing_message = IntakeMessage.find_by(provider_message_id: provider_message_id)
      return duplicate_result(existing_message) if existing_message

      message = nil
      created_attachments = []
      IntakeMessage.transaction do
        message = intake_session.intake_messages.create!(
          direction: :inbound,
          provider_message_id: provider_message_id,
          message_type: message_data[:message_type],
          text_body: message_data[:text_body].presence,
          created_at: message_data[:provider_timestamp],
          updated_at: message_data[:provider_timestamp]
        )

        intake_session.intake_events.create!(
          event_type: "inbound_message_persisted",
          payload_json: {
            intake_message_id: message.id,
            provider_message_id: provider_message_id,
            from_wa_id: message_data[:from_wa_id],
            patient_phone_e164: message_data[:patient_phone_e164],
            raw_change: message_data[:raw_change],
            raw_message: message_data[:raw_message]
          }
        )

        created_attachments = persist_attachments_for(message)
      end

      enqueue_attachment_downloads(created_attachments) if @enqueue_attachment_jobs

      { created: true, duplicate: false, message: message, attachments: created_attachments }
    end

    private

    attr_reader :intake_session, :message_data

    def duplicate_result(existing_message)
      intake_session.intake_events.create!(
        event_type: "inbound_message_duplicate",
        payload_json: {
          provider_message_id: provider_message_id,
          existing_intake_message_id: existing_message.id
        }
      )
      { created: false, duplicate: true, message: existing_message }
    end

    def provider_message_id
      message_data[:provider_message_id].to_s
    end

    def persist_attachments_for(message)
      Array(message_data[:attachments]).each_with_object([]) do |attachment_data, attachments|
        media_id = attachment_data[:media_id].to_s.strip
        next if media_id.blank?

        attachment = intake_session.intake_attachments.create!(
          intake_message: message,
          file_name: attachment_data[:file_name].to_s.presence || fallback_file_name(media_id: media_id),
          mime_type: attachment_data[:mime_type].to_s.presence || "application/octet-stream",
          byte_size: attachment_data[:byte_size],
          processing_status: "pending_download",
          s3_key: nil
        )

        intake_session.intake_events.create!(
          event_type: "inbound_attachment_persisted",
          payload_json: {
            intake_attachment_id: attachment.id,
            intake_message_id: message.id,
            provider_message_id: provider_message_id,
            media_id: media_id,
            media_type: attachment_data[:media_type].to_s,
            mime_type: attachment.mime_type
          }
        )

        attachments << { attachment: attachment, media_id: media_id }
      end
    end

    def enqueue_attachment_downloads(created_attachments)
      created_attachments.each do |record|
        DownloadWhatsappMediaJob.perform_async(
          {
            attachment_id: record.fetch(:attachment).id,
            media_id: record.fetch(:media_id),
            whatsapp_account_id: intake_session.whatsapp_account_id
          }
        )
      end
    end

    def fallback_file_name(media_id:)
      "media-#{media_id}.bin"
    end
  end
end
