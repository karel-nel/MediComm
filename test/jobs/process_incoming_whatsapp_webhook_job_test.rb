require "test_helper"

class ProcessIncomingWhatsappWebhookJobTest < ActiveSupport::TestCase
  test "persists inbound message once and skips duplicate provider message ids" do
    practice = practices(:one)
    user = users(:one)
    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "948579418347281",
      waba_id: "waba-test-001",
      display_phone_number: "+27 69 043 2908",
      webhook_verify_token: "verify-token-abc",
      app_secret_ciphertext: "app-secret-abc",
      access_token_ciphertext: "access-token-abc",
      active: true
    )
    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "New Patient Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )
    IntakeField.create!(
      intake_flow: flow,
      key: "patient_full_name",
      label: "Patient Full Name",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )

    parsed_event = {
      provider: "whatsapp_cloud_api",
      received_at: Time.current.iso8601,
      whatsapp_account_id: account.id,
      entries: [
        {
          "changes" => [
            {
              "field" => "messages",
              "value" => {
                "metadata" => {
                  "display_phone_number" => "27690432908",
                  "phone_number_id" => "948579418347281"
                },
                "contacts" => [ { "profile" => { "name" => "Karel Nel" } } ],
                "messages" => [
                  {
                    "from" => "27825608530",
                    "id" => "wamid.HBgLMjc4MjU2MDg1MzAVAgASGBYzRUIwRThGQjk1RDNCRTY1NEU1NzNBAA==",
                    "timestamp" => "1773753464",
                    "text" => { "body" => "hello" },
                    "type" => "text"
                  }
                ]
              }
            }
          ]
        }
      ]
    }

    trigger_calls = 0
    stubbed_trigger = lambda do |payload:, intake_session:|
      trigger_calls += 1
      { status: :ok, payload: payload, session_id: intake_session.id }
    end

    with_class_method_stub(N8n::TriggerConversationAgent, :call, stubbed_trigger) do
      ProcessIncomingWhatsappWebhookJob.new.perform(parsed_event)
      ProcessIncomingWhatsappWebhookJob.new.perform(parsed_event)
    end

    assert_equal 1, IntakeMessage.where(provider_message_id: "wamid.HBgLMjc4MjU2MDg1MzAVAgASGBYzRUIwRThGQjk1RDNCRTY1NEU1NzNBAA==").count
    assert_equal 1, trigger_calls
  end

  private

  def with_class_method_stub(klass, method_name, callable)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name, callable)
    yield
  ensure
    klass.define_singleton_method(method_name, original)
  end
end
