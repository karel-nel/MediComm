require "set"

module Fields
  class ApplyCandidates
    AUTO_COMPLETE_CONFIDENCE = 0.92
    STRICT_IDENTIFIER_AUTO_COMPLETE_CONFIDENCE = 0.90
    CLARIFICATION_CONFIDENCE = 0.75

    BOOLEAN_TRUE_VALUES = %w[true t yes y 1].freeze
    BOOLEAN_FALSE_VALUES = %w[false f no n 0].freeze

    def self.call(intake_session:, candidate_fields:, source_message: nil, applied_by: nil)
      new(
        intake_session: intake_session,
        candidate_fields: candidate_fields,
        source_message: source_message,
        applied_by: applied_by
      ).call
    end

    def initialize(intake_session:, candidate_fields:, source_message: nil, applied_by: nil)
      @intake_session = intake_session
      @candidate_fields = Array(candidate_fields)
      @source_message = source_message
      @applied_by = applied_by
    end

    def call
      flow_fields_by_key = @intake_session.intake_flow.intake_fields.active.index_by(&:key)
      asked_field_keys = currently_asked_field_keys
      rejected_keys = []
      applied_values = []

      IntakeFieldValue.transaction do
        @candidate_fields.each do |candidate|
          candidate_hash = candidate.respond_to?(:to_h) ? candidate.to_h : {}
          field_key = (candidate_hash[:key] || candidate_hash["key"]).to_s
          field = flow_fields_by_key[field_key]

          unless field
            rejected_keys << field_key
            next
          end

          raw_value = (candidate_hash[:value] || candidate_hash["value"]).to_s
          next if raw_value.strip.blank?

          validation_result = validate_and_normalize_value(field: field, raw_value: raw_value)
          normalized_value = validation_result[:value]
          confidence = normalize_confidence(candidate_hash[:confidence] || candidate_hash["confidence"])
          latest_value = latest_active_value(field)
          status = status_for_candidate(
            field: field,
            confidence: confidence,
            validation_errors: validation_result[:errors],
            latest_value: latest_value,
            normalized_value: normalized_value,
            asked_field_keys: asked_field_keys
          )

          if same_value?(latest_value, normalized_value) &&
              (latest_value&.status_complete? || latest_value&.status_inferred?)
            applied_values << latest_value
            next
          end

          if latest_value&.canonical_value_text.to_s.strip == normalized_value &&
              latest_value&.status.to_s == status.to_s
            applied_values << latest_value
            next
          end

          new_value = @intake_session.intake_field_values.create!(
            intake_field: field,
            source_message: @source_message,
            canonical_value_text: normalized_value,
            status: status,
            confidence: confidence
          )

          latest_value&.update!(superseded_by: new_value)

          @intake_session.intake_events.create!(
            event_type: status == :rejected ? "field_candidate_rejected" : "field_candidate_applied",
            payload_json: {
              intake_field_id: field.id,
              intake_field_key: field.key,
              intake_field_value_id: new_value.id,
              source_message_id: @source_message&.provider_message_id,
              confidence: confidence,
              source: (candidate_hash[:source] || candidate_hash["source"]).presence || "n8n",
              applied_by: @applied_by,
              validation_errors: validation_result[:errors]
            }
          )

          rejected_keys << field.key if status == :rejected
          applied_values << new_value
        end
      end

      {
        status: :ok,
        intake_session_id: @intake_session.id,
        applied_count: applied_values.size,
        rejected_keys: rejected_keys.uniq
      }
    end

    private

    def latest_active_value(field)
      @intake_session.intake_field_values
        .where(intake_field: field, superseded_by_id: nil)
        .order(created_at: :desc)
        .first
    end

    def normalize_confidence(raw_confidence)
      value = raw_confidence.to_f
      return 1.0 if value > 1.0
      return 0.0 if value < 0.0

      value
    end

    def status_for_candidate(field:, confidence:, validation_errors:, latest_value:, normalized_value:, asked_field_keys:)
      return :rejected if validation_errors.any?

      complete_threshold = strict_identifier_field?(field) ? STRICT_IDENTIFIER_AUTO_COMPLETE_CONFIDENCE : AUTO_COMPLETE_CONFIDENCE
      return :complete if confidence >= complete_threshold
      return :complete if asked_field_confirmation_promotes_to_complete?(
        field: field,
        confidence: confidence,
        asked_field_keys: asked_field_keys
      )
      return :complete if confirmation_promotes_to_complete?(
        field: field,
        latest_value: latest_value,
        normalized_value: normalized_value,
        confidence: confidence
      )
      return :candidate if confidence >= CLARIFICATION_CONFIDENCE

      :needs_clarification
    end

    def strict_identifier_field?(field)
      key = field.key.to_s
      key.match?(/(^|_)id($|_)/) || key.end_with?("_id_number") || validation_type_for(field) == "za_id_number"
    end

    def confirmation_promotes_to_complete?(field:, latest_value:, normalized_value:, confidence:)
      return false if strict_identifier_field?(field)
      return false if confidence < CLARIFICATION_CONFIDENCE
      return false if latest_value.blank?
      return false unless latest_value.status_candidate? || latest_value.status_needs_clarification?
      return false unless same_value?(latest_value, normalized_value)

      true
    end

    def asked_field_confirmation_promotes_to_complete?(field:, confidence:, asked_field_keys:)
      return false if strict_identifier_field?(field)
      return false unless asked_field_keys.include?(field.key)
      return false if confidence < CLARIFICATION_CONFIDENCE

      true
    end

    def currently_asked_field_keys
      recommendation = Conversation::SelectNextAsk.call(intake_session: @intake_session)
      Array(recommendation&.dig(:field_keys)).map(&:to_s).to_set
    end

    def same_value?(latest_value, normalized_value)
      latest_value&.canonical_value_text.to_s.strip.casecmp?(normalized_value.to_s.strip)
    end

    def validate_and_normalize_value(field:, raw_value:)
      value = raw_value.to_s.strip
      rules = normalized_rules(field.validation_rules_json)
      errors = []

      value = value.gsub(/\D/, "") if truthy?(rules["strip_non_digits_before_validation"])
      value = value.gsub(/\D/, "") if truthy?(rules["digits_only"])
      value = normalize_by_type(field: field, value: value, rules: rules, errors: errors)
      apply_generic_validations(value: value, rules: rules, errors: errors)

      {
        value: value.to_s.strip,
        errors: errors.uniq
      }
    end

    def normalize_by_type(field:, value:, rules:, errors:)
      type = validation_type_for(field, rules)

      case type
      when "email"
        normalized = value.to_s.downcase.strip
        errors << "invalid_email" unless normalized.match?(URI::MailTo::EMAIL_REGEXP)
        normalized
      when "phone", "phone_e164_or_local_za"
        normalized = normalize_phone(value)
        errors << "invalid_phone" if normalized.blank?
        normalized || value
      when "number"
        normalize_number(value, errors)
      when "boolean"
        normalize_boolean(value, errors)
      when "date"
        normalize_date(value, errors)
      when "za_id_number"
        normalize_za_id(value, rules, errors)
      else
        value
      end
    end

    def apply_generic_validations(value:, rules:, errors:)
      text = value.to_s
      stripped = text.strip

      if rules.key?("required") && truthy?(rules["required"]) && stripped.blank?
        errors << "required"
      end
      if rules.key?("min_length") && stripped.length < rules["min_length"].to_i
        errors << "min_length"
      end
      if rules.key?("max_length") && stripped.length > rules["max_length"].to_i
        errors << "max_length"
      end
      if rules.key?("exact_length") && stripped.length != rules["exact_length"].to_i
        errors << "exact_length"
      end
      if truthy?(rules["disallow_numbers"]) && stripped.match?(/\d/)
        errors << "disallow_numbers"
      end
      if rules.key?("min_words") && word_count(stripped) < rules["min_words"].to_i
        errors << "min_words"
      end
      if rules.key?("max_words") && word_count(stripped) > rules["max_words"].to_i
        errors << "max_words"
      end
      if rules.key?("pattern")
        begin
          regex = Regexp.new(rules["pattern"].to_s)
          errors << "pattern" unless stripped.match?(regex)
        rescue RegexpError
          errors << "pattern"
        end
      end

      allowed_values = Array(rules["allowed_values"]).map { |item| item.to_s.strip.downcase }
      if allowed_values.any? && !allowed_values.include?(stripped.downcase)
        errors << "allowed_values"
      end

      if rules.key?("digits_only") && truthy?(rules["digits_only"]) && !stripped.match?(/\A\d+\z/)
        errors << "digits_only"
      end

      if rules.key?("min") || rules.key?("max")
        numeric = Float(stripped)
        errors << "min" if rules.key?("min") && numeric < rules["min"].to_f
        errors << "max" if rules.key?("max") && numeric > rules["max"].to_f
      end
    rescue ArgumentError, TypeError
      errors << "number"
    end

    def validation_type_for(field, rules = normalized_rules(field.validation_rules_json))
      explicit_type = rules["type"].to_s
      return explicit_type if explicit_type.present?

      field.field_type.to_s
    end

    def normalized_rules(raw_rules)
      (raw_rules || {}).to_h.stringify_keys
    end

    def normalize_phone(value)
      raw = value.to_s.strip
      return nil if raw.blank?

      if raw.start_with?("+")
        normalized = "+#{raw.gsub(/[^\d]/, "")}"
      else
        digits = raw.gsub(/[^\d]/, "")
        return nil if digits.blank?

        if digits.start_with?("00")
          normalized = "+#{digits[2..]}"
        elsif digits.start_with?("0") && digits.length == 10
          normalized = "+27#{digits[1..]}"
        elsif digits.start_with?("27") && digits.length == 11
          normalized = "+#{digits}"
        else
          normalized = "+#{digits}"
        end
      end

      normalized.match?(/\A\+\d{10,15}\z/) ? normalized : nil
    end

    def normalize_number(value, errors)
      numeric = Float(value.to_s.strip)
      return numeric.to_i.to_s if numeric.integer?

      numeric.to_s
    rescue ArgumentError
      errors << "number"
      value.to_s.strip
    end

    def normalize_boolean(value, errors)
      normalized = value.to_s.strip.downcase
      return "true" if BOOLEAN_TRUE_VALUES.include?(normalized)
      return "false" if BOOLEAN_FALSE_VALUES.include?(normalized)

      errors << "boolean"
      value.to_s.strip
    end

    def normalize_date(value, errors)
      Date.parse(value.to_s.strip).iso8601
    rescue Date::Error
      errors << "date"
      value.to_s.strip
    end

    def normalize_za_id(value, rules, errors)
      candidate = value.to_s.strip
      candidate = candidate.gsub(/\D/, "") if truthy?(rules["strip_non_digits_before_validation"]) || truthy?(rules["digits_only"])
      expected_length = rules["exact_length"].presence&.to_i || 13

      errors << "exact_length" unless candidate.length == expected_length
      errors << "digits_only" unless candidate.match?(/\A\d+\z/)
      errors << "za_id_checksum" unless valid_za_id_checksum?(candidate)
      candidate
    end

    def valid_za_id_checksum?(candidate)
      return false unless candidate.match?(/\A\d{13}\z/)

      digits = candidate.chars.map(&:to_i)
      odd_sum = digits[0] + digits[2] + digits[4] + digits[6] + digits[8] + digits[10]
      even_number = (digits[1].to_s + digits[3].to_s + digits[5].to_s + digits[7].to_s + digits[9].to_s + digits[11].to_s).to_i
      even_sum = (even_number * 2).digits.sum
      total = odd_sum + even_sum
      checksum = (10 - (total % 10)) % 10

      checksum == digits[12]
    end

    def word_count(text)
      text.split(/\s+/).reject(&:blank?).size
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
