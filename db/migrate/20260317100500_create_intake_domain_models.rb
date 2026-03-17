class CreateIntakeDomainModels < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_accounts do |t|
      t.references :practice, null: false, foreign_key: true
      t.string :phone_number_id, null: false
      t.string :waba_id, null: false
      t.string :display_phone_number, null: false
      t.text :access_token_ciphertext
      t.string :business_account_name
      t.boolean :active, null: false, default: true

      t.timestamps null: false
    end
    add_index :whatsapp_accounts, [ :practice_id, :phone_number_id ], unique: true

    create_table :intake_flows do |t|
      t.references :practice, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :flow_type, null: false
      t.integer :status, null: false, default: 0
      t.text :description
      t.string :default_language, null: false, default: "en-ZA"
      t.string :tone_preset, null: false, default: "professional"
      t.boolean :allow_skip_by_default, null: false, default: false
      t.boolean :completion_email_enabled, null: false, default: false
      t.jsonb :completion_email_recipients_json, null: false, default: []
      t.datetime :published_at

      t.timestamps null: false
    end
    add_index :intake_flows, [ :practice_id, :status ]
    add_index :intake_flows, [ :practice_id, :name ]

    create_table :intake_field_groups do |t|
      t.references :intake_flow, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.integer :position, null: false, default: 0
      t.boolean :repeatable, null: false, default: false
      t.jsonb :visibility_rules_json, null: false, default: {}

      t.timestamps null: false
    end
    add_index :intake_field_groups, [ :intake_flow_id, :key ], unique: true
    add_index :intake_field_groups, [ :intake_flow_id, :position ]

    create_table :intake_fields do |t|
      t.references :intake_flow, null: false, foreign_key: true
      t.references :intake_field_group, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.string :field_type, null: false
      t.boolean :required, null: false, default: true
      t.integer :ask_priority, null: false, default: 0
      t.boolean :extraction_enabled, null: false, default: true
      t.string :source_preference, null: false, default: "any"
      t.jsonb :validation_rules_json, null: false, default: {}
      t.jsonb :branching_rules_json, null: false, default: {}
      t.jsonb :skip_rules_json, null: false, default: {}
      t.text :ai_prompt_hint
      t.jsonb :example_values_json, null: false, default: []
      t.string :autofill_pdf_key
      t.boolean :active, null: false, default: true

      t.timestamps null: false
    end
    add_index :intake_fields, [ :intake_flow_id, :key ], unique: true
    add_index :intake_fields, [ :intake_flow_id, :ask_priority ]
    add_index :intake_fields, [ :intake_flow_id, :active ]

    create_table :intake_sessions do |t|
      t.references :practice, null: false, foreign_key: true
      t.references :intake_flow, null: false, foreign_key: true
      t.references :whatsapp_account, null: false, foreign_key: true
      t.references :initiated_by_user, null: false, foreign_key: { to_table: :users }
      t.string :patient_phone_e164, null: false
      t.string :patient_display_name, null: false
      t.string :external_reference
      t.integer :status, null: false, default: 0
      t.string :language, null: false, default: "en-ZA"
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps null: false
    end
    add_index :intake_sessions, [ :practice_id, :status ]
    add_index :intake_sessions, [ :practice_id, :updated_at ]
    add_index :intake_sessions, :patient_phone_e164
    add_index :intake_sessions, :external_reference

    create_table :intake_messages do |t|
      t.references :intake_session, null: false, foreign_key: true
      t.integer :direction, null: false, default: 0
      t.string :provider_message_id
      t.string :message_type, null: false, default: "text"
      t.text :text_body

      t.timestamps null: false
    end
    add_index :intake_messages, [ :intake_session_id, :created_at ]
    add_index :intake_messages, :provider_message_id, unique: true, where: "provider_message_id IS NOT NULL"

    create_table :intake_attachments do |t|
      t.references :intake_session, null: false, foreign_key: true
      t.references :intake_message, foreign_key: true
      t.string :mime_type, null: false
      t.string :s3_key
      t.string :file_name, null: false
      t.bigint :byte_size
      t.string :processing_status, null: false, default: "processed"

      t.timestamps null: false
    end
    add_index :intake_attachments, [ :intake_session_id, :created_at ]

    create_table :intake_field_values do |t|
      t.references :intake_session, null: false, foreign_key: true
      t.references :intake_field, null: false, foreign_key: true
      t.references :source_message, foreign_key: { to_table: :intake_messages }
      t.references :source_attachment, foreign_key: { to_table: :intake_attachments }
      t.references :verified_by_user, foreign_key: { to_table: :users }
      t.references :superseded_by, foreign_key: { to_table: :intake_field_values }
      t.text :canonical_value_text
      t.integer :status, null: false, default: 0
      t.decimal :confidence, precision: 5, scale: 2, null: false, default: 0.0

      t.timestamps null: false
    end
    add_index :intake_field_values, [ :intake_session_id, :intake_field_id ]
    add_index :intake_field_values, [ :intake_session_id, :status ]

    create_table :intake_events do |t|
      t.references :intake_session, null: false, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :payload_json, null: false, default: {}

      t.timestamps null: false
    end
    add_index :intake_events, [ :intake_session_id, :created_at ]
    add_index :intake_events, :event_type

    create_table :session_reviews do |t|
      t.references :intake_session, null: false, foreign_key: true, index: { unique: true }
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.text :notes
      t.datetime :reviewed_at

      t.timestamps null: false
    end
    add_index :session_reviews, :status

    create_table :exported_documents do |t|
      t.references :intake_session, null: false, foreign_key: true
      t.string :document_type, null: false, default: "completion_summary"
      t.string :storage_key
      t.string :status, null: false, default: "pending"
      t.datetime :generated_at

      t.timestamps null: false
    end
    add_index :exported_documents, :status
  end
end
