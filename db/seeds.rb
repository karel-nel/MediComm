puts "Seeding MediComm Phase 2 data..."

[
  ExportedDocument,
  SessionReview,
  IntakeEvent,
  IntakeFieldValue,
  IntakeAttachment,
  IntakeMessage,
  IntakeSession,
  IntakeField,
  IntakeFieldGroup,
  IntakeFlow,
  WhatsappAccount,
  User,
  Practice
].each(&:delete_all)

practice = Practice.create!(
  name: "MediComm Demo Practice",
  slug: "medicomm-demo-practice",
  timezone: "Africa/Johannesburg",
  contact_email: "ops@medicomm-demo.co.za",
  status: "active"
)

owner = User.create!(
  practice: practice,
  first_name: "Anele",
  last_name: "Ndlovu",
  email: "anele.owner@medicomm-demo.co.za",
  password: "password123",
  password_confirmation: "password123",
  role: :owner,
  active: true
)

admin = User.create!(
  practice: practice,
  first_name: "Maya",
  last_name: "Patel",
  email: "maya.admin@medicomm-demo.co.za",
  password: "password123",
  password_confirmation: "password123",
  role: :admin,
  active: true
)

staff = User.create!(
  practice: practice,
  first_name: "Johan",
  last_name: "Botha",
  email: "johan.staff@medicomm-demo.co.za",
  password: "password123",
  password_confirmation: "password123",
  role: :staff,
  active: true
)

read_only = User.create!(
  practice: practice,
  first_name: "Ruth",
  last_name: "Molefe",
  email: "ruth.readonly@medicomm-demo.co.za",
  password: "password123",
  password_confirmation: "password123",
  role: :read_only,
  active: true
)

whatsapp_account = WhatsappAccount.create!(
  practice: practice,
  phone_number_id: "155512300001",
  waba_id: "waba-za-demo-001",
  display_phone_number: "+27 71 555 1000",
  webhook_verify_token: "demo-verify-token-001",
  app_secret_ciphertext: "demo-app-secret-001",
  access_token_ciphertext: "encrypted-demo-token",
  business_account_name: "MediComm Intake",
  active: true
)

new_patient_flow = IntakeFlow.create!(
  practice: practice,
  created_by: owner,
  name: "New Patient Intake",
  flow_type: "new_patient",
  status: :published,
  description: "Collect core demographics, medical aid details, and required document uploads.",
  default_language: "en-ZA",
  tone_preset: "professional",
  allow_skip_by_default: false,
  completion_email_enabled: true,
  completion_email_recipients_json: [ "intake@medicomm-demo.co.za" ],
  published_at: 5.days.ago
)

follow_up_flow = IntakeFlow.create!(
  practice: practice,
  created_by: admin,
  name: "Follow-up Intake",
  flow_type: "follow_up",
  status: :published,
  description: "Collect follow-up symptoms and medication changes before return visit.",
  default_language: "en-ZA",
  tone_preset: "empathetic",
  allow_skip_by_default: true,
  completion_email_enabled: false,
  completion_email_recipients_json: [],
  published_at: 3.days.ago
)

patient_group = IntakeFieldGroup.create!(
  intake_flow: new_patient_flow,
  key: "patient_details",
  label: "Patient Details",
  position: 1,
  repeatable: false,
  visibility_rules_json: {}
)

medical_aid_group = IntakeFieldGroup.create!(
  intake_flow: new_patient_flow,
  key: "medical_aid",
  label: "Medical Aid",
  position: 2,
  repeatable: false,
  visibility_rules_json: {}
)

uploads_group = IntakeFieldGroup.create!(
  intake_flow: new_patient_flow,
  key: "uploads",
  label: "Required Uploads",
  position: 3,
  repeatable: false,
  visibility_rules_json: {}
)

follow_up_group = IntakeFieldGroup.create!(
  intake_flow: follow_up_flow,
  key: "follow_up_details",
  label: "Follow-up Details",
  position: 1,
  repeatable: false,
  visibility_rules_json: {}
)

fields = {}

[
  [ patient_group, "full_name", "Full Name", "text", true, 1 ],
  [ patient_group, "id_number", "ID Number", "text", true, 2 ],
  [ patient_group, "date_of_birth", "Date of Birth", "date", true, 3 ],
  [ patient_group, "phone_number", "Phone Number", "phone", true, 4 ],
  [ medical_aid_group, "medical_aid_provider", "Medical Aid Provider", "text", true, 5 ],
  [ medical_aid_group, "medical_aid_number", "Medical Aid Number", "text", true, 6 ],
  [ uploads_group, "id_document_upload", "ID Document Upload", "file", true, 7 ],
  [ uploads_group, "medical_aid_card_upload", "Medical Aid Card Upload", "file", false, 8 ]
].each do |group, key, label, field_type, required, ask_priority|
  fields[key] = IntakeField.create!(
    intake_flow: new_patient_flow,
    intake_field_group: group,
    key: key,
    label: label,
    field_type: field_type,
    required: required,
    ask_priority: ask_priority,
    extraction_enabled: true,
    source_preference: "any",
    validation_rules_json: {},
    branching_rules_json: {},
    skip_rules_json: {},
    example_values_json: [],
    active: true
  )
end

[
  [ "follow_up_reason", "Follow-up Reason", "text", true, 1 ],
  [ "current_symptoms", "Current Symptoms", "text", true, 2 ],
  [ "medication_changes", "Medication Changes", "text", false, 3 ],
  [ "latest_test_results", "Latest Test Results Upload", "file", false, 4 ]
].each do |key, label, field_type, required, ask_priority|
  fields[key] = IntakeField.create!(
    intake_flow: follow_up_flow,
    intake_field_group: follow_up_group,
    key: key,
    label: label,
    field_type: field_type,
    required: required,
    ask_priority: ask_priority,
    extraction_enabled: true,
    source_preference: "any",
    validation_rules_json: {},
    branching_rules_json: {},
    skip_rules_json: {},
    example_values_json: [],
    active: true
  )
end

session_review_queue = IntakeSession.create!(
  practice: practice,
  intake_flow: new_patient_flow,
  whatsapp_account: whatsapp_account,
  initiated_by_user: admin,
  patient_phone_e164: "+27824567891",
  patient_display_name: "Nomsa Dlamini",
  external_reference: "NP-2026-0001",
  status: :awaiting_staff_review,
  language: "en-ZA",
  started_at: 3.hours.ago,
  completed_at: nil
)

session_active = IntakeSession.create!(
  practice: practice,
  intake_flow: new_patient_flow,
  whatsapp_account: whatsapp_account,
  initiated_by_user: staff,
  patient_phone_e164: "+27835551234",
  patient_display_name: "Peter Mokoena",
  external_reference: "NP-2026-0002",
  status: :active,
  language: "en-ZA",
  started_at: 90.minutes.ago,
  completed_at: nil
)

session_completed = IntakeSession.create!(
  practice: practice,
  intake_flow: new_patient_flow,
  whatsapp_account: whatsapp_account,
  initiated_by_user: owner,
  patient_phone_e164: "+27824449988",
  patient_display_name: "Lebo Khumalo",
  external_reference: "NP-2026-0003",
  status: :completed,
  language: "en-ZA",
  started_at: 1.day.ago,
  completed_at: 20.hours.ago
)

session_follow_up = IntakeSession.create!(
  practice: practice,
  intake_flow: follow_up_flow,
  whatsapp_account: whatsapp_account,
  initiated_by_user: admin,
  patient_phone_e164: "+27837770011",
  patient_display_name: "Thandi Radebe",
  external_reference: "FU-2026-0001",
  status: :awaiting_patient,
  language: "en-ZA",
  started_at: 5.hours.ago,
  completed_at: nil
)

message_counter = 0

create_message = lambda do |session:, direction:, type:, text:, timestamp:|
  message_counter += 1
  IntakeMessage.create!(
    intake_session: session,
    direction: direction,
    message_type: type,
    text_body: text,
    provider_message_id: "wa-msg-#{message_counter.to_s.rjust(5, '0')}",
    created_at: timestamp,
    updated_at: timestamp
  )
end

nomsa_outbound = create_message.call(
  session: session_review_queue,
  direction: :outbound,
  type: "text",
  text: "Welcome Nomsa. Please share your full name, ID number, and medical aid details.",
  timestamp: 3.hours.ago
)
nomsa_inbound_1 = create_message.call(
  session: session_review_queue,
  direction: :inbound,
  type: "text",
  text: "Nomsa Dlamini, 9001011234089, Discovery Classic Smart.",
  timestamp: 2.hours.ago
)
nomsa_inbound_2 = create_message.call(
  session: session_review_queue,
  direction: :inbound,
  type: "image",
  text: "Here is my ID photo.",
  timestamp: 100.minutes.ago
)

nomsa_id_attachment = IntakeAttachment.create!(
  intake_session: session_review_queue,
  intake_message: nomsa_inbound_2,
  mime_type: "image/jpeg",
  s3_key: "demo/intake/nomsa/id-card.jpg",
  file_name: "nomsa-id.jpg",
  byte_size: 412_000,
  processing_status: "processed",
  created_at: 99.minutes.ago,
  updated_at: 99.minutes.ago
)

create_message.call(
  session: session_active,
  direction: :outbound,
  type: "text",
  text: "Hi Peter, please send your ID number and medical aid card.",
  timestamp: 80.minutes.ago
)
peter_inbound = create_message.call(
  session: session_active,
  direction: :inbound,
  type: "text",
  text: "My ID is 8507074567081. Medical aid card coming shortly.",
  timestamp: 55.minutes.ago
)

create_message.call(
  session: session_completed,
  direction: :outbound,
  type: "text",
  text: "Thanks Lebo, your intake is complete.",
  timestamp: 22.hours.ago
)
lebo_inbound = create_message.call(
  session: session_completed,
  direction: :inbound,
  type: "text",
  text: "Lebo Khumalo, 9202125123088, FedHealth FlexiFed 123456789.",
  timestamp: 25.hours.ago
)

create_message.call(
  session: session_follow_up,
  direction: :outbound,
  type: "text",
  text: "Please share your follow-up reason and current symptoms.",
  timestamp: 4.hours.ago
)
follow_up_inbound = create_message.call(
  session: session_follow_up,
  direction: :inbound,
  type: "text",
  text: "I still have dizziness and headaches in the mornings.",
  timestamp: 3.hours.ago
)

IntakeFieldValue.create!(
  intake_session: session_review_queue,
  intake_field: fields.fetch("full_name"),
  source_message: nomsa_inbound_1,
  canonical_value_text: "Nomsa Dlamini",
  status: :complete,
  confidence: 0.99
)
IntakeFieldValue.create!(
  intake_session: session_review_queue,
  intake_field: fields.fetch("id_number"),
  source_message: nomsa_inbound_1,
  canonical_value_text: "9001011234089",
  status: :complete,
  confidence: 0.97
)
IntakeFieldValue.create!(
  intake_session: session_review_queue,
  intake_field: fields.fetch("medical_aid_provider"),
  source_message: nomsa_inbound_1,
  canonical_value_text: "Discovery Classic Smart",
  status: :complete,
  confidence: 0.92
)
IntakeFieldValue.create!(
  intake_session: session_review_queue,
  intake_field: fields.fetch("medical_aid_number"),
  source_message: nomsa_inbound_1,
  canonical_value_text: "Unclear from message",
  status: :needs_clarification,
  confidence: 0.52
)
IntakeFieldValue.create!(
  intake_session: session_review_queue,
  intake_field: fields.fetch("id_document_upload"),
  source_message: nomsa_inbound_2,
  source_attachment: nomsa_id_attachment,
  canonical_value_text: "Uploaded: nomsa-id.jpg",
  status: :complete,
  confidence: 0.95
)

IntakeFieldValue.create!(
  intake_session: session_active,
  intake_field: fields.fetch("id_number"),
  source_message: peter_inbound,
  canonical_value_text: "8507074567081",
  status: :candidate,
  confidence: 0.74
)
IntakeFieldValue.create!(
  intake_session: session_active,
  intake_field: fields.fetch("full_name"),
  canonical_value_text: "Peter Mokoena",
  status: :candidate,
  confidence: 0.63
)

IntakeFieldValue.create!(
  intake_session: session_completed,
  intake_field: fields.fetch("full_name"),
  source_message: lebo_inbound,
  canonical_value_text: "Lebo Khumalo",
  status: :complete,
  confidence: 0.99
)
IntakeFieldValue.create!(
  intake_session: session_completed,
  intake_field: fields.fetch("id_number"),
  source_message: lebo_inbound,
  canonical_value_text: "9202125123088",
  status: :complete,
  confidence: 0.98
)
IntakeFieldValue.create!(
  intake_session: session_completed,
  intake_field: fields.fetch("medical_aid_provider"),
  source_message: lebo_inbound,
  canonical_value_text: "FedHealth FlexiFed",
  status: :complete,
  confidence: 0.94
)
IntakeFieldValue.create!(
  intake_session: session_completed,
  intake_field: fields.fetch("medical_aid_number"),
  source_message: lebo_inbound,
  canonical_value_text: "123456789",
  status: :complete,
  confidence: 0.93
)

IntakeFieldValue.create!(
  intake_session: session_follow_up,
  intake_field: fields.fetch("follow_up_reason"),
  source_message: follow_up_inbound,
  canonical_value_text: "Persistent dizziness and headaches",
  status: :complete,
  confidence: 0.91
)
IntakeFieldValue.create!(
  intake_session: session_follow_up,
  intake_field: fields.fetch("current_symptoms"),
  source_message: follow_up_inbound,
  canonical_value_text: "Dizziness and morning headaches",
  status: :candidate,
  confidence: 0.76
)

[
  [ session_review_queue, "session_started", { by: "maya.admin@medicomm-demo.co.za" }, 3.hours.ago ],
  [ session_review_queue, "message_received", { provider_message_id: nomsa_inbound_1.provider_message_id }, 2.hours.ago ],
  [ session_review_queue, "attachment_processed", { attachment: nomsa_id_attachment.file_name }, 95.minutes.ago ],
  [ session_active, "session_started", { by: "johan.staff@medicomm-demo.co.za" }, 90.minutes.ago ],
  [ session_active, "message_received", { provider_message_id: peter_inbound.provider_message_id }, 55.minutes.ago ],
  [ session_completed, "review_approved", { reviewer: "anele.owner@medicomm-demo.co.za" }, 20.hours.ago ],
  [ session_follow_up, "clarification_requested", { reason: "symptom duration missing" }, 2.hours.ago ]
].each do |session, event_type, payload, timestamp|
  IntakeEvent.create!(
    intake_session: session,
    event_type: event_type,
    payload_json: payload,
    created_at: timestamp,
    updated_at: timestamp
  )
end

SessionReview.create!(
  intake_session: session_review_queue,
  reviewer: staff,
  status: :pending,
  notes: "Medical aid number needs confirmation.",
  reviewed_at: nil
)

SessionReview.create!(
  intake_session: session_completed,
  reviewer: owner,
  status: :approved,
  notes: "All mandatory fields captured with high confidence.",
  reviewed_at: 20.hours.ago
)

SessionReview.create!(
  intake_session: session_follow_up,
  reviewer: admin,
  status: :needs_follow_up,
  notes: "Requested additional detail on symptom duration and medication response.",
  reviewed_at: 2.hours.ago
)

ExportedDocument.create!(
  intake_session: session_completed,
  document_type: "completion_summary",
  storage_key: "demo/exports/session-#{session_completed.id}-summary.pdf",
  status: "generated",
  generated_at: 19.hours.ago
)

puts "Seed complete."
puts "Practice: #{practice.name}"
puts "Users: #{practice.users.count}, Flows: #{practice.intake_flows.count}, Sessions: #{practice.intake_sessions.count}"
