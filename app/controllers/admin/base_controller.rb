class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_practice_context!
  before_action :ensure_active_account!

  layout "admin"

  private

  def ensure_practice_context!
    return if current_practice.present?

    sign_out(current_user) if current_user
    redirect_to new_user_session_path, alert: "Your account is not linked to a practice yet."
  end

  def ensure_active_account!
    return if current_user&.active?

    sign_out(current_user) if current_user
    redirect_to new_user_session_path, alert: "Your account is inactive."
  end
end
