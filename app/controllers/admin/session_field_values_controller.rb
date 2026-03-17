class Admin::SessionFieldValuesController < Admin::BaseController
  before_action :set_session
  before_action :set_field_value

  def edit
  end

  def update
    corrected = Admin::FieldValueCorrection.new(
      intake_session: @intake_session,
      field_value: @field_value,
      reviewer: current_user,
      params: field_value_params
    ).call

    redirect_to admin_session_path(@intake_session), notice: "Field value corrected (new version ##{corrected.id})."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "Could not save field value correction."
    render :edit, status: :unprocessable_entity
  end

  private

  def set_session
    @intake_session = current_practice.intake_sessions.find(params[:session_id])
  end

  def set_field_value
    @field_value = @intake_session.intake_field_values.find(params[:id])
  end

  def field_value_params
    params.require(:intake_field_value).permit(:canonical_value_text, :status, :verified)
  end
end
