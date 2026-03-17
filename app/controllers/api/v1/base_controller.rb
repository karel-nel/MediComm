class Api::V1::BaseController < ActionController::API
  before_action :authenticate_n8n!

  private

  def authenticate_n8n!
    provided_token = request.authorization.to_s.delete_prefix("Bearer ").strip
    expected_token = ENV["N8N_BEARER_TOKEN"].to_s.strip
    expected_token = ENV["N8N_SHARED_BEARER_TOKEN"].to_s.strip if expected_token.blank?

    if expected_token.blank? || provided_token.blank?
      return render json: { error: "unauthorized" }, status: :unauthorized
    end

    return if ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)

    render json: { error: "unauthorized" }, status: :unauthorized
  end
end
