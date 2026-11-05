class User < ApplicationRecord
  include MemberRole
  include ProfessionalRole

  devise :database_authenticatable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: Devise::JWT::RevocationStrategies::Null

  enum :role, { member: "member", professional: "professional" }, validate: true

  # A role is chosen at sign-up and can never change.
  attr_readonly :role

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 100 }
  validates :timezone, iana_timezone: true
end
