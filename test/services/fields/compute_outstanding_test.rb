require "test_helper"

class Fields::ComputeOutstandingTest < ActiveSupport::TestCase
  test "builds linked next ask batch and excludes already completed linked fields" do
    practice = practices(:one)
    user = users(:one)
    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "948579418347999",
      waba_id: "waba-test-linked-001",
      display_phone_number: "+27 69 000 9999",
      webhook_verify_token: "verify-token-linked",
      app_secret_ciphertext: "app-secret-linked",
      access_token_ciphertext: "access-token-linked",
      active: true
    )
    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Linked Batch Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )
    group = IntakeFieldGroup.create!(
      intake_flow: flow,
      key: "responsible_person",
      label: "Responsible Person",
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
      branching_rules_json: {
        linked_field_keys: [
          "responsible_full_names",
          "responsible_id_number",
          "responsible_cell_phone"
        ]
      },
      active: true
    )
    full_names_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "responsible_full_names",
      label: "Responsible Full Names",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    id_number_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "responsible_id_number",
      label: "Responsible ID Number",
      field_type: "text",
      required: true,
      ask_priority: 3,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    cell_phone_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "responsible_cell_phone",
      label: "Responsible Cell Phone",
      field_type: "phone",
      required: true,
      ask_priority: 4,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )

    session = IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+27820001111",
      patient_display_name: "Linked Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )

    IntakeFieldValue.create!(
      intake_session: session,
      intake_field: full_names_field,
      canonical_value_text: "Thabo Mokoena",
      status: :complete,
      confidence: 0.99
    )

    result = Fields::ComputeOutstanding.call(intake_session: session)

    assert_includes result[:allowed_next_asks], surname_field.key
    assert_includes result[:allowed_next_asks], id_number_field.key
    assert_includes result[:allowed_next_asks], cell_phone_field.key
    assert_not_includes result[:allowed_next_asks], full_names_field.key

    first_batch = result[:next_ask_batches].first
    assert_equal "responsible_surname", first_batch[:batch_key]
    assert_equal "responsible_person", first_batch[:group_key]
    assert_equal [ "responsible_surname", "responsible_id_number", "responsible_cell_phone" ], first_batch[:field_keys]
  end
end
