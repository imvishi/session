# Decisions

## Assumptions

- **Sessions:** 50 minutes, starting every 60 minutes from the start of the professional's working day, so
  there's a 10-minute break between them.
- **Overlapping sessions:** a member may book overlapping sessions with different professionals. Only a
  professional is limited to one session at a time.
- **Reminders:** they're in-app only, with no email or push.

## Key decisions and trade-offs

- **The backend owns every rule.**
  - It decides the slots, timezone conversion, labels, whether a session can still change, and the reminder
    messages.
  - The frontend only displays what the API sends and never does time arithmetic, so the two can't
    disagree.
  - The trade-off is more API fields, for example ready-made labels and `can_cancel`.
- **Slots are calculated, not stored.**
  - `SlotGenerator` builds them from the weekly hours on each request, so a change to working hours takes
    effect immediately, with nothing to keep in sync.
  - The server only accepts a booking that matches a slot it generates at that moment. That rules out past
    times, made-up times, and times beyond the 4-week window.
- **One rule for cancelling and rescheduling.**
  - `AppointmentPolicy` decides whether a session can change and gives the reason when it can't.
  - The API and the My sessions buttons both use it, so the buttons always match what the server accepts.
  - The 24 hours are measured between real moments, so a clock change doesn't shorten the notice.
- **Rescheduling moves the same appointment.**
  - It updates the existing row under a row lock, and the session stays `booked` with the same id.
  - A member can reschedule as often as they like, and can never end up with no session or two.
  - If the new time fails any check, the update rolls back and the session keeps its old time.
  - The trade-off is that there's no history of previous times.
- **Auth uses a JWT in an HttpOnly, SameSite=Strict cookie,** so JavaScript can't read the token. Because
  of SameSite, the frontend and API must be served from the same site.
- **Roles are an enum on `User`,** with no separate classes per role, because the two roles differ only in
  what they can do.

## How double-booking is prevented

A check in Rails followed by an insert can't prevent it: two requests can both pass the check before either
one inserts. So the database enforces it:

- A PostgreSQL **exclusion constraint** on `appointments` rejects two `booked` rows for the same
  professional whose time ranges overlap. Cancelled rows don't count.
- When two members race for the same slot, the first commit wins. The other gets a clear 409: "This time
  has just been booked by someone else. Please choose another."
- Overlapping inserts can also deadlock. Postgres aborts one of them, which still never allows a
  double-booking, and that member is told to try again. It isn't retried automatically.
- Specs race real threads against the real database to prove all this.

## How timezones and daylight saving are handled

**Storage.** An appointment stores its date, start time and end time on the **professional's clock**, plus
their IANA timezone (for example `Europe/London`). It deliberately doesn't store UTC.

- Working hours are wall-clock times, so a 09:00 session stays at 09:00 for the professional, even if
  daylight-saving or timezone rules change after it's booked.
- Real moments are calculated when needed: `AT TIME ZONE` in SQL, and `starts_at_utc` in Ruby.
- The exclusion constraint compares local times. That's safe because all of one professional's appointments
  are in their timezone.
- The app's `Time.zone` must stay UTC, otherwise Rails shifts the stored times.

**Display.** The server converts every slot and session to the viewer's own timezone, and groups slots by
the viewer's own date. So a slot can appear on a different date for the member than for the professional.
The booking screen shows both clocks.

**Daylight saving changes:**

- **Clocks go forward:** no slot starts in the missing hour. A session that would run across the jump is
  refused.
- **Clocks go back:** slots touching the repeated hour aren't offered. Local time alone can't tell the two
  01:30s apart, and skipping them means every stored appointment maps to exactly one moment.
- **Valid for both people:** an appointment is only saved if, on both the professional's clock and the
  member's, each end is a single unambiguous moment and the clocks don't change during the session. This is
  checked whenever the time is set or changed.

## How reminders are scheduled and delivered reliably

- **Scheduling.**
  - Booking creates one `reminders` row per person and lead time: the member and the professional, 24 hours
    and 1 hour before.
  - These rows are created in the same transaction as the appointment.
  - A reminder whose time has already passed isn't created.
  - Each row gets its own `DeliverReminderJob`, scheduled in Solid Queue for exactly that time.
- **Keeping them in step.** Rescheduling and cancelling replace the undelivered reminders, in the same
  transaction as the change. A cancelled session gets none. Delivered reminders are kept, because they're
  already notifications.
- **Surviving restarts.** Solid Queue stores jobs in PostgreSQL, so a job due while the server was down
  runs when it comes back.
- **Following the transaction.** The queue is a separate database. Jobs are queued only after the
  appointment's transaction commits, so a booking that rolls back leaves no jobs behind.
- **Exactly one delivery.** Solid Queue runs a job at least once, and an old job can still run after a
  change. So a job only carries the reminder id. Delivery locks the appointment and delivers only if the
  reminder still exists and hasn't been delivered.
- **Out-of-date reminders are skipped.** If the session is cancelled, has already started, or a later
  reminder is already due, nothing is sent.
- **A late job says the real time left.** For example, "starts in 20 minutes" instead of "in 1 hour".
- **The notification.** A delivered reminder is the notification. The message is written on the
  recipient's own clock and names the other person. There's no separate notifications table.
- **Lead times are configurable.** They live in one list, `Reminder::LEAD_TIMES`. The database only checks
  that `minutes_before` is positive, so changing them needs no migration.


## What I'd do next with more time

I reviewed most of the code myself, but I'm still not fully confident in some parts, especially
notifications. I'd review that part again and simplify it where I can.
