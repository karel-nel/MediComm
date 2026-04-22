require "base64"

module Conversation
  class BuildN8nRequest
    TRANSCRIPT_LIMIT = 20
    ATTACHMENT_LIMIT = 10
    ATTACHMENT_BASE64_MAX_BYTES = 3 * 1024 * 1024

    def self.call(intake_session:, source_message:)
      new(intake_session: intake_session, source_message: source_message).call
    end

    def initialize(intake_session:, source_message:)
      @intake_session = intake_session
      @source_message = source_message
    end

    def call
      {
        session_id: intake_session.id,
        intake_session_id: intake_session.id,
        practice_id: intake_session.practice_id,
        source_message_id: source_message.provider_message_id,
        meta: {
          event: "inbound_message_received",
          generated_at: Time.current.iso8601,
          schema_version: "2026-03-25.n8n_context.v1"
        },
        practice: practice_payload,
        flow: flow_payload,
        whatsapp_account: whatsapp_account_payload,
        session: session_payload,
        source_message: source_message_payload,
        state: state_payload,
        field_groups: field_groups_payload,
        fields: fields_payload,
        current_field_values: current_field_values_payload,
        recent_transcript: recent_transcript_payload,
        recent_attachments: recent_attachments_payload,
        callbacks: callback_payload,
        instructions: {
          deterministic_rules_owned_by_rails: true,
          do_not_ask_completed_fields: true,
          ask_linked_fields_as_batch_when_available: true,
          prefer_clustered_questions: true,
          use_next_question_batch_as_source_of_truth: true,
          do_not_change_business_rules: true,
          reply_naturally: true
        }
      }
    end

    private

    attr_reader :intake_session, :source_message

    def flow
      @flow ||= intake_session.intake_flow
    end

    def practice
      @practice ||= intake_session.practice
    end

    def whatsapp_account
      @whatsapp_account ||= intake_session.whatsapp_account
    end

    def active_fields
      @active_fields ||= flow.intake_fields.active.includes(:intake_field_group).order(:ask_priority)
    end

    def active_groups
      @active_groups ||= flow.intake_field_groups.active.order(:position)
    end

    def outstanding_state
      @outstanding_state ||= Fields::ComputeOutstanding.call(intake_session: intake_session)
    end

    def latest_unsuperseded_values
      @latest_unsuperseded_values ||= intake_session
        .intake_field_values
        .where(superseded_by_id: nil)
        .includes(:intake_field, :source_message, :source_attachment)
        .index_by(&:intake_field_id)
    end

    def practice_payload
      {
        id: practice.id,
        name: practice.name,
        slug: practice.slug,
        timezone: practice.timezone,
        contact_email: practice.contact_email,
        status: practice.status
      }
    end

    def flow_payload
      {
        id: flow.id,
        name: flow.name,
        flow_type: flow.flow_type,
        status: flow.status,
        description: flow.description,
        default_language: flow.default_language,
        tone_preset: flow.tone_preset,
        allow_skip_by_default: flow.allow_skip_by_default,
        completion_email_enabled: flow.completion_email_enabled,
        completion_email_recipients: Array(flow.completion_email_recipients_json),
        published_at: flow.published_at&.iso8601
      }
    end

    def whatsapp_account_payload
      {
        id: whatsapp_account.id,
        phone_number_id: whatsapp_account.phone_number_id,
        waba_id: whatsapp_account.waba_id,
        display_phone_number: whatsapp_account.display_phone_number,
        business_account_name: whatsapp_account.business_account_name,
        active: whatsapp_account.active
      }
    end

    def session_payload
      {
        id: intake_session.id,
        practice_id: intake_session.practice_id,
        intake_flow_id: intake_session.intake_flow_id,
        whatsapp_account_id: intake_session.whatsapp_account_id,
        initiated_by_user_id: intake_session.initiated_by_user_id,
        status: intake_session.status,
        language: intake_session.language,
        patient_phone_e164: intake_session.patient_phone_e164,
        patient_display_name: intake_session.patient_display_name,
        external_reference: intake_session.external_reference,
        started_at: intake_session.started_at&.iso8601,
        completed_at: intake_session.completed_at&.iso8601
      }
    end

    def source_message_payload
      {
        id: source_message.id,
        provider_message_id: source_message.provider_message_id,
        direction: source_message.direction,
        message_type: source_message.message_type,
        text: source_message.text_body.to_s,
        received_at: source_message.created_at&.iso8601
      }
    end

    def state_payload
      {
        completed_fields: outstanding_state[:completed_fields],
        missing_fields: outstanding_state[:missing_fields],
        needs_clarification: outstanding_state[:clarification_fields],
        cluster_warnings: outstanding_state[:cluster_warnings],
        allowed_next_asks: outstanding_state[:allowed_next_asks],
        next_ask_batches: outstanding_state[:next_ask_batches],
        question_clusters: outstanding_state[:question_clusters],
        recommended_next_ask: next_ask_recommendation,
        next_question_batch: next_question_batch_payload
      }
    end

    def next_ask_recommendation
      @next_ask_recommendation ||= Conversation::SelectNextAsk.call(intake_session: intake_session)
    end

    def next_question_batch_payload
      recommendation = next_ask_recommendation
      return nil if recommendation.blank?

      generated_reply = Conversation::GenerateReply.call(intake_session_id: intake_session.id)

      {
        mode: recommendation[:mode],
        cluster_key: recommendation[:cluster_key],
        field_keys: Array(recommendation[:field_keys]),
        fields: Array(recommendation[:fields]),
        suggested_reply_text: generated_reply[:reply_text]
      }
    end

    def field_groups_payload
      active_groups.map do |group|
        {
          id: group.id,
          key: group.key,
          label: group.label,
          position: group.position,
          repeatable: group.repeatable,
          visibility_rules_json: group.visibility_rules_json || {}
        }
      end
    end

    def fields_payload
      active_fields.map do |field|
        {
          id: field.id,
          key: field.key,
          label: field.label,
          group_key: field.intake_field_group&.key,
          group_label: field.intake_field_group&.label,
          field_type: field.field_type,
          required: field.required,
          ask_priority: field.ask_priority,
          extraction_enabled: field.extraction_enabled,
          source_preference: field.source_preference,
          ai_prompt_hint: field.ai_prompt_hint,
          validation_rules_json: field.validation_rules_json || {},
          branching_rules_json: field.branching_rules_json || {},
          skip_rules_json: field.skip_rules_json || {},
          example_values_json: field.example_values_json || [],
          autofill_pdf_key: field.autofill_pdf_key
        }
      end
    end

    def current_field_values_payload
      active_fields.filter_map do |field|
        value = latest_unsuperseded_values[field.id]
        next if value.blank?

        {
          field_key: field.key,
          value: value.canonical_value_text,
          status: value.status,
          confidence: value.confidence,
          source_message_id: value.source_message&.provider_message_id,
          source_attachment_id: value.source_attachment_id,
          captured_at: value.created_at&.iso8601
        }
      end
    end

    def recent_transcript_payload
      intake_session.intake_messages
        .reorder(created_at: :desc)
        .limit(TRANSCRIPT_LIMIT)
        .reverse
        .map do |message|
          {
            id: message.id,
            provider_message_id: message.provider_message_id,
            direction: message.direction,
            type: message.message_type,
            text: message.text_body.to_s,
            created_at: message.created_at&.iso8601
          }
        end
    end

    def recent_attachments_payload
      intake_session.intake_attachments
        .reorder(created_at: :desc)
        .limit(ATTACHMENT_LIMIT)
        .reverse
        .map do |attachment|
          base64_content = encoded_attachment_content(attachment)

          {
            id: attachment.id,
            intake_message_id: attachment.intake_message_id,
            mime_type: attachment.mime_type,
            file_name: attachment.file_name,
            byte_size: attachment.byte_size,
            s3_key: attachment.s3_key,
            processing_status: attachment.processing_status,
            content_encoding: base64_content[:encoding],
            content_base64: base64_content[:content_base64],
            content_status: base64_content[:status],
            content_error: base64_content[:error],
            created_at: attachment.created_at&.iso8601
          }
        end
    end

    def callback_payload
      {
        conversation_state_path: "/api/v1/intake_sessions/#{intake_session.id}/conversation_state",
        conversation_response_path: "/api/v1/intake_sessions/#{intake_session.id}/conversation_response"
      }
    end

    def encoded_attachment_content(attachment)
      return content_error_payload("missing_storage_key") if attachment.s3_key.blank?

      file_path = resolve_attachment_file_path(attachment.s3_key)
      return content_error_payload("missing_local_file") unless file_path.present? && File.exist?(file_path)

      bytes = File.binread(file_path)
      max_bytes = max_attachment_base64_bytes
      return content_error_payload("attachment_too_large") if bytes.bytesize > max_bytes

      {
        encoding: "base64",
        content_base64: Base64.strict_encode64(bytes),
        status: "included",
        error: nil
      }
    rescue StandardError => e
      content_error_payload("read_failed: #{e.class}")
    end

    def resolve_attachment_file_path(storage_key)
      return nil if storage_key.blank?
      return storage_key if storage_key.start_with?("/")

      Rails.root.join(storage_key).to_s
    end

    def max_attachment_base64_bytes
      configured = ENV["N8N_ATTACHMENT_BASE64_MAX_BYTES"].to_i
      configured.positive? ? configured : ATTACHMENT_BASE64_MAX_BYTES
    end

    def content_error_payload(error)
      {
        encoding: nil,
        content_base64: nil,
        status: "omitted",
        error: error
      }
    end
  end
end
