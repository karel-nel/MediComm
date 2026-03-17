class Webhooks::WhatsappController < ActionController::API
  # GET /webhooks/whatsapp
  # Meta verification handshake:
  # - WHATSAPP_VERIFY_TOKEN must match hub.verify_token
  # - response body must be hub.challenge with 200 status
  def show
    challenge = params["hub.challenge"].presence
    mode = params["hub.mode"].presence
    provided_verify_token = params["hub.verify_token"].presence

    if mode == "subscribe" && challenge.present? && valid_verify_token?(provided_verify_token)
      render plain: challenge, status: :ok
    else
      render plain: "verification failed", status: :forbidden
    end
  end

  # POST /webhooks/whatsapp
  # Receives webhook payload and enqueues async processing.
  def create
    raw_payload = request.raw_post
    verifier = Whatsapp::SignatureVerifier.new(
      signature: request.headers["X-Hub-Signature-256"],
      raw_body: raw_payload,
      app_secret: ENV["WHATSAPP_APP_SECRET"]
    )

    return render json: { error: "invalid signature" }, status: :unauthorized unless verifier.call

    parsed_event = Whatsapp::WebhookParser.new(payload: raw_payload).call
    ProcessIncomingWhatsappWebhookJob.perform_later(parsed_event: parsed_event)

    head :accepted
  rescue Whatsapp::WebhookParser::ParseError => e
    Rails.logger.warn("[Webhooks::WhatsappController] payload parse failed: #{e.message}")
    render json: { error: "invalid payload" }, status: :bad_request
  end

  private

  def valid_verify_token?(provided_verify_token)
    configured_verify_token = ENV["WHATSAPP_VERIFY_TOKEN"].to_s
    return false if configured_verify_token.blank? || provided_verify_token.blank?

    ActiveSupport::SecurityUtils.secure_compare(provided_verify_token, configured_verify_token)
  end
end
