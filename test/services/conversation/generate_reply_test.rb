require "test_helper"
require "securerandom"

class Conversation::GenerateReplyTest < ActiveSupport::TestCase
  test "builds a multi-question reply from linked cluster recommendation" do
    session = build_cluster_session

    result = Conversation::GenerateReply.call(intake_session_id: session.id)

    assert_equal :ok, result[:status]
    assert_includes result[:reply_text], "Please share the following details"
    assert_includes result[:reply_text], "Responsible Surname"
    assert_includes result[:reply_text], "Responsible ID Number"
    assert_includes result[:reply_text], "Responsible Cell Phone"
    assert_equal "cluster", result.dig(:next_ask, :mode)
  end

  test "falls back when no question is outstanding" do
    session = build_cluster_session
    field_ids = session.intake_flow.intake_fields.where(active: true).pluck(:id)

    session.intake_flow.intake_fields.where(id: field_ids).find_each do |field|
      IntakeFieldValue.create!(
        intake_session: session,
        intake_field: field,
        canonical_value_text: "done",
        status: :complete,
        confidence: 0.99
      )
    end

    result = Conversation::GenerateReply.call(intake_session_id: session.id)
    assert_equal "Thank you, we received your message and will continue shortly.", result[:reply_text]
    assert_nil result[:next_ask]
  end

  private

  def build_cluster_session
    practice = practices(:one)
    user = users(:one)
    suffix = SecureRandom.hex(4)

    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "reply-#{suffix}",
      waba_id: "reply-waba-#{suffix}",
      display_phone_number: "+27 69 432 1000",
      webhook_verify_token: "verify-#{suffix}",
      app_secret_ciphertext: "secret-#{suffix}",
      access_token_ciphertext: "token-#{suffix}",
      active: true
    )

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "GenerateReply Flow #{suffix}",
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

    IntakeField.create!(
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

    IntakeField.create!(
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

    IntakeField.create!(
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

    IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+27820008888",
      patient_display_name: "Reply Test",
      status: :active,
      language: "en-ZA",
      started_at: Time.current
    )
  end
end
