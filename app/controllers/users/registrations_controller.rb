class Users::RegistrationsController < Devise::RegistrationsController
  def create
    practice = build_practice
    build_resource(sign_up_params.except(:practice_name))
    resource.practice_name = sign_up_params[:practice_name]
    resource.practice = practice
    resource.role = :owner
    resource.active = true

    begin
      ActiveRecord::Base.transaction do
        practice.save!
        resource.save!
      end
    rescue ActiveRecord::RecordInvalid
      merge_practice_errors(practice)
      clean_up_passwords resource
      set_minimum_password_length
      return respond_with resource
    rescue ActiveRecord::RecordNotUnique
      resource.errors.add(:practice_name, "has already been taken")
      clean_up_passwords resource
      set_minimum_password_length
      return respond_with resource
    end

    yield resource if block_given?

    if resource.active_for_authentication?
      set_flash_message! :notice, :signed_up
      sign_up(resource_name, resource)
      respond_with resource, location: after_sign_up_path_for(resource)
    else
      set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
      expire_data_after_sign_in!
      respond_with resource, location: after_inactive_sign_up_path_for(resource)
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(
      :first_name, :last_name, :practice_name, :email, :password, :password_confirmation
    )
  end

  def build_practice
    Practice.new(
      name: sign_up_params[:practice_name],
      contact_email: sign_up_params[:email],
      timezone: Practice::DEFAULT_TIMEZONE,
      status: Practice::DEFAULT_STATUS
    )
  end

  def merge_practice_errors(practice)
    return if practice.errors.empty?

    practice.errors.each do |error|
      attribute = error.attribute == :name ? :practice_name : error.attribute
      resource.errors.add(attribute, error.message)
    end
  end
end
