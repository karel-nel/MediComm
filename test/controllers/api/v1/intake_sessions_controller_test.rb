require "test_helper"

class Api::V1::IntakeSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_bearer = ENV["N8N_BEARER_TOKEN"]
    ENV["N8N_BEARER_TOKEN"] = "n8n-test-token"

    @practice = practices(:one)
    @user = users(:one)
    @account = WhatsappAccount.create!(
      practice: @practice,
      phone_number_id: "948579418347281",
      waba_id: "waba-test-001",
      display_phone_number: "+27 69 043 2908",
      webhook_verify_token: "verify-token-abc",
      app_secret_ciphertext: "app-secret-abc",
      access_token_ciphertext: "access-token-abc",
      active: true
    )
    @flow = IntakeFlow.create!(
      practice: @practice,
      created_by: @user,
      name: "New Patient Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )
    @required_field = IntakeField.create!(
      intake_flow: @flow,
      key: "patient_full_name",
      label: "Patient Full Name",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    @missing_field = IntakeField.create!(
      intake_flow: @flow,
      key: "patient_id_number",
      label: "Patient ID Number",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    @session = IntakeSession.create!(
      practice: @practice,
      intake_flow: @flow,
      whatsapp_account: @account,
      initiated_by_user: @user,
      patient_phone_e164: "+27825608530",
      patient_display_name: "Karel Nel",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )
    @session.intake_messages.create!(
      direction: :inbound,
      provider_message_id: "wamid.123",
      message_type: "text",
      text_body: "hello"
    )
    @session.intake_field_values.create!(
      intake_field: @required_field,
      canonical_value_text: "Karel Nel",
      status: :complete,
      confidence: 0.98
    )
  end

  teardown do
    ENV["N8N_BEARER_TOKEN"] = @original_bearer
  end

  test "requires bearer authentication for conversation_state" do
    get conversation_state_api_v1_intake_session_path(@session)
    assert_response :unauthorized
  end

  test "returns conversation_state payload for authorized n8n caller" do
    get conversation_state_api_v1_intake_session_path(@session), headers: auth_headers

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @session.id, json.dig("session", "id")
    assert_equal @flow.name, json.dig("flow", "name")
    assert_includes json.dig("state", "missing_fields"), "patient_id_number"
    assert_equal "hello", json.dig("latest_message", "text")
  end

  private

  def auth_headers
    { "Authorization" => "Bearer n8n-test-token" }
  end
end
