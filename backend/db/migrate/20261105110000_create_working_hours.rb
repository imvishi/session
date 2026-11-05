class CreateWorkingHours < ActiveRecord::Migration[8.1]
  def change
    create_table :working_hours do |t|
      t.references :professional, null: false, foreign_key: { to_table: :users }, index: false
      t.integer :day_of_week, null: false, limit: 2
      t.integer :start_minute, null: false, limit: 2
      t.integer :end_minute, null: false, limit: 2

      t.timestamps

      t.check_constraint "day_of_week BETWEEN 0 AND 6", name: "working_hours_day_is_valid"
      t.check_constraint "start_minute >= 0 AND end_minute <= 1439", name: "working_hours_within_one_day"
      t.check_constraint "end_minute > start_minute", name: "working_hours_end_after_start"
    end

    add_index :working_hours, [ :professional_id, :day_of_week ], unique: true
  end
end
