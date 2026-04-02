require "test_helper"
require "sidekiq/testing"
require "securerandom"

class Whatsapp::PersistInboundMessageTest < ActiveSupport::TestCase
  setup do
    Sidekiq::Testing.fake!
    DownloadWhatsappMediaJob.clear
  end

  teardown do
    DownloadWhatsappMediaJob.clear
  end

  test "persists inbound attachments and enqueues download jobs" do
    context = build_session_context
    intake_session = context.fetch(:intake_session)

    message_data = {
      provider_message_id: "wamid.persist.#{SecureRandom.hex(4)}",
      message_type: "document",
      text_body: "",
      from_wa_id: "27825550123",
      patient_phone_e164: "+27825550123",
      patient_display_name: "Attachment Patient",
      provider_timestamp: Time.current,
      raw_change: {},
      raw_message: {},
      attachments: [
        {
          media_id: "meta-doc-attachment-001",
          media_type: "document",
          mime_type: "application/pdf",
          file_name: "id-copy.pdf",
          byte_size: 123_456
        }
      ]
    }

    result = Whatsapp::PersistInboundMessage.call(intake_session: intake_session, message_data: message_data)

    assert result[:created]
    assert_equal 1, intake_session.intake_messages.where(provider_message_id: message_data[:provider_message_id]).count
    assert_equal 1, intake_session.intake_attachments.where(file_name: "id-copy.pdf").count
    assert_equal 1, DownloadWhatsappMediaJob.jobs.size

    queued_payload = DownloadWhatsappMediaJob.jobs.first["args"].first
    assert_equal "meta-doc-attachment-001", queued_payload["media_id"]
  end

  test "does not enqueue duplicate downloads when provider message already exists" do
    context = build_session_context
    intake_session = context.fetch(:intake_session)

    message_data = {
      provider_message_id: "wamid.persist.duplicate",
      message_type: "image",
      text_body: "",
      from_wa_id: "27825550123",
      patient_phone_e164: "+27825550123",
      patient_display_name: "Attachment Patient",
      provider_timestamp: Time.current,
      raw_change: {},
      raw_message: {},
      attachments: [
        {
          media_id: "meta-image-dup-001",
          media_type: "image",
          mime_type: "image/jpeg",
          file_name: "front.jpg"
        }
      ]
    }

    first_result = Whatsapp::PersistInboundMessage.call(intake_session: intake_session, message_data: message_data)
    second_result = Whatsapp::PersistInboundMessage.call(intake_session: intake_session, message_data: message_data)

    assert first_result[:created]
    assert second_result[:duplicate]
    assert_equal 1, intake_session.intake_attachments.where(file_name: "front.jpg").count
    assert_equal 1, DownloadWhatsappMediaJob.jobs.size
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
      display_phone_number: "+27 69 123 0000",
      webhook_verify_token: "verify-#{suffix}",
      app_secret_ciphertext: "app-secret-#{suffix}",
      access_token_ciphertext: "access-token-#{suffix}",
      active: true
    )

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Persist Inbound #{suffix}",
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
      patient_phone_e164: "+2782#{rand(10_000_000).to_s.rjust(7, '0')}",
      patient_display_name: "Attachment Patient",
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
