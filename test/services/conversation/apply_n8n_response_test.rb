require "test_helper"

class Conversation::ApplyN8nResponseTest < ActiveSupport::TestCase
  test "applies valid candidate fields, persists outbound message, and audits response" do
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
    valid_field = IntakeField.create!(
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
    IntakeField.create!(
      intake_flow: flow,
      key: "patient_id_number",
      label: "Patient ID Number",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    session = IntakeSession.create!(
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
    source_message = session.intake_messages.create!(
      direction: :inbound,
      provider_message_id: "wamid.abc",
      message_type: "text",
      text_body: "Hello"
    )

    stubbed_send = lambda do |**_kwargs|
      { status: :sent, provider_message_id: "wamid.outbound.1", code: 200 }
    end

    result = nil
    with_class_method_stub(Whatsapp::SendMessage, :call, stubbed_send) do
      result = Conversation::ApplyN8nResponse.call(
        intake_session: session,
        payload: {
          source_message_id: source_message.provider_message_id,
          candidate_fields: [
            { key: valid_field.key, value: "Karel Nel", confidence: 0.98, source: "message_text" },
            { key: "unknown_key", value: "foo", confidence: 0.9, source: "message_text" }
          ],
          reply: { text: "Thanks, please send your ID number." }
        }
      )
    end

    assert_equal :ok, result[:status]
    assert_equal 1, session.intake_field_values.where(intake_field: valid_field, superseded_by_id: nil).count
    assert_equal 1, session.intake_messages.direction_outbound.count
    assert session.intake_events.where(event_type: "n8n_response_applied").exists?
    assert_equal "awaiting_patient", session.reload.status
  end

  test "uses deterministic cluster reply when n8n reply text is blank" do
    practice = practices(:one)
    user = users(:one)
    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "948579418347282",
      waba_id: "waba-test-002",
      display_phone_number: "+27 69 043 2910",
      webhook_verify_token: "verify-token-def",
      app_secret_ciphertext: "app-secret-def",
      access_token_ciphertext: "access-token-def",
      active: true
    )
    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Cluster Fallback Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )
    IntakeField.create!(
      intake_flow: flow,
      key: "patient_surname",
      label: "Patient Surname",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      branching_rules_json: { linked_field_keys: [ "patient_id_number" ] },
      active: true
    )
    IntakeField.create!(
      intake_flow: flow,
      key: "patient_id_number",
      label: "Patient ID Number",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    session = IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+27825608531",
      patient_display_name: "Karel Nel",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )
    source_message = session.intake_messages.create!(
      direction: :inbound,
      provider_message_id: "wamid.def",
      message_type: "text",
      text_body: "Hello"
    )

    captured_message_body = nil
    stubbed_send = lambda do |**kwargs|
      captured_message_body = kwargs[:message_body]
      { status: :sent, provider_message_id: "wamid.outbound.2", code: 200 }
    end

    with_class_method_stub(Whatsapp::SendMessage, :call, stubbed_send) do
      Conversation::ApplyN8nResponse.call(
        intake_session: session,
        payload: {
          source_message_id: source_message.provider_message_id,
          candidate_fields: [],
          reply: { text: "   " }
        }
      )
    end

    assert_includes captured_message_body, "Please share the following details"
    assert_includes captured_message_body, "Patient Surname"
    assert_includes captured_message_body, "Patient ID Number"
  end

  test "prefers generated reply when candidates were applied to avoid stale re-asks" do
    practice = practices(:one)
    user = users(:one)
    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "948579418347283",
      waba_id: "waba-test-003",
      display_phone_number: "+27 69 043 2911",
      webhook_verify_token: "verify-token-ghi",
      app_secret_ciphertext: "app-secret-ghi",
      access_token_ciphertext: "access-token-ghi",
      active: true
    )
    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Stale Reply Guard Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )
    surname_field = IntakeField.create!(
      intake_flow: flow,
      key: "patient_surname",
      label: "Patient Surname",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    IntakeField.create!(
      intake_flow: flow,
      key: "patient_id_number",
      label: "Patient ID Number",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    session = IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+27825608532",
      patient_display_name: "Karel Nel",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )
    source_message = session.intake_messages.create!(
      direction: :inbound,
      provider_message_id: "wamid.ghi",
      message_type: "text",
      text_body: "Nel"
    )

    captured_message_body = nil
    stubbed_send = lambda do |**kwargs|
      captured_message_body = kwargs[:message_body]
      { status: :sent, provider_message_id: "wamid.outbound.3", code: 200 }
    end

    with_class_method_stub(Whatsapp::SendMessage, :call, stubbed_send) do
      Conversation::ApplyN8nResponse.call(
        intake_session: session,
        payload: {
          source_message_id: source_message.provider_message_id,
          candidate_fields: [
            { key: surname_field.key, value: "Nel", confidence: 0.95, source: "message_text" }
          ],
          reply: { text: "Please confirm your surname again." }
        }
      )
    end

    assert_includes captured_message_body, "Patient ID Number"
    refute_includes captured_message_body, "confirm your surname again"

    applied_event = session.intake_events.where(event_type: "n8n_response_applied").order(created_at: :desc).first
    assert_equal "generated", applied_event.payload_json["reply_source"]
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
