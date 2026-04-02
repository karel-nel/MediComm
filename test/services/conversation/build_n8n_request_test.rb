require "test_helper"
require "securerandom"
require "base64"
require "fileutils"

class Conversation::BuildN8nRequestTest < ActiveSupport::TestCase
  test "includes stored attachment bytes as base64 in recent_attachments payload" do
    context = build_session_context
    intake_session = context.fetch(:intake_session)

    source_message = intake_session.intake_messages.create!(
      direction: :inbound,
      provider_message_id: "wamid.build.req.#{SecureRandom.hex(4)}",
      message_type: "document",
      text_body: nil
    )

    storage_root = Rails.root.join("tmp", "storage")
    relative_key = "intake_attachments/test/#{SecureRandom.hex(8)}.txt"
    absolute_path = storage_root.join(relative_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    file_bytes = "Attachment payload for n8n base64"
    File.binwrite(absolute_path, file_bytes)

    attachment = intake_session.intake_attachments.create!(
      intake_message: source_message,
      file_name: "proof.txt",
      mime_type: "text/plain",
      byte_size: file_bytes.bytesize,
      s3_key: File.join("tmp/storage", relative_key),
      processing_status: "processed"
    )

    payload = Conversation::BuildN8nRequest.call(
      intake_session: intake_session,
      source_message: source_message
    )

    encoded_attachment = payload[:recent_attachments].find { |entry| entry[:id] == attachment.id }
    assert_not_nil encoded_attachment
    assert_equal "base64", encoded_attachment[:content_encoding]
    assert_equal Base64.strict_encode64(file_bytes), encoded_attachment[:content_base64]
    assert_equal "included", encoded_attachment[:content_status]
    assert_nil encoded_attachment[:content_error]
  ensure
    FileUtils.rm_rf(Rails.root.join("tmp", "storage", "intake_attachments", "test"))
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
      display_phone_number: "+27 69 888 0000",
      webhook_verify_token: "verify-#{suffix}",
      app_secret_ciphertext: "app-secret-#{suffix}",
      access_token_ciphertext: "access-token-#{suffix}",
      active: true
    )

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Build n8n Request #{suffix}",
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
      patient_phone_e164: "+2786#{rand(10_000_000).to_s.rjust(7, '0')}",
      patient_display_name: "Build Request Test",
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
