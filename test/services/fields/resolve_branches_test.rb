require "test_helper"
require "securerandom"

class Fields::ResolveBranchesTest < ActiveSupport::TestCase
  test "applies skip rules from trusted values" do
    context = build_session_context("Resolve Branches Skip")
    flow = context.fetch(:flow)
    intake_session = context.fetch(:intake_session)

    occupation_field = IntakeField.create!(
      intake_flow: flow,
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

    initial_result = Fields::ResolveBranches.call(intake_session: intake_session)
    assert_not_includes initial_result[:active_field_keys], business_field.key
    assert_includes initial_result[:skipped_field_keys], business_field.key

    IntakeFieldValue.create!(
      intake_session: intake_session,
      intake_field: occupation_field,
      canonical_value_text: "Self-employed designer",
      status: :complete,
      confidence: 0.99
    )

    resolved_result = Fields::ResolveBranches.call(intake_session: intake_session)
    assert_includes resolved_result[:active_field_keys], business_field.key
    assert_not_includes resolved_result[:skipped_field_keys], business_field.key
  end

  test "applies on_complete actions to activate and deactivate fields" do
    context = build_session_context("Resolve Branches Actions")
    flow = context.fetch(:flow)
    intake_session = context.fetch(:intake_session)

    decision_field = IntakeField.create!(
      intake_flow: flow,
      key: "patient_same_as_debtor",
      label: "Patient same as debtor?",
      field_type: "boolean",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      branching_rules_json: {
        on_complete: [
          {
            if: {
              field_key: "patient_same_as_debtor",
              op: "equals",
              value: "no"
            },
            then: {
              activate_field: "debtor_id_number"
            },
            else: {
              deactivate_field: "debtor_id_number"
            }
          }
        ]
      },
      active: true
    )

    dependent_field = IntakeField.create!(
      intake_flow: flow,
      key: "debtor_id_number",
      label: "Debtor ID Number",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      branching_rules_json: {
        visible_if: {
          field_key: "patient_same_as_debtor",
          op: "equals",
          value: "__never_visible_without_override__"
        }
      },
      active: true
    )

    first_value = IntakeFieldValue.create!(
      intake_session: intake_session,
      intake_field: decision_field,
      canonical_value_text: "no",
      status: :complete,
      confidence: 0.99
    )

    activated_result = Fields::ResolveBranches.call(intake_session: intake_session)
    assert_includes activated_result[:active_field_keys], dependent_field.key

    second_value = IntakeFieldValue.create!(
      intake_session: intake_session,
      intake_field: decision_field,
      canonical_value_text: "yes",
      status: :complete,
      confidence: 0.99
    )
    first_value.update!(superseded_by: second_value)

    deactivated_result = Fields::ResolveBranches.call(intake_session: intake_session)
    assert_not_includes deactivated_result[:active_field_keys], dependent_field.key
  end

  private

  def build_session_context(flow_name)
    practice = practices(:one)
    user = users(:one)
    suffix = SecureRandom.hex(6)

    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "phone-#{suffix}",
      waba_id: "waba-#{suffix}",
      display_phone_number: "+27 69 111 0000",
      webhook_verify_token: "verify-#{suffix}",
      app_secret_ciphertext: "app-secret-#{suffix}",
      access_token_ciphertext: "access-token-#{suffix}",
      active: true
    )

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "#{flow_name} #{suffix}",
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
      patient_phone_e164: "+2783#{rand(10_000_000).to_s.rjust(7, '0')}",
      patient_display_name: "Branch Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )

    {
      practice: practice,
      user: user,
      flow: flow,
      intake_session: intake_session
    }
  end
end
