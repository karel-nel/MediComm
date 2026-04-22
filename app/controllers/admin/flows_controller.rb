class Admin::FlowsController < Admin::BaseController
  before_action :set_flow, only: [ :show, :edit, :update, :publish, :revert_to_draft, :archive, :destroy ]

  def index
    @flows = current_practice
      .intake_flows
      .includes(:created_by, :intake_fields, :intake_field_groups)
      .order(updated_at: :desc)
  end

  def new
    @flow = current_practice.intake_flows.new(
      flow_type: "new_patient",
      tone_preset: "professional",
      default_language: "en-ZA",
      status: :draft
    )
    @presenter = Admin::FlowEditorPresenter.new(flow: @flow)
  end

  def create
    @flow = current_practice.intake_flows.new(flow_params)
    @flow.created_by = current_user
    @flow.completion_email_recipients_json = completion_recipients_array

    begin
      ActiveRecord::Base.transaction do
        @flow.save!
        apply_extraction_policy! if extraction_policy_param.present?
      end
      redirect_to edit_admin_flow_path(@flow), notice: "Flow created."
    rescue ActiveRecord::RecordInvalid
      @presenter = Admin::FlowEditorPresenter.new(flow: @flow)
      flash.now[:alert] = "Please review the fields below."
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @presenter = Admin::FlowEditorPresenter.new(flow: @flow)
  end

  def edit
    @presenter = Admin::FlowEditorPresenter.new(flow: @flow)
  end

  def update
    attributes = flow_params.merge(
      completion_email_recipients_json: completion_recipients_array
    )

    begin
      ActiveRecord::Base.transaction do
        @flow.update!(attributes)
        apply_extraction_policy! if extraction_policy_param.present?
      end
      redirect_to edit_admin_flow_path(@flow), notice: "Flow configuration updated."
    rescue ActiveRecord::RecordInvalid
      @presenter = Admin::FlowEditorPresenter.new(flow: @flow)
      flash.now[:alert] = "Please review the fields below."
      render :edit, status: :unprocessable_entity
    end
  end

  def publish
    @flow.update!(status: :published, published_at: Time.current)
    redirect_to admin_flow_path(@flow), notice: "Flow published."
  end

  def revert_to_draft
    @flow.update!(status: :draft)
    redirect_to admin_flow_path(@flow), notice: "Flow moved back to draft."
  end

  def archive
    @flow.update!(status: :archived)
    redirect_to admin_flows_path, notice: "Flow archived."
  end

  def destroy
    archive
  end

  private

  def set_flow
    @flow = current_practice
      .intake_flows
      .includes(:intake_field_groups, intake_fields: :intake_field_group)
      .find(params[:id])
  end

  def flow_params
    params.require(:intake_flow).permit(
      :name,
      :description,
      :flow_type,
      :status,
      :default_language,
      :tone_preset,
      :allow_skip_by_default,
      :completion_email_enabled,
      intake_fields_attributes: [ :id, :required, :ask_priority, :source_preference, :extraction_enabled, :active, { linked_field_keys: [] } ]
    )
  end

  def completion_recipients_array
    raw = params.dig(:intake_flow, :completion_email_recipients_text).to_s
    raw.split(",").map(&:strip).reject(&:blank?)
  end

  def extraction_policy_param
    params.dig(:intake_flow, :extraction_policy).to_s
  end

  def apply_extraction_policy!
    case extraction_policy_param
    when "enabled"
      @flow.intake_fields.update_all(extraction_enabled: true)
    when "disabled"
      @flow.intake_fields.update_all(extraction_enabled: false)
    end
  end
end
