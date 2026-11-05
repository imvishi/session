class ApplicationController < ActionController::API
  # Secure by default: every endpoint requires a login unless it opts out.
  before_action :authenticate_user!

  private

  # An explicit list, so fields like encrypted_password can't leak.
  def user_json(user)
    user.slice(:id, :name, :email, :role, :timezone)
  end
end
