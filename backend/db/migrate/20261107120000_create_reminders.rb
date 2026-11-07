class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, index: false
      t.integer :minutes_before, null: false
      t.datetime :remind_at, null: false
      t.datetime :delivered_at
      t.text :message
      t.datetime :read_at
      # The Active Job id of the job that delivers it, so rescheduling or cancelling can remove that job.
      t.string :job_id

      t.timestamps

      t.check_constraint "minutes_before > 0", name: "reminders_minutes_before_is_positive"
      t.check_constraint "delivered_at IS NULL OR message IS NOT NULL", name: "reminders_delivered_with_message"
    end

    # A person's notification list, newest first.
    add_index :reminders, [ :user_id, :delivered_at ], where: "delivered_at IS NOT NULL", name: "index_reminders_delivered"
  end
end
