require "test_helper"
require "securerandom"

class Whatsapp::SendTemplateMessageTest < ActiveSupport::TestCase
  test "sends template payload with env template id and body parameters" do
    context = build_session_context
    session = context.fetch(:intake_session)

    ENV["WHATSAPP_FOLLOW_UP_TEMPLATE_ID"] = "medicomm_follow_up_v20260422_01"
    ENV["WHATSAPP_FOLLOW_UP_TEMPLATE_LANGUAGE"] = "en"

    captured_request = nil
    captured_http_options = {}
    stubbed_start = lambda do |_host, _port, use_ssl:, open_timeout:, read_timeout:, &block|
      captured_http_options = {
        use_ssl: use_ssl,
        open_timeout: open_timeout,
        read_timeout: read_timeout
      }

      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |request|
        captured_request = request
        FakeSuccessResponse.new(
          body: { messages: [ { id: "wamid.template.outbound.1" } ] }.to_json,
          code: "200"
        )
      end

      block.call(fake_http)
    end

    result = nil
    with_class_method_stub(Net::HTTP, :start, stubbed_start) do
      result = Whatsapp::SendTemplateMessage.call(
        intake_session_id: session.id,
        body_parameters: [ "Karel Nel" ]
      )
    end

    assert_equal :sent, result[:status]
    assert_equal "wamid.template.outbound.1", result[:provider_message_id]
    assert_equal "medicomm_follow_up_v20260422_01", result[:template_name]
    assert_equal "en", result[:language_code]
    assert_equal true, captured_http_options[:use_ssl]
    assert_equal 10, captured_http_options[:open_timeout]
    assert_equal 10, captured_http_options[:read_timeout]

    payload = JSON.parse(captured_request.body)
    assert_equal "template", payload["type"]
    assert_equal "medicomm_follow_up_v20260422_01", payload.dig("template", "name")
    assert_equal "en", payload.dig("template", "language", "code")
    assert_equal "Karel Nel", payload.dig("template", "components", 0, "parameters", 0, "text")
    assert_equal 1, Array(payload.dig("template", "components", 0, "parameters")).size
  end

  test "returns skipped when no template id is configured" do
    context = build_session_context
    session = context.fetch(:intake_session)

    ENV.delete("WHATSAPP_FOLLOW_UP_TEMPLATE_ID")

    result = Whatsapp::SendTemplateMessage.call(
      intake_session_id: session.id,
      body_parameters: [ "Karel Nel" ]
    )

    assert_equal :skipped, result[:status]
    assert_equal "missing_template_name", result[:reason]
  end

  private

  class FakeSuccessResponse
    attr_reader :body, :code

    def initialize(body:, code:)
      @body = body
      @code = code
    end

    def is_a?(klass)
      return true if klass == Net::HTTPSuccess

      super
    end
  end

  def with_class_method_stub(klass, method_name, callable)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name, callable)
    yield
  ensure
    klass.define_singleton_method(method_name, original)
  end

  def build_session_context
    practice = practices(:one)
    user = users(:one)
    suffix = SecureRandom.hex(6)

    account = WhatsappAccount.create!(
      practice: practice,
      phone_number_id: "phone-#{suffix}",
      waba_id: "waba-#{suffix}",
      display_phone_number: "+27 69 123 0000",
      webhook_verify_token: "verify-#{suffix}",
      app_secret_ciphertext: "app-secret-#{suffix}",
      access_token_ciphertext: "access-token-#{suffix}",
      active: true
    )

    flow = IntakeFlow.create!(
      practice: practice,
      created_by: user,
      name: "Template Send #{suffix}",
      flow_type: "new_patient",
      status: :published,
      default_language: "en-ZA",
      tone_preset: "professional",
      completion_email_enabled: false,
      completion_email_recipients_json: []
    )

    intake_session = IntakeSession.create!(
      practice: practice,
      intake_flow: flow,
      whatsapp_account: account,
      initiated_by_user: user,
      patient_phone_e164: "+2782#{rand(10_000_000).to_s.rjust(7, '0')}",
      patient_display_name: "Karel Nel",
      status: :awaiting_staff_review,
      language: "en-ZA",
      started_at: Time.current
    )

    {
      practice: practice,
      user: user,
      account: account,
      flow: flow,
      intake_session: intake_session
    }
  end
end
