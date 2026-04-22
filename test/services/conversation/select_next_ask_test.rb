require "test_helper"
require "securerandom"

class Conversation::SelectNextAskTest < ActiveSupport::TestCase
  test "selects first available linked question cluster" do
    context = build_session_with_cluster
    session = context.fetch(:session)

    recommendation = Conversation::SelectNextAsk.call(intake_session: session)

    assert_not_nil recommendation
    assert_equal "cluster", recommendation[:mode]
    assert_equal "responsible_surname", recommendation[:cluster_key]
    assert_equal [ "responsible_surname", "responsible_id_number", "responsible_cell_phone" ], recommendation[:field_keys]
  end

  test "returns nil when no asks are outstanding" do
    context = build_session_with_cluster
    session = context.fetch(:session)
    surname_field = context.fetch(:surname_field)
    id_field = context.fetch(:id_field)
    phone_field = context.fetch(:phone_field)

    [ surname_field, id_field, phone_field ].each do |field|
      IntakeFieldValue.create!(
        intake_session: session,
        intake_field: field,
        canonical_value_text: "done",
        status: :complete,
        confidence: 0.99
      )
    end

    recommendation = Conversation::SelectNextAsk.call(intake_session: session)
    assert_nil recommendation
  end

  private

  def build_session_with_cluster
    practice = practices(:one)
    user = users(:one)
    suffix = SecureRandom.hex(4)

    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "cluster-#{suffix}",
      waba_id: "cluster-waba-#{suffix}",
      display_phone_number: "+27 69 100 2000",
      webhook_verify_token: "verify-#{suffix}",
      app_secret_ciphertext: "secret-#{suffix}",
      access_token_ciphertext: "token-#{suffix}",
      active: true
    )

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "SelectNextAsk Flow #{suffix}",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )

    group = IntakeFieldGroup.create!(
      intake_flow: flow,
      key: "responsible",
      label: "Responsible",
      position: 1,
      repeatable: false,
      visibility_rules_json: {}
    )

    surname_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "responsible_surname",
      label: "Responsible Surname",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      branching_rules_json: { linked_field_keys: [ "responsible_id_number", "responsible_cell_phone" ] },
      active: true
    )

    id_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "responsible_id_number",
      label: "Responsible ID Number",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )

    phone_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "responsible_cell_phone",
      label: "Responsible Cell Phone",
      field_type: "phone",
      required: true,
      ask_priority: 3,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )

    session = IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+27820009999",
      patient_display_name: "Cluster Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )

    {
      session: session,
      surname_field: surname_field,
      id_field: id_field,
      phone_field: phone_field
    }
  end
end
