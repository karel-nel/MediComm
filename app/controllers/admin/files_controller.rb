class Admin::FilesController < Admin::BaseController
  before_action :set_attachment, only: :show

  def index
    @attachments = Admin::FilesQuery.new(practice: current_practice, params: params).results
    @processing_statuses = current_practice.intake_attachments.distinct.pluck(:processing_status).sort
  end

  def show
  end

  private

  def set_attachment
    @attachment = current_practice.intake_attachments.find(params[:id])
    @related_field_values = @attachment.source_field_values.includes(:intake_field, :intake_session)
  end
end
