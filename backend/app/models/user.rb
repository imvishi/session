class User < ApplicationRecord
  devise :database_authenticatable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: Devise::JWT::RevocationStrategies::Null

  enum :role, { member: "member", professional: "professional" }, validate: true

  # A role is chosen at sign-up and can never change.
  attr_readonly :role

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 100 }
  validate :timezone_is_iana_identifier

  private

  def timezone_is_iana_identifier
    return if TZInfo::Timezone.all_identifiers.include?(timezone)

    errors.add(:timezone, "is not a valid IANA timezone")
  end
end
