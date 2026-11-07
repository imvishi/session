require "rails_helper"

RSpec.describe DeliverReminderJob do
  describe ".enqueue_later" do
    let(:reminder) { instance_double(Reminder, id: 7, job_id: "job-7", remind_at: 1.day.from_now) }

    it "queues the job under the reminder's job_id, at its time" do
      described_class.enqueue_later(reminder)

      expect(described_class).to have_been_enqueued.with(7).at(reminder.remind_at)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.last["job_id"]).to eq("job-7")
    end

    it "reports a queue failure instead of raising it, because the change is already saved" do
      allow_any_instance_of(described_class).to receive(:enqueue).and_raise(ActiveRecord::ConnectionNotEstablished)
      allow(Rails.error).to receive(:report)

      expect { described_class.enqueue_later(reminder) }.not_to raise_error
      expect(Rails.error).to have_received(:report).with(an_instance_of(ActiveRecord::ConnectionNotEstablished), hash_including(handled: true))
    end
  end

  describe ".discard_later" do
    # Plain doubles, and queued_jobs stubbed: the test database has no Solid Queue tables,
    # because specs use the test adapter.
    let(:queued) { double("queued job", discard: true) }
    let(:running) { double("running job") }

    before do
      allow(described_class).to receive(:queue_adapter_name).and_return("solid_queue")
      allow(described_class).to receive(:queued_jobs).with(%w[a b]).and_return([ queued, running ])
      allow(running).to receive(:discard).and_raise(SolidQueue::Execution::UndiscardableError)
    end

    it "discards queued jobs, and leaves a running one to find its reminder gone" do
      described_class.discard_later([ "a", nil, "b" ])

      expect(queued).to have_received(:discard)
      expect(running).to have_received(:discard)
    end

    it "waits for the transaction to commit, and does nothing if it rolls back" do
      ActiveRecord::Base.transaction do
        described_class.discard_later(%w[a b])
        expect(described_class).not_to have_received(:queued_jobs)
        raise ActiveRecord::Rollback
      end

      expect(described_class).not_to have_received(:queued_jobs)
    end

    it "reports a queue failure instead of raising it" do
      allow(described_class).to receive(:queued_jobs).and_raise(ActiveRecord::ConnectionNotEstablished)
      allow(Rails.error).to receive(:report)

      expect { described_class.discard_later(%w[a b]) }.not_to raise_error
      expect(Rails.error).to have_received(:report)
    end

    it "does nothing with another queue adapter" do
      allow(described_class).to receive(:queue_adapter_name).and_return("test")

      described_class.discard_later(%w[a b])

      expect(described_class).not_to have_received(:queued_jobs)
    end
  end
end
