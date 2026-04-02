require "test_helper"
require "securerandom"
require "fileutils"

class Attachments::LocalStoragePipelineTest < ActiveSupport::TestCase
  test "stores attachment bytes to local storage and extracts text content" do
    context = build_session_context
    intake_session = context.fetch(:intake_session)

    intake_message = intake_session.intake_messages.create!(
      direction: :inbound,
      provider_message_id: "wamid.local.#{SecureRandom.hex(4)}",
      message_type: "document",
      text_body: nil
    )

    attachment = intake_session.intake_attachments.create!(
      intake_message: intake_message,
      file_name: "details.txt",
      mime_type: "text/plain",
      byte_size: nil,
      processing_status: "downloaded"
    )

    source_dir = Rails.root.join("tmp", "tests", "attachments")
    FileUtils.mkdir_p(source_dir)
    source_path = source_dir.join("source-#{attachment.id}.txt")
    File.write(source_path, "Patient note line one.\nPatient note line two.")

    store_result = Attachments::StoreToS3.call(
      attachment_id: attachment.id,
      source_path: source_path.to_s,
      content_type: "text/plain"
    )

    assert_equal :ok, store_result[:status]

    attachment.reload
    assert_equal "stored_local", attachment.processing_status
    assert attachment.s3_key.present?
    assert File.exist?(Rails.root.join(attachment.s3_key))
    assert_not File.exist?(source_path)

    extraction_result = Attachments::RunExtraction.call(attachment_id: attachment.id)
    assert_equal :ok, extraction_result[:status]
    assert_includes extraction_result[:extracted_text], "Patient note line one."
  ensure
    FileUtils.rm_rf(Rails.root.join("tmp", "tests", "attachments"))
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
      display_phone_number: "+27 69 321 0000",
      webhook_verify_token: "verify-#{suffix}",
      app_secret_ciphertext: "app-secret-#{suffix}",
      access_token_ciphertext: "access-token-#{suffix}",
      active: true
    )

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Local Storage Pipeline #{suffix}",
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
      patient_phone_e164: "+2784#{rand(10_000_000).to_s.rjust(7, '0')}",
      patient_display_name: "Local Storage Test",
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
