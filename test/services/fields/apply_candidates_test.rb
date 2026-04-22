require "test_helper"
require "securerandom"

class Fields::ApplyCandidatesTest < ActiveSupport::TestCase
  test "marks invalid deterministic values as rejected and returns rejected keys" do
    context = build_session_context("Apply Candidates Validation")
    flow = context.fetch(:flow)
    intake_session = context.fetch(:intake_session)

    id_field = IntakeField.create!(
      intake_flow: flow,
      key: "patient_id_number",
      label: "Patient ID Number",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      validation_rules_json: {
        type: "za_id_number",
        digits_only: true,
        exact_length: 13
      },
      active: true
    )

    result = Fields::ApplyCandidates.call(
      intake_session: intake_session,
      candidate_fields: [
        {
          key: id_field.key,
          value: "1234",
          confidence: 0.99,
          source: "n8n"
        }
      ],
      applied_by: "n8n"
    )

    assert_equal [ id_field.key ], result[:rejected_keys]

    rejected_value = intake_session.intake_field_values.order(:created_at).last
    assert_equal id_field.id, rejected_value.intake_field_id
    assert_equal "rejected", rejected_value.status

    rejected_event = intake_session.intake_events.find_by(event_type: "field_candidate_rejected")
    assert_not_nil rejected_event
    assert_includes Array(rejected_event.payload_json["validation_errors"]), "exact_length"
  end

  test "normalizes valid values and applies status from confidence thresholds" do
    context = build_session_context("Apply Candidates Thresholds")
    flow = context.fetch(:flow)
    intake_session = context.fetch(:intake_session)

    phone_field = IntakeField.create!(
      intake_flow: flow,
      key: "patient_cell_phone",
      label: "Patient Cell Phone",
      field_type: "phone",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      validation_rules_json: {
        type: "phone_e164_or_local_za",
        min_length: 10,
        max_length: 15
      },
      active: true
    )

    result = Fields::ApplyCandidates.call(
      intake_session: intake_session,
      candidate_fields: [
        {
          key: phone_field.key,
          value: "082 123 4567",
          confidence: 0.95,
          source: "n8n"
        }
      ],
      applied_by: "n8n"
    )

    assert_empty result[:rejected_keys]

    applied_value = intake_session.intake_field_values.order(:created_at).last
    assert_equal phone_field.id, applied_value.intake_field_id
    assert_equal "+27821234567", applied_value.canonical_value_text
    assert_equal "complete", applied_value.status

    applied_event = intake_session.intake_events.find_by(event_type: "field_candidate_applied")
    assert_not_nil applied_event
    assert_equal [], Array(applied_event.payload_json["validation_errors"])
  end

  test "marks asked non-strict fields as complete on valid confirmation confidence" do
    context = build_session_context("Apply Candidates Confirmation")
    flow = context.fetch(:flow)
    intake_session = context.fetch(:intake_session)

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

    Fields::ApplyCandidates.call(
      intake_session: intake_session,
      candidate_fields: [
        { key: surname_field.key, value: "Nel", confidence: 0.8, source: "n8n" }
      ],
      applied_by: "n8n"
    )

    latest_value = intake_session.intake_field_values.where(intake_field: surname_field, superseded_by_id: nil).first
    assert_equal "complete", latest_value.status
  end

  test "does not downgrade complete value for same normalized value with lower confidence" do
    context = build_session_context("Apply Candidates No Downgrade")
    flow = context.fetch(:flow)
    intake_session = context.fetch(:intake_session)

    phone_field = IntakeField.create!(
      intake_flow: flow,
      key: "patient_cell_phone",
      label: "Patient Cell Phone",
      field_type: "phone",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      validation_rules_json: { type: "phone_e164_or_local_za", min_length: 10, max_length: 15 },
      active: true
    )

    Fields::ApplyCandidates.call(
      intake_session: intake_session,
      candidate_fields: [
        { key: phone_field.key, value: "0821234567", confidence: 0.95, source: "n8n" }
      ],
      applied_by: "n8n"
    )

    assert_equal 1, intake_session.intake_field_values.where(intake_field: phone_field).count
    assert_equal "complete", intake_session.intake_field_values.where(intake_field: phone_field, superseded_by_id: nil).first.status

    Fields::ApplyCandidates.call(
      intake_session: intake_session,
      candidate_fields: [
        { key: phone_field.key, value: "+27 82 123 4567", confidence: 0.8, source: "n8n" }
      ],
      applied_by: "n8n"
    )

    latest_value = intake_session.intake_field_values.where(intake_field: phone_field, superseded_by_id: nil).first
    assert_equal 1, intake_session.intake_field_values.where(intake_field: phone_field).count
    assert_equal "complete", latest_value.status
    assert_equal "+27821234567", latest_value.canonical_value_text
  end

  test "keeps non-asked low-confidence non-strict fields as candidate" do
    context = build_session_context("Apply Candidates Non Asked")
    flow = context.fetch(:flow)
    intake_session = context.fetch(:intake_session)

    asked_field = IntakeField.create!(
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
    non_asked_field = IntakeField.create!(
      intake_flow: flow,
      key: "responsible_employer",
      label: "Responsible Employer",
      field_type: "text",
      required: false,
      ask_priority: 100,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )

    Fields::ApplyCandidates.call(
      intake_session: intake_session,
      candidate_fields: [
        { key: non_asked_field.key, value: "Acme Corp", confidence: 0.8, source: "n8n" }
      ],
      applied_by: "n8n"
    )

    latest_non_asked = intake_session.intake_field_values.where(intake_field: non_asked_field, superseded_by_id: nil).first
    assert_equal "candidate", latest_non_asked.status

    # Sanity: asked field remains missing so ask context existed
    assert_equal 0, intake_session.intake_field_values.where(intake_field: asked_field).count
  end

  test "marks strict identifier fields complete at 0.90 confidence" do
    context = build_session_context("Apply Candidates Strict Identifier Threshold")
    flow = context.fetch(:flow)
    intake_session = context.fetch(:intake_session)

    id_field = IntakeField.create!(
      intake_flow: flow,
      key: "patient_id_number",
      label: "Patient ID Number",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      validation_rules_json: {
        type: "za_id_number",
        digits_only: true,
        exact_length: 13
      },
      active: true
    )

    Fields::ApplyCandidates.call(
      intake_session: intake_session,
      candidate_fields: [
        { key: id_field.key, value: "0308215351088", confidence: 0.90, source: "n8n" }
      ],
      applied_by: "n8n"
    )

    latest_value = intake_session.intake_field_values.where(intake_field: id_field, superseded_by_id: nil).first
    assert_equal "complete", latest_value.status
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
      display_phone_number: "+27 69 000 0000",
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
      patient_phone_e164: "+2782#{rand(10_000_000).to_s.rjust(7, '0')}",
      patient_display_name: "Validation Test",
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
