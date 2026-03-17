require "test_helper"
require "sidekiq/testing"

class Api::V1::ConversationResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_bearer = ENV["N8N_BEARER_TOKEN"]
    ENV["N8N_BEARER_TOKEN"] = "n8n-test-token"
    Sidekiq::Testing.fake!
    ApplyN8nConversationResponseJob.clear

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
    @session = IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+27825608530",
      patient_display_name: "Karel Nel",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )
  end

  teardown do
    ENV["N8N_BEARER_TOKEN"] = @original_bearer
    ApplyN8nConversationResponseJob.clear
  end

  test "requires bearer authentication for conversation_response" do
    post conversation_response_api_v1_intake_session_path(@session), params: {
      source_message_id: "wamid.1",
      candidate_fields: [],
      reply: { text: "Hello" }
    }, as: :json

    assert_response :unauthorized
  end

  test "enqueues apply job for authorized n8n callback" do
    assert_difference -> { ApplyN8nConversationResponseJob.jobs.size }, 1 do
      post conversation_response_api_v1_intake_session_path(@session),
           params: {
             source_message_id: "wamid.1",
             candidate_fields: [
               { key: "patient_full_name", value: "Karel Nel", confidence: 0.97, source: "message_text" }
             ],
             reply: { text: "Thanks, please send your ID number." }
           },
           headers: auth_headers,
           as: :json
    end

    assert_response :accepted
  end

  private

  def auth_headers
    { "Authorization" => "Bearer n8n-test-token" }
  end
end
