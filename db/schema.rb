# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_17_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "exported_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "document_type", default: "completion_summary", null: false
    t.datetime "generated_at"
    t.bigint "intake_session_id", null: false
    t.string "status", default: "pending", null: false
    t.string "storage_key"
    t.datetime "updated_at", null: false
    t.index ["intake_session_id"], name: "index_exported_documents_on_intake_session_id"
    t.index ["status"], name: "index_exported_documents_on_status"
  end

  create_table "intake_attachments", force: :cascade do |t|
    t.bigint "byte_size"
    t.datetime "created_at", null: false
    t.string "file_name", null: false
    t.bigint "intake_message_id"
    t.bigint "intake_session_id", null: false
    t.string "mime_type", null: false
    t.string "processing_status", default: "processed", null: false
    t.string "s3_key"
    t.datetime "updated_at", null: false
    t.index ["intake_message_id"], name: "index_intake_attachments_on_intake_message_id"
    t.index ["intake_session_id", "created_at"], name: "index_intake_attachments_on_intake_session_id_and_created_at"
    t.index ["intake_session_id"], name: "index_intake_attachments_on_intake_session_id"
  end

  create_table "intake_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.bigint "intake_session_id", null: false
    t.jsonb "payload_json", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_intake_events_on_event_type"
    t.index ["intake_session_id", "created_at"], name: "index_intake_events_on_intake_session_id_and_created_at"
    t.index ["intake_session_id"], name: "index_intake_events_on_intake_session_id"
  end

  create_table "intake_field_groups", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.bigint "intake_flow_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.boolean "repeatable", default: false, null: false
    t.datetime "updated_at", null: false
    t.jsonb "visibility_rules_json", default: {}, null: false
    t.index ["intake_flow_id", "archived_at"], name: "index_intake_field_groups_on_intake_flow_id_and_archived_at"
    t.index ["intake_flow_id", "key"], name: "index_intake_field_groups_on_intake_flow_id_and_key", unique: true
    t.index ["intake_flow_id", "position"], name: "index_intake_field_groups_on_intake_flow_id_and_position"
    t.index ["intake_flow_id"], name: "index_intake_field_groups_on_intake_flow_id"
  end

  create_table "intake_field_values", force: :cascade do |t|
    t.text "canonical_value_text"
    t.decimal "confidence", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "intake_field_id", null: false
    t.bigint "intake_session_id", null: false
    t.bigint "source_attachment_id"
    t.bigint "source_message_id"
    t.integer "status", default: 0, null: false
    t.bigint "superseded_by_id"
    t.datetime "updated_at", null: false
    t.bigint "verified_by_user_id"
    t.index ["intake_field_id"], name: "index_intake_field_values_on_intake_field_id"
    t.index ["intake_session_id", "intake_field_id"], name: "idx_on_intake_session_id_intake_field_id_e41f0ca4bc"
    t.index ["intake_session_id", "status"], name: "index_intake_field_values_on_intake_session_id_and_status"
    t.index ["intake_session_id"], name: "index_intake_field_values_on_intake_session_id"
    t.index ["source_attachment_id"], name: "index_intake_field_values_on_source_attachment_id"
    t.index ["source_message_id"], name: "index_intake_field_values_on_source_message_id"
    t.index ["superseded_by_id"], name: "index_intake_field_values_on_superseded_by_id"
    t.index ["verified_by_user_id"], name: "index_intake_field_values_on_verified_by_user_id"
  end

  create_table "intake_fields", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "ai_prompt_hint"
    t.integer "ask_priority", default: 0, null: false
    t.string "autofill_pdf_key"
    t.jsonb "branching_rules_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.jsonb "example_values_json", default: [], null: false
    t.boolean "extraction_enabled", default: true, null: false
    t.string "field_type", null: false
    t.bigint "intake_field_group_id"
    t.bigint "intake_flow_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.boolean "required", default: true, null: false
    t.jsonb "skip_rules_json", default: {}, null: false
    t.string "source_preference", default: "any", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validation_rules_json", default: {}, null: false
    t.index ["intake_field_group_id"], name: "index_intake_fields_on_intake_field_group_id"
    t.index ["intake_flow_id", "active"], name: "index_intake_fields_on_intake_flow_id_and_active"
    t.index ["intake_flow_id", "ask_priority"], name: "index_intake_fields_on_intake_flow_id_and_ask_priority"
    t.index ["intake_flow_id", "key"], name: "index_intake_fields_on_intake_flow_id_and_key", unique: true
    t.index ["intake_flow_id"], name: "index_intake_fields_on_intake_flow_id"
  end

  create_table "intake_flows", force: :cascade do |t|
    t.boolean "allow_skip_by_default", default: false, null: false
    t.boolean "completion_email_enabled", default: false, null: false
    t.jsonb "completion_email_recipients_json", default: [], null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "default_language", default: "en-ZA", null: false
    t.text "description"
    t.string "flow_type", null: false
    t.string "name", null: false
    t.bigint "practice_id", null: false
    t.datetime "published_at"
    t.integer "status", default: 0, null: false
    t.string "tone_preset", default: "professional", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_intake_flows_on_created_by_id"
    t.index ["practice_id", "name"], name: "index_intake_flows_on_practice_id_and_name"
    t.index ["practice_id", "status"], name: "index_intake_flows_on_practice_id_and_status"
    t.index ["practice_id"], name: "index_intake_flows_on_practice_id"
  end

  create_table "intake_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "direction", default: 0, null: false
    t.bigint "intake_session_id", null: false
    t.string "message_type", default: "text", null: false
    t.string "provider_message_id"
    t.text "text_body"
    t.datetime "updated_at", null: false
    t.index ["intake_session_id", "created_at"], name: "index_intake_messages_on_intake_session_id_and_created_at"
    t.index ["intake_session_id"], name: "index_intake_messages_on_intake_session_id"
    t.index ["provider_message_id"], name: "index_intake_messages_on_provider_message_id", unique: true, where: "(provider_message_id IS NOT NULL)"
  end

  create_table "intake_sessions", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "external_reference"
    t.bigint "initiated_by_user_id", null: false
    t.bigint "intake_flow_id", null: false
    t.string "language", default: "en-ZA", null: false
    t.string "patient_display_name", null: false
    t.string "patient_phone_e164", null: false
    t.bigint "practice_id", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "whatsapp_account_id", null: false
    t.index ["external_reference"], name: "index_intake_sessions_on_external_reference"
    t.index ["initiated_by_user_id"], name: "index_intake_sessions_on_initiated_by_user_id"
    t.index ["intake_flow_id"], name: "index_intake_sessions_on_intake_flow_id"
    t.index ["patient_phone_e164"], name: "index_intake_sessions_on_patient_phone_e164"
    t.index ["practice_id", "status"], name: "index_intake_sessions_on_practice_id_and_status"
    t.index ["practice_id", "updated_at"], name: "index_intake_sessions_on_practice_id_and_updated_at"
    t.index ["practice_id"], name: "index_intake_sessions_on_practice_id"
    t.index ["whatsapp_account_id"], name: "index_intake_sessions_on_whatsapp_account_id"
  end

  create_table "practices", force: :cascade do |t|
    t.string "contact_email", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.string "timezone", default: "Africa/Johannesburg", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_practices_on_slug", unique: true
    t.index ["status"], name: "index_practices_on_status"
  end

  create_table "session_reviews", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "intake_session_id", null: false
    t.text "notes"
    t.datetime "reviewed_at"
    t.bigint "reviewer_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["intake_session_id"], name: "index_session_reviews_on_intake_session_id", unique: true
    t.index ["reviewer_id"], name: "index_session_reviews_on_reviewer_id"
    t.index ["status"], name: "index_session_reviews_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.bigint "practice_id", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["practice_id"], name: "index_users_on_practice_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "whatsapp_accounts", force: :cascade do |t|
    t.text "access_token_ciphertext"
    t.boolean "active", default: true, null: false
    t.text "app_secret_ciphertext"
    t.string "business_account_name"
    t.datetime "created_at", null: false
    t.string "display_phone_number", null: false
    t.string "phone_number_id", null: false
    t.bigint "practice_id", null: false
    t.datetime "updated_at", null: false
    t.string "waba_id", null: false
    t.string "webhook_verify_token"
    t.index ["practice_id", "phone_number_id"], name: "index_whatsapp_accounts_on_practice_id_and_phone_number_id", unique: true
    t.index ["practice_id"], name: "index_whatsapp_accounts_on_practice_id"
    t.index ["webhook_verify_token"], name: "index_whatsapp_accounts_on_webhook_verify_token_unique", unique: true, where: "(webhook_verify_token IS NOT NULL)"
  end

  add_foreign_key "exported_documents", "intake_sessions"
  add_foreign_key "intake_attachments", "intake_messages"
  add_foreign_key "intake_attachments", "intake_sessions"
  add_foreign_key "intake_events", "intake_sessions"
  add_foreign_key "intake_field_groups", "intake_flows"
  add_foreign_key "intake_field_values", "intake_attachments", column: "source_attachment_id"
  add_foreign_key "intake_field_values", "intake_field_values", column: "superseded_by_id"
  add_foreign_key "intake_field_values", "intake_fields"
  add_foreign_key "intake_field_values", "intake_messages", column: "source_message_id"
  add_foreign_key "intake_field_values", "intake_sessions"
  add_foreign_key "intake_field_values", "users", column: "verified_by_user_id"
  add_foreign_key "intake_fields", "intake_field_groups"
  add_foreign_key "intake_fields", "intake_flows"
  add_foreign_key "intake_flows", "practices"
  add_foreign_key "intake_flows", "users", column: "created_by_id"
  add_foreign_key "intake_messages", "intake_sessions"
  add_foreign_key "intake_sessions", "intake_flows"
  add_foreign_key "intake_sessions", "practices"
  add_foreign_key "intake_sessions", "users", column: "initiated_by_user_id"
  add_foreign_key "intake_sessions", "whatsapp_accounts"
  add_foreign_key "session_reviews", "intake_sessions"
  add_foreign_key "session_reviews", "users", column: "reviewer_id"
  add_foreign_key "users", "practices"
  add_foreign_key "whatsapp_accounts", "practices"
end
