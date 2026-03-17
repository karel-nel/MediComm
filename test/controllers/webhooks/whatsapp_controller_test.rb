require "test_helper"
require "sidekiq/testing"

class Webhooks::WhatsappControllerTest < ActionDispatch::IntegrationTest
  setup do
    Sidekiq::Testing.fake!
    ProcessIncomingWhatsappWebhookJob.clear

    @account = WhatsappAccount.create!(
      practice: practices(:one),
      phone_number_id: "155512340001",
      waba_id: "waba-test-001",
      display_phone_number: "+27 71 111 0001",
      business_account_name: "Test Account One",
      webhook_verify_token: "verify-token-123",
      app_secret_ciphertext: "app-secret-123",
      access_token_ciphertext: "access-token-123",
      active: true
    )

    @other_account = WhatsappAccount.create!(
      practice: practices(:two),
      phone_number_id: "155512340002",
      waba_id: "waba-test-002",
      display_phone_number: "+27 71 111 0002",
      business_account_name: "Test Account Two",
      webhook_verify_token: "verify-token-456",
      app_secret_ciphertext: "app-secret-456",
      access_token_ciphertext: "access-token-456",
      active: true
    )
  end

  teardown do
    ProcessIncomingWhatsappWebhookJob.clear
  end

  test "verifies webhook endpoint with challenge on valid token" do
    get webhooks_whatsapp_url, params: {
      "hub.mode" => "subscribe",
      "hub.challenge" => "1158201444",
      "hub.verify_token" => "verify-token-123"
    }

    assert_response :ok
    assert_equal "1158201444", response.body
  end

  test "rejects webhook verification when token is invalid" do
    get webhooks_whatsapp_url, params: {
      "hub.mode" => "subscribe",
      "hub.challenge" => "1158201444",
      "hub.verify_token" => "wrong-token"
    }

    assert_response :forbidden
  end

  test "accepts signed incoming payload and enqueues processor job" do
    payload = {
      object: "whatsapp_business_account",
      entry: [ {
        id: "entry_1",
        changes: [ {
          field: "messages",
          value: {
            metadata: {
              phone_number_id: @account.phone_number_id
            }
          }
        } ]
      } ]
    }.to_json

    signature = signed_meta_signature(payload, @account.app_secret_ciphertext)

    assert_difference -> { ProcessIncomingWhatsappWebhookJob.jobs.size }, 1 do
      post webhooks_whatsapp_url,
           params: payload,
           headers: {
             "CONTENT_TYPE" => "application/json",
             "X-Hub-Signature-256" => signature
           }
    end

    assert_response :accepted
  end

  test "rejects incoming payload when signature is invalid" do
    payload = {
      object: "whatsapp_business_account",
      entry: [ {
        id: "entry_2",
        changes: [ {
          field: "messages",
          value: {
            metadata: {
              phone_number_id: @other_account.phone_number_id
            }
          }
        } ]
      } ]
    }.to_json

    post webhooks_whatsapp_url,
         params: payload,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "X-Hub-Signature-256" => "sha256=invalid"
         }

    assert_response :unauthorized
    assert_equal 0, ProcessIncomingWhatsappWebhookJob.jobs.size
  end

  test "rejects incoming payload when account cannot be resolved from phone_number_id" do
    payload = {
      object: "whatsapp_business_account",
      entry: [ {
        id: "entry_3",
        changes: [ {
          field: "messages",
          value: {
            metadata: {
              phone_number_id: "999999999999"
            }
          }
        } ]
      } ]
    }.to_json

    signature = signed_meta_signature(payload, @account.app_secret_ciphertext)

    post webhooks_whatsapp_url,
         params: payload,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "X-Hub-Signature-256" => signature
         }

    assert_response :unauthorized
    assert_equal 0, ProcessIncomingWhatsappWebhookJob.jobs.size
  end

  private

  def signed_meta_signature(payload, app_secret)
    digest = OpenSSL::HMAC.hexdigest("SHA256", app_secret, payload)
    "sha256=#{digest}"
  end
end
