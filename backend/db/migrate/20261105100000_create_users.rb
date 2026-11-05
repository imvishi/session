class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :encrypted_password, null: false
      t.string :role, null: false
      t.string :timezone, null: false

      t.timestamps

      t.check_constraint "role IN ('member', 'professional')", name: "users_role_is_valid"
      # With the unique index below, this makes uniqueness case-insensitive in the database.
      t.check_constraint "email = lower(email)", name: "users_email_is_lowercase"
    end

    add_index :users, :email, unique: true
  end
end
