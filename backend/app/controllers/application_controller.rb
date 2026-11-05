class ApplicationController < ActionController::API
  # Secure by default: every endpoint requires a login unless it opts out.
  before_action :authenticate_user!

  private

  def require_professional!
    return if current_user.professional?

    render json: { error: "Only professionals can do this." }, status: :forbidden
  end

  def require_member!
    return if current_user.member?

    render json: { error: "Only members can do this." }, status: :forbidden
  end

  # An explicit list, so fields like encrypted_password can't leak.
  def user_json(user)
    user.slice(:id, :name, :email, :role, :timezone)
  end
end
