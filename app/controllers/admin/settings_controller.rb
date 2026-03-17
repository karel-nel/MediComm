class Admin::SettingsController < Admin::BaseController
  before_action :set_settings_summary

  def show
  end

  def update
    if current_practice.update(settings_params)
      redirect_to admin_settings_path, notice: "Practice settings updated."
    else
      flash.now[:alert] = "Could not update practice settings."
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_settings_summary
    @team_member_count = current_practice.users.count
    @flow_count = current_practice.intake_flows.count
  end

  def settings_params
    params.require(:practice).permit(:name, :contact_email, :timezone, :status)
  end
end
