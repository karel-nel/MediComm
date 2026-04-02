require "test_helper"
require "sidekiq/testing"
require "securerandom"

class AttachmentPipelineJobsTest < ActiveSupport::TestCase
  setup do
    Sidekiq::Testing.fake!
    StoreAttachmentJob.clear
    ExtractAttachmentTextJob.clear
    ExtractFieldCandidatesJob.clear
  end

  teardown do
    StoreAttachmentJob.clear
    ExtractAttachmentTextJob.clear
    ExtractFieldCandidatesJob.clear
  end

  test "download store and extract jobs chain with local storage mode" do
    context = build_session_context
    intake_session = context.fetch(:intake_session)

    intake_message = intake_session.intake_messages.create!(
      direction: :inbound,
      provider_message_id: "wamid.pipeline.#{SecureRandom.hex(4)}",
      message_type: "document",
      text_body: nil
    )
    attachment = intake_session.intake_attachments.create!(
      intake_message: intake_message,
      file_name: "pipeline-note.txt",
      mime_type: "text/plain",
      processing_status: "pending_download"
    )

    DownloadWhatsappMediaJob.new.perform(
      {
        attachment_id: attachment.id,
        media_id: "meta-pipeline-001",
        whatsapp_account_id: intake_session.whatsapp_account_id
      }
    )

    attachment.reload
    assert_equal "downloaded", attachment.processing_status
    assert_equal 1, StoreAttachmentJob.jobs.size

    StoreAttachmentJob.new.perform(StoreAttachmentJob.jobs.first["args"].first)
    attachment.reload
    assert_equal "stored_local", attachment.processing_status
    assert attachment.s3_key.present?
    assert_equal 1, ExtractAttachmentTextJob.jobs.size

    ExtractAttachmentTextJob.new.perform(ExtractAttachmentTextJob.jobs.first["args"].first)
    attachment.reload
    assert_equal "processed", attachment.processing_status
    assert_equal 1, ExtractFieldCandidatesJob.jobs.size
  end

  private

  def build_session_context
    practice = practices(:one)
    user = users(:one)
    suffix = SecureRandom.hex(6)

    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "phone-#{suffix}",
      waba_id: "waba-#{suffix}",
      display_phone_number: "+27 69 654 0000",
      webhook_verify_token: "verify-#{suffix}",
      app_secret_ciphertext: "app-secret-#{suffix}",
      access_token_ciphertext: "access-token-#{suffix}",
      active: true
    )

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Attachment Pipeline #{suffix}",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )

    intake_session = IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+2785#{rand(10_000_000).to_s.rjust(7, '0')}",
      patient_display_name: "Pipeline Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )

    {
      practice: practice,
      user: user,
      account: account,
      flow: flow,
      intake_session: intake_session
    }
  end
end
