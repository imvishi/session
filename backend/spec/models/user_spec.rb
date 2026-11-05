require "rails_helper"

RSpec.describe User, type: :model do
  def build_user(**overrides)
    User.new({
      name: "Test Member",
      email: "member@example.com",
      password: "password123",
      role: "member",
      timezone: "Asia/Singapore"
    }.merge(overrides))
  end

  describe "role" do
    it "allows member and professional" do
      expect(build_user(role: "member")).to be_valid
      expect(build_user(role: "professional")).to be_valid
    end

    it "rejects any other role without raising" do
      user = build_user(role: "admin")

      expect(user).not_to be_valid
      expect(user.errors).to have_key(:role)
    end

    it "is required" do
      expect(build_user(role: nil)).not_to be_valid
    end

    it "is enforced by the database even if validations are skipped" do
      user = build_user
      user.save!

      expect { User.where(id: user.id).update_all(role: "admin") }
        .to raise_error(ActiveRecord::StatementInvalid)
    end

    it "cannot change after creation" do
      user = build_user
      user.save!

      expect { user.role = "professional" }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end

  describe "timezone" do
    %w[Asia/Singapore America/New_York Europe/London UTC].each do |timezone|
      it "accepts the IANA timezone #{timezone}" do
        expect(build_user(timezone:)).to be_valid
      end
    end

    [ nil, "", "+08:00", "Mars/Olympus" ].each do |timezone|
      it "rejects #{timezone.inspect}" do
        user = build_user(timezone:)

        expect(user).not_to be_valid
        expect(user.errors).to have_key(:timezone)
      end
    end
  end

  describe "name" do
    it "is required" do
      expect(build_user(name: "   ")).not_to be_valid
    end

    it "has surrounding whitespace stripped" do
      expect(build_user(name: "  Sam ").name).to eq("Sam")
    end
  end

  describe "email" do
    it "is unique regardless of case, and stored in lowercase" do
      build_user(email: "Sam@Example.com").save!

      expect(build_user(email: "sam@example.COM")).not_to be_valid
      expect(User.last.email).to eq("sam@example.com")
    end

    it "is enforced by the database even if validations are skipped" do
      user = build_user
      user.save!

      expect { build_user.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect { User.where(id: user.id).update_all(email: "MEMBER@example.com") }
        .to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "password" do
    it "must be between 8 and 72 characters" do
      expect(build_user(password: "a" * 7)).not_to be_valid
      expect(build_user(password: "a" * 8)).to be_valid
      expect(build_user(password: "a" * 72)).to be_valid
      expect(build_user(password: "a" * 73)).not_to be_valid
    end
  end
end
