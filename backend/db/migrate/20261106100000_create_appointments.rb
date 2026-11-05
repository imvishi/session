class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"

    create_table :appointments do |t|
      t.references :member, null: false, foreign_key: { to_table: :users }, index: false
      t.references :professional, null: false, foreign_key: { to_table: :users }, index: false
      # The date and times on the professional's clock, not UTC. The timezone is an IANA name.
      t.date :appointment_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :timezone, null: false
      t.integer :status, null: false, default: 0, limit: 2

      t.timestamps

      t.check_constraint "end_time > start_time", name: "appointments_end_after_start"
      t.check_constraint "member_id <> professional_id", name: "appointments_different_people"
      t.check_constraint "status IN (0, 1)", name: "appointments_status_is_valid"
    end

    add_index :appointments, [ :member_id, :appointment_date ]
    add_index :appointments, [ :professional_id, :appointment_date ]

    # This stops double-booking a professional even when two requests arrive at the same moment,
    # which a check in Rails can't do. Their appointments share a timezone, so local times compare
    # correctly. Cancelled sessions are ignored, so their times free up.
    add_exclusion_constraint :appointments, "professional_id WITH =, tsrange(appointment_date + start_time, appointment_date + end_time) WITH &&",
                             using: :gist, where: "status = 0", name: "appointments_no_professional_overlap"
  end
end
