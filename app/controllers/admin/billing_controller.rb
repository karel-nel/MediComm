class Admin::BillingController < Admin::BaseController
  def show
    @summary = Admin::BillingSummary.new(practice: current_practice)
  end
end
