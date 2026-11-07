# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_07_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.bigint "member_id", null: false
    t.bigint "professional_id", null: false
    t.date "appointment_date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.string "timezone", null: false
    t.integer "status", limit: 2, default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id", "appointment_date"], name: "index_appointments_on_member_id_and_appointment_date"
    t.index ["professional_id", "appointment_date"], name: "index_appointments_on_professional_id_and_appointment_date"
    t.check_constraint "end_time > start_time", name: "appointments_end_after_start"
    t.check_constraint "member_id <> professional_id", name: "appointments_different_people"
    t.check_constraint "status = ANY (ARRAY[0, 1])", name: "appointments_status_is_valid"
    t.exclusion_constraint "professional_id WITH =, tsrange((appointment_date + start_time), (appointment_date + end_time)) WITH &&", where: "status = 0", using: :gist, name: "appointments_no_professional_overlap"
  end

  create_table "reminders", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.bigint "user_id", null: false
    t.integer "minutes_before", null: false
    t.datetime "remind_at", null: false
    t.datetime "delivered_at"
    t.text "message"
    t.datetime "read_at"
    t.string "job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_reminders_on_appointment_id"
    t.index ["user_id", "delivered_at"], name: "index_reminders_delivered", where: "(delivered_at IS NOT NULL)"
    t.check_constraint "delivered_at IS NULL OR message IS NOT NULL", name: "reminders_delivered_with_message"
    t.check_constraint "minutes_before > 0", name: "reminders_minutes_before_is_positive"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "encrypted_password", null: false
    t.string "role", null: false
    t.string "timezone", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "email::text = lower(email::text)", name: "users_email_is_lowercase"
    t.check_constraint "role::text = ANY (ARRAY['member'::character varying, 'professional'::character varying]::text[])", name: "users_role_is_valid"
  end

  create_table "working_hours", force: :cascade do |t|
    t.bigint "professional_id", null: false
    t.integer "day_of_week", limit: 2, null: false
    t.integer "start_minute", limit: 2, null: false
    t.integer "end_minute", limit: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["professional_id", "day_of_week"], name: "index_working_hours_on_professional_id_and_day_of_week", unique: true
    t.check_constraint "day_of_week >= 0 AND day_of_week <= 6", name: "working_hours_day_is_valid"
    t.check_constraint "end_minute > start_minute", name: "working_hours_end_after_start"
    t.check_constraint "start_minute >= 0 AND end_minute <= 1439", name: "working_hours_within_one_day"
  end

  add_foreign_key "appointments", "users", column: "member_id"
  add_foreign_key "appointments", "users", column: "professional_id"
  add_foreign_key "reminders", "appointments"
  add_foreign_key "reminders", "users"
  add_foreign_key "working_hours", "users", column: "professional_id"
end
