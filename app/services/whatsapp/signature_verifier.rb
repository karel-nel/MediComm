require "openssl"

module Whatsapp
  class SignatureVerifier
    def self.call(signature:, raw_body:, app_secret:)
      new(signature: signature, raw_body: raw_body, app_secret: app_secret).call
    end

    def initialize(signature:, raw_body:, app_secret:)
      @signature = signature
      @raw_body = raw_body
      @app_secret = app_secret
    end

    def call
      secret = app_secret.to_s.strip
      return false if secret.blank? || raw_body.blank?

      signature_digest = extract_signature_digest
      return false if signature_digest.blank?

      expected_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
      ActiveSupport::SecurityUtils.secure_compare(signature_digest, expected_signature)
    end

    private

    attr_reader :app_secret, :raw_body, :signature

    def extract_signature_digest
      match = signature.to_s.match(/\Asha256=(?<digest>[0-9a-f]{64})\z/i)
      match&.[](:digest)&.downcase
    end
  end
end
