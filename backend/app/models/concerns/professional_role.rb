# The parts of User that only apply to professionals.
module ProfessionalRole
  extend ActiveSupport::Concern

  included do
    has_many :working_hours, foreign_key: :professional_id,
                             inverse_of: :professional, dependent: :destroy
    has_many :professional_appointments, class_name: "Appointment", foreign_key: :professional_id,
                                     inverse_of: :professional, dependent: :restrict_with_error
  end
end
