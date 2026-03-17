class Webhooks::WhatsappController < ActionController::API
  # GET /webhooks/whatsapp
  # Meta verification handshake:
  # - webhook_verify_token on WhatsappAccount must match hub.verify_token
  # - response body must be hub.challenge with 200 status
  def show
    challenge = params["hub.challenge"].presence
    mode = params["hub.mode"].presence
    provided_verify_token = params["hub.verify_token"].presence

    if mode == "subscribe" && challenge.present? && verified_account(provided_verify_token).present?
      render plain: challenge, status: :ok
    else
      render plain: "verification failed", status: :forbidden
    end
  end

  # POST /webhooks/whatsapp
  # Receives webhook payload and enqueues async processing.
  def create
    raw_payload = request.raw_post
    signature = request.headers["X-Hub-Signature-256"]
    account = verified_signature_account(signature: signature, raw_payload: raw_payload)

    return render json: { error: "invalid signature" }, status: :unauthorized unless account

    parsed_event = Whatsapp::WebhookParser.new(payload: raw_payload).call
    parsed_event[:whatsapp_account_id] = account.id
    ProcessIncomingWhatsappWebhookJob.perform_async(parsed_event)

    head :accepted
  rescue Whatsapp::WebhookParser::ParseError => e
    Rails.logger.warn("[Webhooks::WhatsappController] payload parse failed: #{e.message}")
    render json: { error: "invalid payload" }, status: :bad_request
  end

  private

  def verified_account(provided_verify_token)
    return if provided_verify_token.blank?

    WhatsappAccount.find_by(webhook_verify_token: provided_verify_token)
  end

  def verified_signature_account(signature:, raw_payload:)
    signature_candidate_accounts(raw_payload).find do |account|
      Whatsapp::SignatureVerifier.call(
        signature: signature,
        raw_body: raw_payload,
        app_secret: account.app_secret_ciphertext
      )
    end
  end

  def signature_candidate_accounts(raw_payload)
    phone_number_ids = extract_phone_number_ids(raw_payload)
    return WhatsappAccount.none if phone_number_ids.empty?

    WhatsappAccount.where(phone_number_id: phone_number_ids).where.not(app_secret_ciphertext: [ nil, "" ])
  end

  def extract_phone_number_ids(raw_payload)
    payload = JSON.parse(raw_payload)
    entries = Array(payload["entry"])

    entries.flat_map do |entry|
      changes = Array(entry["changes"])
      changes.filter_map do |change|
        change.dig("value", "metadata", "phone_number_id").presence
      end
    end.uniq
  rescue JSON::ParserError
    []
  end
end
