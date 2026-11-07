# AI usage

## Tools

**Claude Code** (Anthropic's coding agent in the terminal, running Claude Opus) was the only AI tool I used.
I worked with it as a pair programmer: I set the direction and the rules, it wrote code and specs against
them, and I reviewed every change, edited files myself and pushed back when it got something wrong.

| Part | How AI was used |
|---|---|
| Auth (Devise + JWT in an HttpOnly cookie) | Generated the setup and request specs; I decided the cookie approach and the role model (an enum, not STI). |
| Availability and slots | Wrote `SlotGenerator`, `WeeklyAvailability` and the daylight-saving handling with me; I set the rule that the backend owns all time logic. |
| Booking | Wrote `BookAppointment`, the exclusion constraint and the concurrency specs that race real threads. |
| My sessions, cancel and reschedule | Wrote `SessionList`, `AppointmentPolicy` and the services from the brief, then reworked them after my corrections below. |
| Reminders and notifications | Wrote the reminder model, Solid Queue jobs and notification list; redesigned twice at my direction. |
| Frontend | Wrote the React pages, RTK Query endpoints and Vitest tests. |
| Docker and README | Wrote `compose.yaml`, the dev Dockerfiles and the docs; I edited the wording. |
| Review | Ran `/code-review` on the reminder work, which found real bugs (see the last example). |

## Where I corrected, rejected or improved what the AI produced

### 1. Storing appointments in UTC: rejected

The AI suggested the usual approach: store each appointment as `starts_at` and `ends_at` in UTC. I chose
to store the appointment date, start time and end time on the professional's clock, plus their IANA timezone.
A professional's working hours are wall-clock times ("Monday 09:00"), and a session at 09:00 should stay at
09:00 for them even if a government changes its timezone or daylight-saving rules after the booking. A UTC
timestamp would silently move it. Stored local time also reads naturally for the professional and matches how
slots are generated from their weekly hours.

The cost is that real moments have to be calculated when comparing or sending times. That's done in SQL with
`AT TIME ZONE`, and in `Appointment#starts_at_utc` for Ruby code. Two other consequences are handled
deliberately:
- The exclusion constraint compares local times, which is correct because all of one professional's
  appointments are in their timezone.
- When the clocks go back, local time can't tell the two repeated hours apart, so slots touching that hour
  aren't offered.

### 2. Rescheduling as a new status: rejected

The AI first modelled a reschedule as a `rescheduled` status on the old appointment plus a new booking. I
rejected it. A member can reschedule as many times as they like, and a chain of `rescheduled` rows adds
states to every query and makes "never leave the member with no session or two sessions" harder to
guarantee, because it becomes a two-row operation. I had it update the same row in place under a lock, so
the appointment keeps its id and stays `booked`, and the constraint check applies to the new time. The status
migration was rolled back and deleted.

### 3. Locking members against overlapping bookings: rejected

To stop double-booking the AI also locked the member's row and refused overlapping sessions for a member
(`MEMBER_BUSY`). The brief only requires that a *professional* can't be double-booked. The extra lock added
contention and a rule nobody asked for, so I removed it: only the professional is protected, by a database
exclusion constraint.

### 4. Automatic deadlock retry: rejected

The concurrency specs showed overlapping inserts can deadlock in Postgres. The AI added a retry loop
(`TRY_AGAIN`). I replaced it with a clear "can't book right now" message. Postgres already guarantees no
double-booking when it aborts one transaction, and a hidden retry loop is more code to reason about than the
rare case is worth.

### 5. A recurring sweep for reminders: improved

The AI's first reminder design was a job running every minute that delivered whatever was due. I asked why
we didn't schedule one job per reminder at its exact time, and then asked for those jobs to be updated when a
session is rescheduled or cancelled. It reworked the design: each reminder row stores its job id, jobs are
queued only after the transaction commits, and delivery locks the row so a stale or duplicate job does
nothing. Reminders now arrive on time instead of up to a minute late, with no polling.

### 6. Hardcoded lead times in the database: corrected

The reminders table had a check constraint `lead_time IN (0, 1)`. I pointed out that lead times could be
anything in future. It became `minutes_before`, with the database only checking that it's positive and the
lead times defined in one list in `Reminder::LEAD_TIMES`, so they change without a migration.

### 7. Responsibility in the wrong class: corrected

The AI put `local_attributes` (turning a slot into appointment columns) on `Appointment`. That isn't the
model's job, so it moved to the `Slot` value object that `SlotGenerator` returns. I also had it rewrite the
"valid for both people" daylight-saving check so it reads clearly, and keep models from calling services.

### 8. Frontend polling: rejected

The navbar polled notifications every minute. I removed it: a page reload shows new notifications, and every
open tab calling the server each minute wasn't worth it for this app.

### 9. A claim the AI got wrong, caught by review

While building the reminder jobs, the AI said it had verified against the real queue that cancelling or
rescheduling removes the old scheduled jobs. A later `/code-review` showed this was wrong: in Solid Queue
1.7.2, `Job#discard` ignores jobs that are still scheduled, which reminder jobs always are. The specs missed
it because they stubbed the queue lookup, and coverage confirmed that line never ran in tests. Users are not
affected, because a stale job finds its reminder deleted and does nothing, but the old jobs stay queued until
their time. This is still open. The lesson for me: don't accept "verified" from an AI without seeing the check,
and be wary of specs that stub the exact thing they claim to test.
