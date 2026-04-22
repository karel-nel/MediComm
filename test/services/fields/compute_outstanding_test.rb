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

  test "excludes required fields that are currently skipped and reintroduces when skip condition clears" do
    practice = practices(:one)
    user = users(:one)
    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "948579418347998",
      waba_id: "waba-test-skipped-001",
      display_phone_number: "+27 69 000 8888",
      webhook_verify_token: "verify-token-skipped",
      app_secret_ciphertext: "app-secret-skipped",
      access_token_ciphertext: "access-token-skipped",
      active: true
    )
    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Skipped Required Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )
    group = IntakeFieldGroup.create!(
      intake_flow: flow,
      key: "occupation",
      label: "Occupation",
      position: 1,
      repeatable: false,
      visibility_rules_json: {}
    )
    occupation_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "patient_occupation",
      label: "Occupation",
      field_type: "text",
      required: false,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    business_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "patient_self_employed_business_name",
      label: "Business Name",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      skip_rules_json: {
        operator: "all",
        skip_if: [
          {
            field_key: "patient_occupation",
            op: "not_contains_any",
            value: [ "self", "self-employed" ]
          }
        ]
      },
      active: true
    )

    session = IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+27820002222",
      patient_display_name: "Skip Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )

    initial_result = Fields::ComputeOutstanding.call(intake_session: session)
    assert_not_includes initial_result[:missing_fields], business_field.key
    assert_not_includes initial_result[:allowed_next_asks], business_field.key
    assert_includes initial_result[:skipped_fields], business_field.key

    IntakeFieldValue.create!(
      intake_session: session,
      intake_field: occupation_field,
      canonical_value_text: "Self-employed consultant",
      status: :complete,
      confidence: 0.99
    )

    resolved_result = Fields::ComputeOutstanding.call(intake_session: session)
    assert_includes resolved_result[:missing_fields], business_field.key
    assert_includes resolved_result[:allowed_next_asks], business_field.key
    assert_not_includes resolved_result[:skipped_fields], business_field.key
  end

  test "keeps unanswered linked fields together even when cluster anchor is already complete" do
    practice = practices(:one)
    user = users(:one)
    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "948579418347997",
      waba_id: "waba-test-address-001",
      display_phone_number: "+27 69 000 7777",
      webhook_verify_token: "verify-token-address",
      app_secret_ciphertext: "app-secret-address",
      access_token_ciphertext: "access-token-address",
      active: true
    )
    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Address Cluster Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )
    group = IntakeFieldGroup.create!(
      intake_flow: flow,
      key: "address_details",
      label: "Address Details",
      position: 1,
      repeatable: false,
      visibility_rules_json: {}
    )
    street_number_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "address_street_number",
      label: "Street Number",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      branching_rules_json: {
        linked_field_keys: [
          "address_street_name",
          "address_area",
          "address_province"
        ]
      },
      active: true
    )
    street_name_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "address_street_name",
      label: "Street Name",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    area_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "address_area",
      label: "Area",
      field_type: "text",
      required: true,
      ask_priority: 3,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )
    province_field = IntakeField.create!(
      intake_flow: flow,
      intake_field_group: group,
      key: "address_province",
      label: "Province",
      field_type: "text",
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
      patient_phone_e164: "+27820003333",
      patient_display_name: "Address Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )

    IntakeFieldValue.create!(
      intake_session: session,
      intake_field: street_number_field,
      canonical_value_text: "24",
      status: :complete,
      confidence: 0.98
    )

    result = Fields::ComputeOutstanding.call(intake_session: session)
    first_batch = result[:next_ask_batches].first

    assert_equal [ street_name_field.key, area_field.key, province_field.key ], first_batch[:field_keys]
    assert_equal first_batch[:field_keys], result[:question_clusters].first[:field_keys]
    assert_not_includes first_batch[:field_keys], street_number_field.key
  end

  test "reports cluster warnings for orphan and one-way links" do
    practice = practices(:one)
    user = users(:one)
    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "948579418347996",
      waba_id: "waba-test-warnings-001",
      display_phone_number: "+27 69 000 6666",
      webhook_verify_token: "verify-token-warnings",
      app_secret_ciphertext: "app-secret-warnings",
      access_token_ciphertext: "access-token-warnings",
      active: true
    )
    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Cluster Warning Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )

    IntakeField.create!(
      intake_flow: flow,
      key: "address_street_number",
      label: "Street Number",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      branching_rules_json: {
        linked_field_keys: [
          "address_street_name",
          "address_missing_from_flow"
        ]
      },
      active: true
    )
    IntakeField.create!(
      intake_flow: flow,
      key: "address_street_name",
      label: "Street Name",
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
      patient_phone_e164: "+27820004444",
      patient_display_name: "Warning Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )

    result = Fields::ComputeOutstanding.call(intake_session: session)

    assert_equal 2, result[:cluster_warnings].size
    assert_equal "one_way_link", result[:cluster_warnings].first[:type]
    assert_equal "orphan_link", result[:cluster_warnings].second[:type]
  end

  test "includes unresolved optional linked fields when asking a required cluster" do
    practice = practices(:one)
    user = users(:one)
    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "948579418347995",
      waba_id: "waba-test-optional-cluster-001",
      display_phone_number: "+27 69 000 5555",
      webhook_verify_token: "verify-token-optional-cluster",
      app_secret_ciphertext: "app-secret-optional-cluster",
      access_token_ciphertext: "access-token-optional-cluster",
      active: true
    )
    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Optional Cluster Intake",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )

    IntakeField.create!(
      intake_flow: flow,
      key: "patient_id_number",
      label: "ID Number",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      branching_rules_json: { linked_field_keys: [ "patient_email" ] },
      active: true
    )
    IntakeField.create!(
      intake_flow: flow,
      key: "patient_email",
      label: "Email",
      field_type: "email",
      required: false,
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
      patient_phone_e164: "+27820005555",
      patient_display_name: "Optional Cluster Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )

    result = Fields::ComputeOutstanding.call(intake_session: session)
    first_batch = result[:next_ask_batches].first

    assert_equal [ "patient_id_number", "patient_email" ], first_batch[:field_keys]
    assert_includes result[:missing_fields], "patient_id_number"
    assert_not_includes result[:missing_fields], "patient_email"
  end
end
