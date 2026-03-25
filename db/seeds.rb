puts "Seeding MediComm Phase 2 data..."

# [
#   ExportedDocument,
#   SessionReview,
#   IntakeEvent,
#   IntakeFieldValue,
#   IntakeAttachment,
#   IntakeMessage,
#   IntakeSession,
#   IntakeField,
#   IntakeFieldGroup,
#   IntakeFlow,
#   WhatsappAccount,
#   User,
#   Practice
# ].each(&:delete_all)

# practice = Practice.create!(
#   name: "MediComm Demo Practice",
#   slug: "medicomm-demo-practice",
#   timezone: "Africa/Johannesburg",
#   contact_email: "ops@medicomm-demo.co.za",
#   status: "active"
# )

# owner = User.create!(
#   practice: practice,
#   first_name: "Anele",
#   last_name: "Ndlovu",
#   email: "anele.owner@medicomm-demo.co.za",
#   password: "password123",
#   password_confirmation: "password123",
#   role: :owner,
#   active: true
# )

# admin = User.create!(
#   practice: practice,
#   first_name: "Maya",
#   last_name: "Patel",
#   email: "maya.admin@medicomm-demo.co.za",
#   password: "password123",
#   password_confirmation: "password123",
#   role: :admin,
#   active: true
# )

# staff = User.create!(
#   practice: practice,
#   first_name: "Johan",
#   last_name: "Botha",
#   email: "johan.staff@medicomm-demo.co.za",
#   password: "password123",
#   password_confirmation: "password123",
#   role: :staff,
#   active: true
# )

# read_only = User.create!(
#   practice: practice,
#   first_name: "Ruth",
#   last_name: "Molefe",
#   email: "ruth.readonly@medicomm-demo.co.za",
#   password: "password123",
#   password_confirmation: "password123",
#   role: :read_only,
#   active: true
# )

# whatsapp_account = WhatsappAccount.create!(
#   practice: practice,
#   phone_number_id: "155512300001",
#   waba_id: "waba-za-demo-001",
#   display_phone_number: "+27 71 555 1000",
#   webhook_verify_token: "demo-verify-token-001",
#   app_secret_ciphertext: "demo-app-secret-001",
#   access_token_ciphertext: "encrypted-demo-token",
#   business_account_name: "MediComm Intake",
#   active: true
# )

# new_patient_flow = IntakeFlow.create!(
#   practice: practice,
#   created_by: owner,
#   name: "New Patient Intake",
#   flow_type: "new_patient",
#   status: :published,
#   description: "Collect core demographics, medical aid details, and required document uploads.",
#   default_language: "en-ZA",
#   tone_preset: "professional",
#   allow_skip_by_default: false,
#   completion_email_enabled: true,
#   completion_email_recipients_json: [ "intake@medicomm-demo.co.za" ],
#   published_at: 5.days.ago
# )

# follow_up_flow = IntakeFlow.create!(
#   practice: practice,
#   created_by: admin,
#   name: "Follow-up Intake",
#   flow_type: "follow_up",
#   status: :published,
#   description: "Collect follow-up symptoms and medication changes before return visit.",
#   default_language: "en-ZA",
#   tone_preset: "empathetic",
#   allow_skip_by_default: true,
#   completion_email_enabled: false,
#   completion_email_recipients_json: [],
#   published_at: 3.days.ago
# )

# patient_group = IntakeFieldGroup.create!(
#   intake_flow: new_patient_flow,
#   key: "patient_details",
#   label: "Patient Details",
#   position: 1,
#   repeatable: false,
#   visibility_rules_json: {}
# )

# medical_aid_group = IntakeFieldGroup.create!(
#   intake_flow: new_patient_flow,
#   key: "medical_aid",
#   label: "Medical Aid",
#   position: 2,
#   repeatable: false,
#   visibility_rules_json: {}
# )

# uploads_group = IntakeFieldGroup.create!(
#   intake_flow: new_patient_flow,
#   key: "uploads",
#   label: "Required Uploads",
#   position: 3,
#   repeatable: false,
#   visibility_rules_json: {}
# )

# follow_up_group = IntakeFieldGroup.create!(
#   intake_flow: follow_up_flow,
#   key: "follow_up_details",
#   label: "Follow-up Details",
#   position: 1,
#   repeatable: false,
#   visibility_rules_json: {}
# )

# fields = {}
# base_ai_prompt_hints = {
#   "full_name" => "Extract the patient's full legal name; include middle names when present and exclude titles.",
#   "id_number" => "Extract the South African ID number as 13 digits, removing spaces/punctuation.",
#   "date_of_birth" => "Extract date of birth and normalize to YYYY-MM-DD.",
#   "phone_number" => "Extract the primary contact number and normalize to E.164 when possible.",
#   "medical_aid_provider" => "Extract the medical aid provider name only.",
#   "medical_aid_number" => "Extract the medical aid membership number exactly as provided.",
#   "id_document_upload" => "Confirm patient ID document image or PDF was received.",
#   "medical_aid_card_upload" => "Confirm medical aid card image or PDF was received.",
#   "follow_up_reason" => "Summarize the patient's main reason for follow-up in one short phrase.",
#   "current_symptoms" => "Extract current symptoms verbatim and keep clinical wording concise.",
#   "medication_changes" => "Extract any medication changes, additions, or stoppages.",
#   "latest_test_results" => "Confirm upload of latest lab or imaging results."
# }

# base_source_preferences = {
#   "id_document_upload" => "attachment",
#   "medical_aid_card_upload" => "attachment",
#   "latest_test_results" => "attachment",
#   "id_number" => "ocr",
#   "date_of_birth" => "ocr"
# }

# [
#   [ patient_group, "full_name", "Full Name", "text", true, 1 ],
#   [ patient_group, "id_number", "ID Number", "text", true, 2 ],
#   [ patient_group, "date_of_birth", "Date of Birth", "date", true, 3 ],
#   [ patient_group, "phone_number", "Phone Number", "phone", true, 4 ],
#   [ medical_aid_group, "medical_aid_provider", "Medical Aid Provider", "text", true, 5 ],
#   [ medical_aid_group, "medical_aid_number", "Medical Aid Number", "text", true, 6 ],
#   [ uploads_group, "id_document_upload", "ID Document Upload", "file", true, 7 ],
#   [ uploads_group, "medical_aid_card_upload", "Medical Aid Card Upload", "file", false, 8 ]
# ].each do |group, key, label, field_type, required, ask_priority|
#   fields[key] = IntakeField.create!(
#     intake_flow: new_patient_flow,
#     intake_field_group: group,
#     key: key,
#     label: label,
#     field_type: field_type,
#     required: required,
#     ask_priority: ask_priority,
#     extraction_enabled: true,
#     source_preference: base_source_preferences[key] || "any",
#     ai_prompt_hint: base_ai_prompt_hints[key] || "Extract '#{label}' from patient input and normalize for structured storage.",
#     autofill_pdf_key: "new_patient.#{key}",
#     validation_rules_json: {},
#     branching_rules_json: {},
#     skip_rules_json: {},
#     example_values_json: [],
#     active: true
#   )
# end

# [
#   [ "follow_up_reason", "Follow-up Reason", "text", true, 1 ],
#   [ "current_symptoms", "Current Symptoms", "text", true, 2 ],
#   [ "medication_changes", "Medication Changes", "text", false, 3 ],
#   [ "latest_test_results", "Latest Test Results Upload", "file", false, 4 ]
# ].each do |key, label, field_type, required, ask_priority|
#   fields[key] = IntakeField.create!(
#     intake_flow: follow_up_flow,
#     intake_field_group: follow_up_group,
#     key: key,
#     label: label,
#     field_type: field_type,
#     required: required,
#     ask_priority: ask_priority,
#     extraction_enabled: true,
#     source_preference: base_source_preferences[key] || "any",
#     ai_prompt_hint: base_ai_prompt_hints[key] || "Extract '#{label}' from patient follow-up responses for structured capture.",
#     autofill_pdf_key: "follow_up.#{key}",
#     validation_rules_json: {},
#     branching_rules_json: {},
#     skip_rules_json: {},
#     example_values_json: [],
#     active: true
#   )
# end

# session_review_queue = IntakeSession.create!(
#   practice: practice,
#   intake_flow: new_patient_flow,
#   whatsapp_account: whatsapp_account,
#   initiated_by_user: admin,
#   patient_phone_e164: "+27824567891",
#   patient_display_name: "Nomsa Dlamini",
#   external_reference: "NP-2026-0001",
#   status: :awaiting_staff_review,
#   language: "en-ZA",
#   started_at: 3.hours.ago,
#   completed_at: nil
# )

# session_active = IntakeSession.create!(
#   practice: practice,
#   intake_flow: new_patient_flow,
#   whatsapp_account: whatsapp_account,
#   initiated_by_user: staff,
#   patient_phone_e164: "+27835551234",
#   patient_display_name: "Peter Mokoena",
#   external_reference: "NP-2026-0002",
#   status: :active,
#   language: "en-ZA",
#   started_at: 90.minutes.ago,
#   completed_at: nil
# )

# session_completed = IntakeSession.create!(
#   practice: practice,
#   intake_flow: new_patient_flow,
#   whatsapp_account: whatsapp_account,
#   initiated_by_user: owner,
#   patient_phone_e164: "+27824449988",
#   patient_display_name: "Lebo Khumalo",
#   external_reference: "NP-2026-0003",
#   status: :completed,
#   language: "en-ZA",
#   started_at: 1.day.ago,
#   completed_at: 20.hours.ago
# )

# session_follow_up = IntakeSession.create!(
#   practice: practice,
#   intake_flow: follow_up_flow,
#   whatsapp_account: whatsapp_account,
#   initiated_by_user: admin,
#   patient_phone_e164: "+27837770011",
#   patient_display_name: "Thandi Radebe",
#   external_reference: "FU-2026-0001",
#   status: :awaiting_patient,
#   language: "en-ZA",
#   started_at: 5.hours.ago,
#   completed_at: nil
# )

# message_counter = 0

# create_message = lambda do |session:, direction:, type:, text:, timestamp:|
#   message_counter += 1
#   IntakeMessage.create!(
#     intake_session: session,
#     direction: direction,
#     message_type: type,
#     text_body: text,
#     provider_message_id: "wa-msg-#{message_counter.to_s.rjust(5, '0')}",
#     created_at: timestamp,
#     updated_at: timestamp
#   )
# end

# nomsa_outbound = create_message.call(
#   session: session_review_queue,
#   direction: :outbound,
#   type: "text",
#   text: "Welcome Nomsa. Please share your full name, ID number, and medical aid details.",
#   timestamp: 3.hours.ago
# )
# nomsa_inbound_1 = create_message.call(
#   session: session_review_queue,
#   direction: :inbound,
#   type: "text",
#   text: "Nomsa Dlamini, 9001011234089, Discovery Classic Smart.",
#   timestamp: 2.hours.ago
# )
# nomsa_inbound_2 = create_message.call(
#   session: session_review_queue,
#   direction: :inbound,
#   type: "image",
#   text: "Here is my ID photo.",
#   timestamp: 100.minutes.ago
# )

# nomsa_id_attachment = IntakeAttachment.create!(
#   intake_session: session_review_queue,
#   intake_message: nomsa_inbound_2,
#   mime_type: "image/jpeg",
#   s3_key: "demo/intake/nomsa/id-card.jpg",
#   file_name: "nomsa-id.jpg",
#   byte_size: 412_000,
#   processing_status: "processed",
#   created_at: 99.minutes.ago,
#   updated_at: 99.minutes.ago
# )

# create_message.call(
#   session: session_active,
#   direction: :outbound,
#   type: "text",
#   text: "Hi Peter, please send your ID number and medical aid card.",
#   timestamp: 80.minutes.ago
# )
# peter_inbound = create_message.call(
#   session: session_active,
#   direction: :inbound,
#   type: "text",
#   text: "My ID is 8507074567081. Medical aid card coming shortly.",
#   timestamp: 55.minutes.ago
# )

# create_message.call(
#   session: session_completed,
#   direction: :outbound,
#   type: "text",
#   text: "Thanks Lebo, your intake is complete.",
#   timestamp: 22.hours.ago
# )
# lebo_inbound = create_message.call(
#   session: session_completed,
#   direction: :inbound,
#   type: "text",
#   text: "Lebo Khumalo, 9202125123088, FedHealth FlexiFed 123456789.",
#   timestamp: 25.hours.ago
# )

# create_message.call(
#   session: session_follow_up,
#   direction: :outbound,
#   type: "text",
#   text: "Please share your follow-up reason and current symptoms.",
#   timestamp: 4.hours.ago
# )
# follow_up_inbound = create_message.call(
#   session: session_follow_up,
#   direction: :inbound,
#   type: "text",
#   text: "I still have dizziness and headaches in the mornings.",
#   timestamp: 3.hours.ago
# )

# IntakeFieldValue.create!(
#   intake_session: session_review_queue,
#   intake_field: fields.fetch("full_name"),
#   source_message: nomsa_inbound_1,
#   canonical_value_text: "Nomsa Dlamini",
#   status: :complete,
#   confidence: 0.99
# )
# IntakeFieldValue.create!(
#   intake_session: session_review_queue,
#   intake_field: fields.fetch("id_number"),
#   source_message: nomsa_inbound_1,
#   canonical_value_text: "9001011234089",
#   status: :complete,
#   confidence: 0.97
# )
# IntakeFieldValue.create!(
#   intake_session: session_review_queue,
#   intake_field: fields.fetch("medical_aid_provider"),
#   source_message: nomsa_inbound_1,
#   canonical_value_text: "Discovery Classic Smart",
#   status: :complete,
#   confidence: 0.92
# )
# IntakeFieldValue.create!(
#   intake_session: session_review_queue,
#   intake_field: fields.fetch("medical_aid_number"),
#   source_message: nomsa_inbound_1,
#   canonical_value_text: "Unclear from message",
#   status: :needs_clarification,
#   confidence: 0.52
# )
# IntakeFieldValue.create!(
#   intake_session: session_review_queue,
#   intake_field: fields.fetch("id_document_upload"),
#   source_message: nomsa_inbound_2,
#   source_attachment: nomsa_id_attachment,
#   canonical_value_text: "Uploaded: nomsa-id.jpg",
#   status: :complete,
#   confidence: 0.95
# )

# IntakeFieldValue.create!(
#   intake_session: session_active,
#   intake_field: fields.fetch("id_number"),
#   source_message: peter_inbound,
#   canonical_value_text: "8507074567081",
#   status: :candidate,
#   confidence: 0.74
# )
# IntakeFieldValue.create!(
#   intake_session: session_active,
#   intake_field: fields.fetch("full_name"),
#   canonical_value_text: "Peter Mokoena",
#   status: :candidate,
#   confidence: 0.63
# )

# IntakeFieldValue.create!(
#   intake_session: session_completed,
#   intake_field: fields.fetch("full_name"),
#   source_message: lebo_inbound,
#   canonical_value_text: "Lebo Khumalo",
#   status: :complete,
#   confidence: 0.99
# )
# IntakeFieldValue.create!(
#   intake_session: session_completed,
#   intake_field: fields.fetch("id_number"),
#   source_message: lebo_inbound,
#   canonical_value_text: "9202125123088",
#   status: :complete,
#   confidence: 0.98
# )
# IntakeFieldValue.create!(
#   intake_session: session_completed,
#   intake_field: fields.fetch("medical_aid_provider"),
#   source_message: lebo_inbound,
#   canonical_value_text: "FedHealth FlexiFed",
#   status: :complete,
#   confidence: 0.94
# )
# IntakeFieldValue.create!(
#   intake_session: session_completed,
#   intake_field: fields.fetch("medical_aid_number"),
#   source_message: lebo_inbound,
#   canonical_value_text: "123456789",
#   status: :complete,
#   confidence: 0.93
# )

# IntakeFieldValue.create!(
#   intake_session: session_follow_up,
#   intake_field: fields.fetch("follow_up_reason"),
#   source_message: follow_up_inbound,
#   canonical_value_text: "Persistent dizziness and headaches",
#   status: :complete,
#   confidence: 0.91
# )
# IntakeFieldValue.create!(
#   intake_session: session_follow_up,
#   intake_field: fields.fetch("current_symptoms"),
#   source_message: follow_up_inbound,
#   canonical_value_text: "Dizziness and morning headaches",
#   status: :candidate,
#   confidence: 0.76
# )

# [
#   [ session_review_queue, "session_started", { by: "maya.admin@medicomm-demo.co.za" }, 3.hours.ago ],
#   [ session_review_queue, "message_received", { provider_message_id: nomsa_inbound_1.provider_message_id }, 2.hours.ago ],
#   [ session_review_queue, "attachment_processed", { attachment: nomsa_id_attachment.file_name }, 95.minutes.ago ],
#   [ session_active, "session_started", { by: "johan.staff@medicomm-demo.co.za" }, 90.minutes.ago ],
#   [ session_active, "message_received", { provider_message_id: peter_inbound.provider_message_id }, 55.minutes.ago ],
#   [ session_completed, "review_approved", { reviewer: "anele.owner@medicomm-demo.co.za" }, 20.hours.ago ],
#   [ session_follow_up, "clarification_requested", { reason: "symptom duration missing" }, 2.hours.ago ]
# ].each do |session, event_type, payload, timestamp|
#   IntakeEvent.create!(
#     intake_session: session,
#     event_type: event_type,
#     payload_json: payload,
#     created_at: timestamp,
#     updated_at: timestamp
#   )
# end

# SessionReview.create!(
#   intake_session: session_review_queue,
#   reviewer: staff,
#   status: :pending,
#   notes: "Medical aid number needs confirmation.",
#   reviewed_at: nil
# )

# SessionReview.create!(
#   intake_session: session_completed,
#   reviewer: owner,
#   status: :approved,
#   notes: "All mandatory fields captured with high confidence.",
#   reviewed_at: 20.hours.ago
# )

# SessionReview.create!(
#   intake_session: session_follow_up,
#   reviewer: admin,
#   status: :needs_follow_up,
#   notes: "Requested additional detail on symptom duration and medication response.",
#   reviewed_at: 2.hours.ago
# )

# ExportedDocument.create!(
#   intake_session: session_completed,
#   document_type: "completion_summary",
#   storage_key: "demo/exports/session-#{session_completed.id}-summary.pdf",
#   status: "generated",
#   generated_at: 19.hours.ago
# )

# puts "Seed complete."
# puts "Practice: #{practice.name}"
# puts "Users: #{practice.users.count}, Flows: #{practice.intake_flows.count}, Sessions: #{practice.intake_sessions.count}"


# Build the seeding data here from the screenshot provided.
# Practice id: 2
paper_practice = Practice.find_by(id: 2)
paper_practice ||= Practice.create!(
  id: 2,
  name: "MediComm Paper Intake Practice",
  slug: "medicomm-paper-intake-practice",
  timezone: "Africa/Johannesburg",
  contact_email: "ops@medicomm-paper.co.za",
  status: "active"
)

# paper_owner = User.find_or_create_by!(email: "owner@medicomm-paper.co.za") do |user|
#   user.practice = paper_practice
#   user.first_name = "Nadia"
#   user.last_name = "Naidoo"
#   user.password = "password123"
#   user.password_confirmation = "password123"
#   user.role = :owner
#   user.active = true
# end

paper_flow = IntakeFlow.find_or_create_by!(
  practice: paper_practice,
  name: "Patient Information Form Intake"
)
#  do |flow|
#   flow.created_by = paper_owner
#   flow.flow_type = "new_patient"
#   flow.status = :published
#   flow.description = "Digitized intake based on the patient information paper form."
#   flow.default_language = "en-ZA"
#   flow.tone_preset = "professional"
#   flow.allow_skip_by_default = false
#   flow.completion_email_enabled = true
#   flow.completion_email_recipients_json = [ "intake@medicomm-paper.co.za" ]
#   flow.published_at = Time.current
# end

group_attributes = [
  [ "patient_information", "Patient Information", 1 ],
  [ "referral_and_claims", "For Purposes of Referral Letters and Medical Aid Claims", 2 ],
  [ "payment_responsible_party", "Person Responsible for Payment / Main Member of Medical Aid", 3 ],
  [ "contact_person_not_at_same_address", "Contact Person / Friend Not Living at Same Address", 4 ]
]

paper_groups = {}
group_visibility_rules = {
  "patient_information" => {},
  "referral_and_claims" => {
    "operator" => "any",
    "conditions" => [
      { "field_key" => "referral_optometrist_name", "op" => "present" },
      { "field_key" => "referral_gp_name", "op" => "present" },
      { "field_key" => "referral_specialist_name", "op" => "present" }
    ]
  },
  "payment_responsible_party" => {},
  "contact_person_not_at_same_address" => {}
}

group_attributes.each do |key, label, position|
  group = IntakeFieldGroup.find_or_initialize_by(intake_flow: paper_flow, key: key)
  group.assign_attributes(
    label: label,
    position: position,
    repeatable: false,
    visibility_rules_json: group_visibility_rules[key] || {}
  )
  group.save!
  paper_groups[key] = group
end

paper_fields = [
  [ "patient_surname", "Surname", "text", true, "patient_information" ],
  [ "patient_full_names", "Full Names", "text", true, "patient_information" ],
  [ "patient_preferred_first_name", "Preferred 1st Name", "text", false, "patient_information" ],
  [ "patient_language", "Language", "text", false, "patient_information" ],
  [ "patient_title", "Title", "select", false, "patient_information" ],
  [ "patient_age", "Age", "number", false, "patient_information" ],
  [ "patient_id_number", "ID Nr", "text", true, "patient_information" ],
  [ "patient_cell_phone", "Contact Cell", "phone", true, "patient_information" ],
  [ "patient_home_phone", "Contact Home", "phone", false, "patient_information" ],
  [ "patient_work_phone", "Contact Work", "phone", false, "patient_information" ],
  [ "patient_email", "Email", "email", false, "patient_information" ],
  [ "patient_employer", "Employer", "text", false, "patient_information" ],
  [ "patient_occupation", "Occupation", "text", false, "patient_information" ],
  [ "patient_self_employed_business_name", "If Self Employed, Name of Business", "text", false, "patient_information" ],

  [ "referral_optometrist_name", "Optometrist", "text", false, "referral_and_claims" ],
  [ "referral_optometrist_address", "Optometrist Address", "long_text", false, "referral_and_claims" ],
  [ "referral_optometrist_tel", "Optometrist Tel", "phone", false, "referral_and_claims" ],
  [ "referral_gp_name", "GP", "text", false, "referral_and_claims" ],
  [ "referral_gp_address", "GP Address", "long_text", false, "referral_and_claims" ],
  [ "referral_gp_tel", "GP Tel", "phone", false, "referral_and_claims" ],
  [ "referral_specialist_name", "Specialist", "text", false, "referral_and_claims" ],
  [ "referral_specialist_address", "Specialist Address", "long_text", false, "referral_and_claims" ],
  [ "referral_specialist_tel", "Specialist Tel", "phone", false, "referral_and_claims" ],

  [ "responsible_surname", "Responsible Person Surname", "text", true, "payment_responsible_party" ],
  [ "responsible_full_names", "Responsible Person Full Names", "text", true, "payment_responsible_party" ],
  [ "responsible_title", "Responsible Person Title", "select", false, "payment_responsible_party" ],
  [ "responsible_id_number", "Responsible Person ID Nr", "text", false, "payment_responsible_party" ],
  [ "responsible_residential_address", "Residential Address", "long_text", true, "payment_responsible_party" ],
  [ "responsible_residential_postal_code", "Residential Postal Code", "text", false, "payment_responsible_party" ],
  [ "responsible_postal_address", "Postal Address (If Different)", "long_text", false, "payment_responsible_party" ],
  [ "responsible_postal_code", "Postal Code", "text", false, "payment_responsible_party" ],
  [ "responsible_cell_phone", "Responsible Contact Cell", "phone", true, "payment_responsible_party" ],
  [ "responsible_home_phone", "Responsible Contact Home", "phone", false, "payment_responsible_party" ],
  [ "responsible_work_phone", "Responsible Contact Work", "phone", false, "payment_responsible_party" ],
  [ "responsible_email", "Responsible Email", "email", false, "payment_responsible_party" ],
  [ "responsible_employer", "Responsible Employer", "text", false, "payment_responsible_party" ],
  [ "responsible_medical_aid_name", "Medical Aid", "text", false, "payment_responsible_party" ],
  [ "responsible_medical_aid_plan_option", "Medical Aid Plan / Option", "text", false, "payment_responsible_party" ],
  [ "responsible_medical_aid_number", "Medical Aid Number", "text", false, "payment_responsible_party" ],

  [ "contact_person_name", "Contact Person Name", "text", true, "contact_person_not_at_same_address" ],
  [ "contact_person_relationship", "Relationship", "text", true, "contact_person_not_at_same_address" ],
  [ "contact_person_cell_phone", "Contact Person Cell", "phone", true, "contact_person_not_at_same_address" ],
  [ "contact_person_email", "Contact Person Email", "email", false, "contact_person_not_at_same_address" ]
]

validation_rules_by_key = {
  "patient_surname" => { "min_length" => 2, "max_length" => 80, "disallow_numbers" => true },
  "patient_full_names" => { "required" => true, "min_words" => 2, "max_words" => 5, "disallow_numbers" => true },
  "patient_preferred_first_name" => { "min_length" => 2, "max_length" => 60, "disallow_numbers" => true },
  "patient_language" => { "allowed_values" => [ "English", "Afrikaans", "Zulu", "Xhosa", "Sotho", "Tswana" ] },
  "patient_title" => { "allowed_values" => [ "Mr", "Mrs", "Ms", "Miss", "Dr", "Prof" ] },
  "patient_age" => { "min" => 0, "max" => 120 },
  "patient_id_number" => {
    "type" => "za_id_number",
    "digits_only" => true,
    "exact_length" => 13,
    "strip_non_digits_before_validation" => true
  },
  "patient_cell_phone" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "patient_home_phone" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "patient_work_phone" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "patient_email" => { "type" => "email" },
  "patient_employer" => { "max_length" => 120 },
  "patient_occupation" => { "max_length" => 120 },
  "patient_self_employed_business_name" => { "max_length" => 120 },
  "referral_optometrist_tel" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "referral_gp_tel" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "referral_specialist_tel" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "responsible_id_number" => { "type" => "za_id_number", "digits_only" => true, "exact_length" => 13 },
  "responsible_residential_postal_code" => { "pattern" => "^\\d{4}$" },
  "responsible_postal_code" => { "pattern" => "^\\d{4}$" },
  "responsible_cell_phone" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "responsible_home_phone" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "responsible_work_phone" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "responsible_email" => { "type" => "email" },
  "responsible_medical_aid_number" => { "min_length" => 4, "max_length" => 30 },
  "contact_person_cell_phone" => { "type" => "phone_e164_or_local_za", "min_length" => 10, "max_length" => 15 },
  "contact_person_email" => { "type" => "email" }
}

branching_rules_by_key = {
  "patient_surname" => {
    "linked_field_keys" => [
      "patient_full_names",
      "patient_preferred_first_name",
      "patient_language",
      "patient_title",
      "patient_id_number",
      "patient_cell_phone",
      "patient_email"
    ]
  },
  "patient_occupation" => {
    "on_complete" => [
      {
        "if" => { "field_key" => "patient_occupation", "op" => "contains_any", "value" => [ "self", "self-employed" ] },
        "then" => { "activate_field" => "patient_self_employed_business_name" }
      }
    ]
  },
  "responsible_surname" => {
    "linked_field_keys" => [
      "responsible_full_names",
      "responsible_title",
      "responsible_id_number",
      "responsible_residential_address",
      "responsible_residential_postal_code",
      "responsible_postal_address",
      "responsible_postal_code",
      "responsible_cell_phone",
      "responsible_home_phone",
      "responsible_work_phone",
      "responsible_email",
      "responsible_employer",
      "responsible_medical_aid_name",
      "responsible_medical_aid_plan_option",
      "responsible_medical_aid_number"
    ]
  },
  "contact_person_name" => {
    "linked_field_keys" => [
      "contact_person_relationship",
      "contact_person_cell_phone",
      "contact_person_email"
    ]
  },
  "responsible_medical_aid_name" => {
    "on_complete" => [
      {
        "if" => { "field_key" => "responsible_medical_aid_name", "op" => "present" },
        "then" => { "activate_field" => "responsible_medical_aid_plan_option" }
      },
      {
        "if" => { "field_key" => "responsible_medical_aid_name", "op" => "present" },
        "then" => { "activate_field" => "responsible_medical_aid_number" }
      }
    ]
  }
}

skip_rules_by_key = {
  "patient_self_employed_business_name" => {
    "operator" => "all",
    "skip_if" => [
      {
        "field_key" => "patient_occupation",
        "op" => "not_contains_any",
        "value" => [ "self", "self-employed" ]
      }
    ]
  },
  "referral_optometrist_address" => {
    "operator" => "all",
    "skip_if" => [ { "field_key" => "referral_optometrist_name", "op" => "blank" } ]
  },
  "referral_optometrist_tel" => {
    "operator" => "all",
    "skip_if" => [ { "field_key" => "referral_optometrist_name", "op" => "blank" } ]
  },
  "referral_gp_address" => {
    "operator" => "all",
    "skip_if" => [ { "field_key" => "referral_gp_name", "op" => "blank" } ]
  },
  "referral_gp_tel" => {
    "operator" => "all",
    "skip_if" => [ { "field_key" => "referral_gp_name", "op" => "blank" } ]
  },
  "referral_specialist_address" => {
    "operator" => "all",
    "skip_if" => [ { "field_key" => "referral_specialist_name", "op" => "blank" } ]
  },
  "referral_specialist_tel" => {
    "operator" => "all",
    "skip_if" => [ { "field_key" => "referral_specialist_name", "op" => "blank" } ]
  },
  "responsible_medical_aid_plan_option" => {
    "operator" => "all",
    "skip_if" => [ { "field_key" => "responsible_medical_aid_name", "op" => "blank" } ]
  },
  "responsible_medical_aid_number" => {
    "operator" => "all",
    "skip_if" => [ { "field_key" => "responsible_medical_aid_name", "op" => "blank" } ]
  }
}

example_values_by_key = {
  "patient_surname" => [ "Mokoena" ],
  "patient_full_names" => [ "Naledi Mokoena" ],
  "patient_preferred_first_name" => [ "Naledi" ],
  "patient_language" => [ "English" ],
  "patient_title" => [ "Ms" ],
  "patient_age" => [ "34" ],
  "patient_id_number" => [ "9001011234089" ],
  "patient_cell_phone" => [ "+27821234567" ],
  "patient_home_phone" => [ "0111234567" ],
  "patient_work_phone" => [ "0211234567" ],
  "patient_email" => [ "naledi@example.com" ],
  "patient_employer" => [ "Acme Health" ],
  "patient_occupation" => [ "Teacher" ],
  "patient_self_employed_business_name" => [ "Naledi Consulting" ],
  "referral_optometrist_name" => [ "Dr M. Jacobs" ],
  "referral_optometrist_address" => [ "12 Main Rd, Durbanville" ],
  "referral_optometrist_tel" => [ "0219761000" ],
  "referral_gp_name" => [ "Dr L. Mthembu" ],
  "referral_gp_address" => [ "45 Oxford St, East London" ],
  "referral_gp_tel" => [ "0437002000" ],
  "referral_specialist_name" => [ "Dr P. Nkosi" ],
  "referral_specialist_address" => [ "9 Park Ave, Sandton" ],
  "referral_specialist_tel" => [ "0115559876" ],
  "responsible_surname" => [ "Mokoena" ],
  "responsible_full_names" => [ "Thabo Mokoena" ],
  "responsible_title" => [ "Mr" ],
  "responsible_id_number" => [ "8705055678081" ],
  "responsible_residential_address" => [ "22 Kloof Street, Cape Town" ],
  "responsible_residential_postal_code" => [ "8001" ],
  "responsible_postal_address" => [ "PO Box 123, Cape Town" ],
  "responsible_postal_code" => [ "8000" ],
  "responsible_cell_phone" => [ "+27829876543" ],
  "responsible_home_phone" => [ "0215551111" ],
  "responsible_work_phone" => [ "0215552222" ],
  "responsible_email" => [ "thabo@example.com" ],
  "responsible_employer" => [ "Acme Manufacturing" ],
  "responsible_medical_aid_name" => [ "Discovery" ],
  "responsible_medical_aid_plan_option" => [ "Classic Saver" ],
  "responsible_medical_aid_number" => [ "1234567890" ],
  "contact_person_name" => [ "Lerato Maseko" ],
  "contact_person_relationship" => [ "Sister" ],
  "contact_person_cell_phone" => [ "+27835550123" ],
  "contact_person_email" => [ "lerato@example.com" ]
}

paper_source_preferences = {
  "patient_id_number" => "ocr",
  "responsible_id_number" => "ocr",
  "patient_age" => "text",
  "patient_cell_phone" => "text",
  "patient_home_phone" => "text",
  "patient_work_phone" => "text",
  "patient_email" => "text",
  "referral_optometrist_tel" => "text",
  "referral_gp_tel" => "text",
  "referral_specialist_tel" => "text",
  "responsible_cell_phone" => "text",
  "responsible_home_phone" => "text",
  "responsible_work_phone" => "text",
  "responsible_email" => "text",
  "contact_person_cell_phone" => "text",
  "contact_person_email" => "text"
}

paper_ai_prompt_hints = {
  "patient_surname" => "Extract the patient's surname only; exclude titles and prefixes.",
  "patient_full_names" => "Extract the patient's full names as written on official documents.",
  "patient_preferred_first_name" => "Extract the patient's preferred first name or nickname used in communication.",
  "patient_language" => "Extract preferred communication language.",
  "patient_title" => "Extract honorific title such as Mr, Mrs, Ms, Dr, Prof.",
  "patient_age" => "Extract numeric age in years.",
  "patient_id_number" => "Extract South African ID number as exactly 13 digits; remove separators.",
  "patient_cell_phone" => "Extract patient's cellphone number and normalize where possible.",
  "patient_home_phone" => "Extract patient's home phone number if provided.",
  "patient_work_phone" => "Extract patient's work phone number if provided.",
  "patient_email" => "Extract patient's email address.",
  "patient_employer" => "Extract patient employer name.",
  "patient_occupation" => "Extract current occupation.",
  "patient_self_employed_business_name" => "Extract business name when patient is self-employed.",
  "referral_optometrist_name" => "Extract referring optometrist name.",
  "referral_optometrist_address" => "Extract optometrist practice address.",
  "referral_optometrist_tel" => "Extract optometrist telephone number.",
  "referral_gp_name" => "Extract GP name.",
  "referral_gp_address" => "Extract GP practice address.",
  "referral_gp_tel" => "Extract GP telephone number.",
  "referral_specialist_name" => "Extract specialist name.",
  "referral_specialist_address" => "Extract specialist practice address.",
  "referral_specialist_tel" => "Extract specialist telephone number.",
  "responsible_surname" => "Extract surname of person responsible for payment.",
  "responsible_full_names" => "Extract full names of person responsible for payment.",
  "responsible_title" => "Extract title for responsible person.",
  "responsible_id_number" => "Extract responsible person's South African ID number as 13 digits.",
  "responsible_residential_address" => "Extract responsible person's residential address.",
  "responsible_residential_postal_code" => "Extract residential postal code as 4 digits.",
  "responsible_postal_address" => "Extract postal address when different from residential.",
  "responsible_postal_code" => "Extract postal code for postal address.",
  "responsible_cell_phone" => "Extract responsible person's cellphone number.",
  "responsible_home_phone" => "Extract responsible person's home phone number.",
  "responsible_work_phone" => "Extract responsible person's work phone number.",
  "responsible_email" => "Extract responsible person's email address.",
  "responsible_employer" => "Extract employer of responsible person.",
  "responsible_medical_aid_name" => "Extract medical aid scheme name.",
  "responsible_medical_aid_plan_option" => "Extract medical aid plan or option name.",
  "responsible_medical_aid_number" => "Extract medical aid membership number.",
  "contact_person_name" => "Extract contact person full name.",
  "contact_person_relationship" => "Extract relationship of contact person to patient.",
  "contact_person_cell_phone" => "Extract contact person's cellphone number.",
  "contact_person_email" => "Extract contact person's email address."
}

paper_fields.each_with_index do |(key, label, field_type, required, group_key), index|
  group = paper_groups.fetch(group_key)
  field = IntakeField.find_or_initialize_by(intake_flow: paper_flow, key: key)
  field.assign_attributes(
    intake_field_group: group,
    label: label,
    field_type: field_type,
    required: required,
    ask_priority: index + 1,
    extraction_enabled: true,
    source_preference: paper_source_preferences[key] || "any",
    ai_prompt_hint: paper_ai_prompt_hints[key] || "Extract '#{label}' from intake responses and normalize for deterministic storage.",
    autofill_pdf_key: "paper_form.#{group_key}.#{key}",
    validation_rules_json: validation_rules_by_key[key] || {},
    branching_rules_json: branching_rules_by_key[key] || {},
    skip_rules_json: skip_rules_by_key[key] || {},
    example_values_json: example_values_by_key[key] || [],
    active: true
  )
  field.save!
end
