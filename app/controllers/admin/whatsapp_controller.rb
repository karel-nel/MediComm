class Admin::WhatsappController < Admin::BaseController
  before_action :set_account, only: [ :edit, :update ]

  def show
    @overview = Admin::WhatsappOverview.new(practice: current_practice)
    @account = current_practice.whatsapp_accounts.order(:created_at).first
  end

  def new
    @account = current_practice.whatsapp_accounts.new(active: true)
  end

  def create
    @account = current_practice.whatsapp_accounts.new(sanitized_whatsapp_params)

    if @account.save
      redirect_to admin_whatsapp_path, notice: "WhatsApp account created."
    else
      flash.now[:alert] = "Could not create WhatsApp account."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(sanitized_whatsapp_params)
      redirect_to admin_whatsapp_path, notice: "WhatsApp account updated."
    else
      flash.now[:alert] = "Could not update WhatsApp account."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = current_practice.whatsapp_accounts.order(:created_at).first
    redirect_to new_admin_whatsapp_path, alert: "No WhatsApp account configured yet." unless @account
  end

  def whatsapp_params
    params.require(:whatsapp_account).permit(
      :business_account_name,
      :phone_number_id,
      :waba_id,
      :display_phone_number,
      :access_token_ciphertext,
      :active
    )
  end

  def sanitized_whatsapp_params
    permitted = whatsapp_params
    return permitted unless permitted.key?(:access_token_ciphertext)

    return permitted if permitted[:access_token_ciphertext].present?

    permitted.except(:access_token_ciphertext)
  end
end
