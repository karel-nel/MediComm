require "test_helper"
require "securerandom"

class IntakeFieldTest < ActiveSupport::TestCase
  test "normalizes linked_field_keys and removes self-reference" do
    context = build_flow_context
    field = context.fetch(:field)
    linked_field = context.fetch(:linked_field)

    field.linked_field_keys = [ " #{linked_field.key} ", field.key, "", linked_field.key ]
    field.save!
    field.reload

    assert_equal [ linked_field.key ], field.linked_field_keys
    assert_equal [ linked_field.key ], field.branching_rules_json["linked_field_keys"]
    assert_equal [ field.key ], linked_field.reload.linked_field_keys

    field.linked_field_keys = []
    field.save!
    field.reload

    assert_equal [], field.linked_field_keys
    assert_nil field.branching_rules_json["linked_field_keys"]
    assert_equal [], linked_field.reload.linked_field_keys
  end

  test "allows linked_field_keys that may be created later in flow setup" do
    context = build_flow_context
    field = context.fetch(:field)

    field.linked_field_keys = [ "unknown_field_key" ]

    assert field.valid?
    field.save!
    assert_equal [ "unknown_field_key" ], field.reload.linked_field_keys
  end

  test "adds and removes reverse link automatically for linked fields in same flow" do
    context = build_flow_context
    field = context.fetch(:field)
    linked_field = context.fetch(:linked_field)

    field.linked_field_keys = [ linked_field.key ]
    field.save!
    assert_includes linked_field.reload.linked_field_keys, field.key

    field.linked_field_keys = []
    field.save!
    assert_not_includes linked_field.reload.linked_field_keys, field.key
  end

  private

  def build_flow_context
    practice = practices(:one)
    user = users(:one)
    suffix = SecureRandom.hex(4)

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "IntakeFieldTest Flow #{suffix}",
      flow_type: "new_patient",
      status: :draft,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )

    field = IntakeField.create!(
      intake_flow: flow,
      key: "patient_full_name_#{suffix}",
      label: "Patient Full Name",
      field_type: "text",
      required: true,
      ask_priority: 1,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )

    linked_field = IntakeField.create!(
      intake_flow: flow,
      key: "patient_id_number_#{suffix}",
      label: "Patient ID Number",
      field_type: "text",
      required: true,
      ask_priority: 2,
      extraction_enabled: true,
      source_preference: "any",
      active: true
    )

    { field: field, linked_field: linked_field }
  end
end
