# The parts of User that only apply to members.
module MemberRole
  extend ActiveSupport::Concern

  included do
    has_many :member_appointments, class_name: "Appointment", foreign_key: :member_id,
                               inverse_of: :member, dependent: :restrict_with_error
  end
end
