# Session Booking with Reminders

Members book 50-minute sessions with professionals, see their sessions, cancel or reschedule them, and get
in-app reminders 24 hours and 1 hour before each one. Professionals set their weekly availability, see their
schedule and can cancel. Every time is shown on the viewer's own clock.

- **Backend:** Rails 8.1 API (Ruby 3.4.7), PostgreSQL, Devise + devise-jwt, Solid Queue
- **Frontend:** React 19, Vite, MUI, Redux Toolkit Query

Design decisions and trade-offs are in [DECISIONS.md](DECISIONS.md).

## Run it with Docker (recommended)

Prerequisites: Docker with Docker Compose.

```bash
docker compose up --build
```

Then open **http://localhost:5173**, sign up as a professional and set your availability, then sign up as a
member (in another browser or a private window) and book a session. The API runs on http://localhost:3000.

- The first start creates both databases and loads the schema. Data is kept in a Docker volume.
- Ports 5173 and 3000 must be free, so stop any local Rails or Vite server first.
- The source is copied into the images, so run `docker compose up --build` again after changing code.
- `docker compose down -v` stops everything and deletes the data.

### Tests in Docker

```bash
docker compose run --rm -e RAILS_ENV=test backend bash -c "bin/rails db:prepare && bundle exec rspec"
docker compose run --rm --no-deps frontend npm test
```

## Run it locally

Prerequisites: Ruby 3.4.7, Node 24 (npm), PostgreSQL 14 or later (with the `btree_gist` extension, which
ships with the standard packages).

```bash
# Terminal 1: API on http://localhost:3000 (also runs the reminder jobs)
cd backend && bin/setup --skip-server && bin/rails server

# Terminal 2: frontend on http://localhost:5173
cd frontend && npm ci && npm run dev
```

The backend connects to PostgreSQL over the local socket as your OS user. To use another server, set
`DATABASE_HOST`, `DATABASE_USERNAME` and `DATABASE_PASSWORD`. The frontend calls `http://localhost:3000`;
copy `frontend/.env.example` to `frontend/.env.local` to change that. Use `localhost` rather than
`127.0.0.1` for both, because the auth cookie only works when the two count as the same site.

### Tests

```bash
cd backend && bin/rails db:test:prepare && bundle exec rspec
cd frontend && npm test
```