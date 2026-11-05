import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ApiProvider } from '@reduxjs/toolkit/query/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import { baseApi } from './api/baseApi'
import App from './App'
import { browserTimezone } from './utils/timezones'

const member = {
  id: 1,
  name: 'Sam Member',
  email: 'sam@example.com',
  role: 'member',
  timezone: 'Asia/Singapore',
}

function json(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}

const unauthorized = () => json(401, { error: 'You need to sign in or sign up before continuing.' })

/** Stubs fetch with one handler per "METHOD /path". Anything else fails the test. */
function stubApi(routes) {
  const requests = []
  vi.stubGlobal(
    'fetch',
    vi.fn(async (request) => {
      const key = `${request.method} ${new URL(request.url).pathname}`
      const text = await request.clone().text()
      requests.push({ key, credentials: request.credentials, body: text ? JSON.parse(text) : undefined })
      const handler = routes[key]
      if (!handler) throw new Error(`Unexpected request: ${key}`)
      return handler()
    }),
  )
  return {
    requests,
    requestTo(key) {
      const request = requests.find((r) => r.key === key)
      if (!request) throw new Error(`No request made: ${key}`)
      return request
    },
  }
}

function renderAt(path) {
  render(
    <ApiProvider api={baseApi}>
      <MemoryRouter initialEntries={[path]}>
        <App />
      </MemoryRouter>
    </ApiProvider>,
  )
  return { user: userEvent.setup() }
}

describe('routing', () => {
  it('sends a logged-out visitor from a private page to the login page', async () => {
    stubApi({ 'GET /api/v1/me': unauthorized })
    renderAt('/availability')

    expect(await screen.findByRole('heading', { name: 'Log in' })).toBeInTheDocument()
  })

  it('shows a loading spinner, not the login page, while checking who is logged in', async () => {
    stubApi({ 'GET /api/v1/me': () => new Promise(() => {}) })
    renderAt('/availability')

    expect(await screen.findByRole('progressbar', { name: 'Loading' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Log in' })).not.toBeInTheDocument()
  })

  it('keeps a professional on the page they refreshed', async () => {
    stubApi({
      'GET /api/v1/me': () => json(200, { user: professional }),
      'GET /api/v1/availability': () => availabilityResponse([]),
    })
    renderAt('/availability')

    expect(await screen.findByRole('heading', { name: 'Availability' })).toBeInTheDocument()
  })

  it('sends a logged-in user from an unknown page to home', async () => {
    stubApi({ 'GET /api/v1/me': () => json(200, { user: member }) })
    renderAt('/no-such-page')

    expect(await screen.findByRole('heading', { name: 'Welcome, Sam Member' })).toBeInTheDocument()
  })

  it.each([
    ['member', () => member, ['ThoughtFull', 'Find a professional']],
    ['professional', () => professional, ['ThoughtFull', 'Availability']],
  ])('gives a %s only their own navbar links', async (_role, currentUser, links) => {
    stubApi({ 'GET /api/v1/me': () => json(200, { user: currentUser() }) })
    renderAt('/')

    const navbar = await screen.findByRole('navigation', { name: 'Main' })

    expect(within(navbar).getAllByRole('link').map((link) => link.textContent)).toEqual(links)
    expect(within(navbar).getByRole('button', { name: 'Log out' })).toBeInTheDocument()
  })

  it('sends a logged-out visitor to the login page', async () => {
    stubApi({ 'GET /api/v1/me': unauthorized })
    renderAt('/')

    expect(await screen.findByRole('heading', { name: 'Log in' })).toBeInTheDocument()
  })

  it('keeps a logged-in user, found from the cookie, away from the login page', async () => {
    stubApi({ 'GET /api/v1/me': () => json(200, { user: member }) })
    renderAt('/login')

    expect(await screen.findByRole('heading', { name: 'Welcome, Sam Member' })).toBeInTheDocument()
  })

  it('still renders the login page if the check for a user fails', async () => {
    stubApi({ 'GET /api/v1/me': () => json(500, {}) })
    renderAt('/')

    expect(await screen.findByRole('heading', { name: 'Log in' })).toBeInTheDocument()
  })

  it('moves between login and signup', async () => {
    stubApi({ 'GET /api/v1/me': unauthorized })
    const { user } = renderAt('/login')

    await user.click(await screen.findByRole('link', { name: 'Create an account' }))
    expect(screen.getByRole('heading', { name: 'Create your account' })).toBeInTheDocument()

    await user.click(screen.getByRole('link', { name: 'Log in' }))
    expect(screen.getByRole('heading', { name: 'Log in' })).toBeInTheDocument()
  })
})

describe('login', () => {
  async function fillIn(user) {
    await user.type(await screen.findByLabelText(/Email/), 'sam@example.com')
    await user.type(screen.getByLabelText(/Password/), 'password123')
    await user.click(screen.getByRole('button', { name: 'Log in' }))
  }

  it('logs in, sending the cookie with the request, and shows the home page', async () => {
    const { requestTo } = stubApi({
      'GET /api/v1/me': unauthorized,
      'POST /api/v1/auth/login': () => json(200, { user: member }),
    })
    const { user } = renderAt('/login')

    await fillIn(user)

    expect(await screen.findByRole('heading', { name: 'Welcome, Sam Member' })).toBeInTheDocument()
    const request = requestTo('POST /api/v1/auth/login')
    expect(request.credentials).toBe('include')
    expect(request.body).toEqual({ user: { email: 'sam@example.com', password: 'password123' } })
  })

  it("shows the API's error and stays on the page", async () => {
    stubApi({
      'GET /api/v1/me': unauthorized,
      'POST /api/v1/auth/login': () => json(401, { error: 'Invalid email or password.' }),
    })
    const { user } = renderAt('/login')

    await fillIn(user)

    expect(await screen.findByRole('alert')).toHaveTextContent('Invalid email or password.')
    expect(screen.getByRole('button', { name: 'Log in' })).toBeEnabled()
  })

  it('explains when the server cannot be reached', async () => {
    stubApi({ 'GET /api/v1/me': unauthorized })
    const { user } = renderAt('/login')
    await screen.findByRole('heading', { name: 'Log in' })
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))

    await fillIn(user)

    expect(await screen.findByRole('alert')).toHaveTextContent("couldn't reach the server")
  })
})

describe('signup', () => {
  async function fillIn(user) {
    await user.type(await screen.findByLabelText(/Full name/), 'Sam Member')
    await user.type(screen.getByLabelText(/Email/), 'sam@example.com')
    await user.type(screen.getByLabelText(/Password/), 'password123')
  }

  it('signs up as a member by default, in the browser timezone', async () => {
    const { requestTo } = stubApi({
      'GET /api/v1/me': unauthorized,
      'POST /api/v1/auth/signup': () => json(201, { user: member }),
    })
    const { user } = renderAt('/signup')

    await fillIn(user)
    await user.click(screen.getByRole('button', { name: 'Create account' }))

    expect(await screen.findByRole('heading', { name: 'Welcome, Sam Member' })).toBeInTheDocument()
    expect(requestTo('POST /api/v1/auth/signup').body).toEqual({
      user: {
        name: 'Sam Member',
        email: 'sam@example.com',
        password: 'password123',
        role: 'member',
        timezone: browserTimezone(),
      },
    })
  })

  it('signs up as a professional in a chosen timezone', async () => {
    const { requestTo } = stubApi({
      'GET /api/v1/me': unauthorized,
      'POST /api/v1/auth/signup': () => json(201, { user: { ...member, role: 'professional' } }),
    })
    const { user } = renderAt('/signup')

    await fillIn(user)
    await user.click(screen.getByRole('button', { name: 'Professional' }))
    const timezone = screen.getByRole('combobox', { name: /Timezone/ })
    await user.clear(timezone)
    await user.type(timezone, 'Europe/Lond')
    await user.click(await screen.findByRole('option', { name: 'Europe/London' }))
    await user.click(screen.getByRole('button', { name: 'Create account' }))

    await waitFor(() => {
      expect(requestTo('POST /api/v1/auth/signup').body).toMatchObject({
        user: { role: 'professional', timezone: 'Europe/London' },
      })
    })
  })

  it('always keeps a role selected', async () => {
    stubApi({ 'GET /api/v1/me': unauthorized })
    const { user } = renderAt('/signup')
    const memberButton = await screen.findByRole('button', { name: 'Member' })

    await user.click(memberButton)

    expect(memberButton).toHaveAttribute('aria-pressed', 'true')
  })

  it("shows the API's field errors next to their fields", async () => {
    stubApi({
      'GET /api/v1/me': unauthorized,
      'POST /api/v1/auth/signup': () => json(422, { errors: { email: ['has already been taken'] } }),
    })
    const { user } = renderAt('/signup')

    await fillIn(user)
    await user.click(screen.getByRole('button', { name: 'Create account' }))

    expect(await screen.findByText('Email has already been taken')).toBeInTheDocument()
    expect(screen.getByLabelText(/Email/)).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByRole('button', { name: 'Create account' })).toBeEnabled()
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })
})

const professional = { ...member, id: 2, name: 'Pat Professional', role: 'professional' }
const otherProfessional = { ...professional, id: 3, name: 'Alex Professional', email: 'alex@example.com' }

const WEEK = [
  [1, 'Monday'],
  [2, 'Tuesday'],
  [3, 'Wednesday'],
  [4, 'Thursday'],
  [5, 'Friday'],
  [6, 'Saturday'],
  [0, 'Sunday'],
]
const mondayHours = { day_of_week: 1, start_minute: 600, end_minute: 930, slot_count: 5 }

function timeOption(label) {
  const [hours, minutes] = label.split(':').map(Number)
  return { value: hours * 60 + minutes, label }
}

/** What the API returns: a whole week, with these saved days merged in. */
function availabilityBody(savedDays = [], overrides = {}) {
  return {
    timezone_label: 'Asia/Singapore (GMT+08:00)',
    session_minutes: 50,
    slot_interval_minutes: 60,
    break_minutes: 10,
    time_options: ['09:00', '09:30', '10:00', '10:30', '12:00', '15:30', '17:00'].map(timeOption),
    days: WEEK.map(([day_of_week, name]) => ({
      day_of_week,
      name,
      working: false,
      start_minute: 540,
      end_minute: 1020,
      slot_count: null,
      ...(savedDays.find((day) => day.day_of_week === day_of_week) && {
        working: true,
        ...savedDays.find((day) => day.day_of_week === day_of_week),
      }),
    })),
    ...overrides,
  }
}
const availabilityResponse = (savedDays, overrides) => json(200, availabilityBody(savedDays, overrides))

/** Logs in as the next person on this browser, and opens their availability page. */
async function openAvailabilityAsNextPerson(user) {
  await user.type(screen.getByLabelText(/Email/), otherProfessional.email)
  await user.type(screen.getByLabelText(/Password/), 'password123')
  await user.click(screen.getByRole('button', { name: 'Log in' }))
  await user.click(await screen.findByRole('link', { name: 'Availability' }))
}

describe('logout', () => {
  it('returns to the login page', async () => {
    stubApi({
      'GET /api/v1/me': () => json(200, { user: member }),
      'DELETE /api/v1/auth/logout': () => new Response(null, { status: 204 }),
    })
    const { user } = renderAt('/')

    await user.click(await screen.findByRole('button', { name: 'Log out' }))

    expect(await screen.findByRole('heading', { name: 'Log in' })).toBeInTheDocument()
  })

  it("never shows the last person's cached data to the next person on this browser", async () => {
    let hours = [mondayHours]
    const api = stubApi({
      'GET /api/v1/me': () => json(200, { user: professional }),
      'GET /api/v1/availability': () => availabilityResponse(hours),
      'DELETE /api/v1/auth/logout': () => new Response(null, { status: 204 }),
      'POST /api/v1/auth/login': () => json(200, { user: otherProfessional }),
    })
    const { user } = renderAt('/availability')
    expect(await screen.findByLabelText('Monday')).toBeChecked()

    await user.click(screen.getByRole('button', { name: 'Log out' }))
    await screen.findByRole('heading', { name: 'Log in' })
    hours = []
    await openAvailabilityAsNextPerson(user)

    await screen.findByRole('button', { name: 'Save availability' })
    expect(screen.getByLabelText('Monday')).not.toBeChecked()
    expect(api.requests.filter((request) => request.key === 'GET /api/v1/availability')).toHaveLength(2)
  })

  it('stays logged in and says so if the request fails', async () => {
    stubApi({
      'GET /api/v1/me': () => json(200, { user: member }),
      'DELETE /api/v1/auth/logout': () => json(500, {}),
    })
    const { user } = renderAt('/')

    await user.click(await screen.findByRole('button', { name: 'Log out' }))

    expect(await screen.findByRole('alert')).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'Welcome, Sam Member' })).toBeInTheDocument()
  })
})

describe('an expired login', () => {
  it('sends the user to the login page and clears cached data on any 401', async () => {
    let hours = [mondayHours]
    const api = stubApi({
      'GET /api/v1/me': () => json(200, { user: professional }),
      'GET /api/v1/availability': () => availabilityResponse(hours),
      'PUT /api/v1/availability': unauthorized,
      'POST /api/v1/auth/login': () => json(200, { user: otherProfessional }),
    })
    const { user } = renderAt('/availability')

    await user.click(await screen.findByRole('button', { name: 'Save availability' }))
    expect(await screen.findByRole('heading', { name: 'Log in' })).toBeInTheDocument()

    hours = []
    await openAvailabilityAsNextPerson(user)

    await screen.findByRole('button', { name: 'Save availability' })
    expect(screen.getByLabelText('Monday')).not.toBeChecked()
    expect(api.requests.filter((request) => request.key === 'GET /api/v1/availability')).toHaveLength(2)
  })
})

describe('availability', () => {
  const availability = availabilityResponse
  const monday = mondayHours

  function stubProfessional(routes) {
    return stubApi({ 'GET /api/v1/me': () => json(200, { user: professional }), ...routes })
  }

  it('links to the page from the navbar, for a professional', async () => {
    stubProfessional({ 'GET /api/v1/availability': () => availability([]) })
    const { user } = renderAt('/')

    await user.click(await screen.findByRole('link', { name: 'Availability' }))

    expect(await screen.findByRole('heading', { name: 'Availability' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Availability' })).toHaveAttribute('aria-current', 'page')
  })

  it('returns home from the navbar, and can log out from the availability page', async () => {
    stubProfessional({
      'GET /api/v1/availability': () => availability([]),
      'DELETE /api/v1/auth/logout': () => new Response(null, { status: 204 }),
    })
    const { user } = renderAt('/availability')

    await user.click(await screen.findByRole('link', { name: 'ThoughtFull' }))
    expect(await screen.findByRole('heading', { name: 'Welcome, Pat Professional' })).toBeInTheDocument()

    await user.click(screen.getByRole('link', { name: 'Availability' }))
    await user.click(await screen.findByRole('button', { name: 'Log out' }))

    expect(await screen.findByRole('heading', { name: 'Log in' })).toBeInTheDocument()
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument()
  })

  it('keeps a member away from the page, with no link to it', async () => {
    const api = stubApi({ 'GET /api/v1/me': () => json(200, { user: member }) })
    renderAt('/availability')

    expect(await screen.findByRole('heading', { name: 'Welcome, Sam Member' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Log out' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Availability' })).not.toBeInTheDocument()
    expect(api.requests.map((request) => request.key)).not.toContain('GET /api/v1/availability')
  })

  it('shows the days, hours, timezone and slot layout exactly as the API sends them', async () => {
    const body = availabilityBody([], {
      timezone_label: 'Test/Zone (GMT+01:23)',
      session_minutes: 40,
      slot_interval_minutes: 45,
      break_minutes: 5,
      time_options: ['08:00', '08:45'].map(timeOption),
      days: [
        { day_of_week: 3, name: 'Midweek', working: true, start_minute: 480, end_minute: 525, slot_count: 1 },
        { day_of_week: 0, name: 'Restday', working: false, start_minute: 525, end_minute: 525, slot_count: null },
      ],
    })
    stubProfessional({ 'GET /api/v1/availability': () => json(200, body) })
    renderAt('/availability')

    expect(await screen.findByLabelText('Midweek')).toBeChecked()
    expect(screen.getByLabelText('Restday')).not.toBeChecked()
    expect(screen.getByLabelText('Restday start time')).toBeDisabled()
    expect(screen.getByLabelText('Restday start time')).toHaveValue('525')
    expect(screen.queryByLabelText('Monday')).not.toBeInTheDocument()
    expect(screen.getByText('Test/Zone (GMT+01:23)')).toBeInTheDocument()
    expect(screen.getByText(/sessions of 40 minutes that start every 45 minutes/)).toBeInTheDocument()
    expect(screen.getByText(/leaves a 5-minute break/)).toBeInTheDocument()
    const options = within(screen.getByLabelText('Midweek start time')).getAllByRole('option')
    expect(options.map((option) => option.value)).toEqual(['480', '525'])
    expect(options.map((option) => option.textContent)).toEqual(['08:00', '08:45'])
  })

  it('shows the slot count from the API, without calculating its own', async () => {
    // 09:00-17:00 would be 8 slots if the page worked it out, so this proves it doesn't.
    const hours = { day_of_week: 1, start_minute: 540, end_minute: 1020, slot_count: 3 }
    stubProfessional({ 'GET /api/v1/availability': () => availability([hours]) })
    renderAt('/availability')

    expect(await screen.findByText('3 slots')).toBeInTheDocument()
  })

  it('says "1 slot" for a single slot', async () => {
    const hours = { day_of_week: 1, start_minute: 540, end_minute: 600, slot_count: 1 }
    stubProfessional({ 'GET /api/v1/availability': () => availability([hours]) })
    renderAt('/availability')

    expect(await screen.findByText('1 slot')).toBeInTheDocument()
  })

  it('hides the count while a day has unsaved times, and shows it again if they are undone', async () => {
    const hours = { day_of_week: 1, start_minute: 540, end_minute: 1020, slot_count: 8 }
    stubProfessional({ 'GET /api/v1/availability': () => availability([hours]) })
    const { user } = renderAt('/availability')
    await screen.findByText('8 slots')

    await user.selectOptions(screen.getByLabelText('Monday end time'), '12:00')
    expect(screen.queryByText(/slots?$/)).not.toBeInTheDocument()

    await user.selectOptions(screen.getByLabelText('Monday end time'), '17:00')
    expect(screen.getByText('8 slots')).toBeInTheDocument()
  })

  it("shows the server's new count after saving", async () => {
    const hours = { day_of_week: 1, start_minute: 540, end_minute: 1020, slot_count: 8 }
    stubProfessional({
      'GET /api/v1/availability': () => availability([hours]),
      'PUT /api/v1/availability': () => availability([{ ...hours, end_minute: 720, slot_count: 3 }]),
    })
    const { user } = renderAt('/availability')
    await screen.findByText('8 slots')

    await user.selectOptions(screen.getByLabelText('Monday end time'), '12:00')
    await user.click(screen.getByRole('button', { name: 'Save availability' }))

    expect(await screen.findByText('3 slots')).toBeInTheDocument()
  })

  it('has no count for a newly ticked day until it is saved', async () => {
    stubProfessional({ 'GET /api/v1/availability': () => availability([]) })
    const { user } = renderAt('/availability')

    await user.click(await screen.findByLabelText('Monday'))

    expect(screen.queryByText(/slots?$/)).not.toBeInTheDocument()
  })

  it('sends only the ticked days, with the day numbers the API gave', async () => {
    const saved = { day_of_week: 0, start_minute: 540, end_minute: 720 }
    const api = stubProfessional({
      'GET /api/v1/availability': () => availability([monday]),
      'PUT /api/v1/availability': () => availability([{ ...saved, slot_count: 3 }]),
    })
    const { user } = renderAt('/availability')

    await user.click(await screen.findByLabelText('Monday'))
    await user.click(screen.getByLabelText('Sunday'))
    await user.selectOptions(screen.getByLabelText('Sunday end time'), '12:00')
    await user.click(screen.getByRole('button', { name: 'Save availability' }))

    expect(await screen.findByText('Your availability is saved.')).toBeInTheDocument()
    expect(api.requestTo('PUT /api/v1/availability').body).toEqual({ working_hours: [saved] })
  })

  it('can save a week with no working days', async () => {
    const api = stubProfessional({
      'GET /api/v1/availability': () => availability([monday]),
      'PUT /api/v1/availability': () => availability([]),
    })
    const { user } = renderAt('/availability')

    await user.click(await screen.findByLabelText('Monday'))
    await user.click(screen.getByRole('button', { name: 'Save availability' }))

    await screen.findByText('Your availability is saved.')
    expect(api.requestTo('PUT /api/v1/availability').body).toEqual({ working_hours: [] })
  })

  it("keeps a day's times when it is unticked and ticked again", async () => {
    stubProfessional({ 'GET /api/v1/availability': () => availability([monday]) })
    const { user } = renderAt('/availability')

    await user.click(await screen.findByLabelText('Monday'))
    await user.click(screen.getByLabelText('Monday'))

    expect(screen.getByLabelText('Monday start time')).toHaveValue('600')
  })

  it('removes the saved message after the next edit', async () => {
    stubProfessional({
      'GET /api/v1/availability': () => availability([monday]),
      'PUT /api/v1/availability': () => availability([monday]),
    })
    const { user } = renderAt('/availability')

    await user.click(await screen.findByRole('button', { name: 'Save availability' }))
    await screen.findByText('Your availability is saved.')
    await user.click(screen.getByLabelText('Tuesday'))

    expect(screen.queryByText('Your availability is saved.')).not.toBeInTheDocument()
  })

  it('shows the API validation errors and keeps what was selected', async () => {
    const message = 'Monday: End time must be at least 50 minutes after the start time'
    stubProfessional({
      'GET /api/v1/availability': () => availability([monday]),
      'PUT /api/v1/availability': () => json(422, { errors: { working_hours: [message] } }),
    })
    const { user } = renderAt('/availability')

    await user.selectOptions(await screen.findByLabelText('Monday end time'), '10:30')
    await user.click(screen.getByRole('button', { name: 'Save availability' }))

    expect(await screen.findByText(message)).toBeInTheDocument()
    expect(screen.getByLabelText('Monday end time')).toHaveValue('630')
  })

  it('offers a retry when the hours fail to load', async () => {
    let respond = () => json(500, {})
    stubProfessional({ 'GET /api/v1/availability': () => respond() })
    const { user } = renderAt('/availability')

    const retry = await screen.findByRole('button', { name: 'Try again' })
    respond = () => availability([monday])
    await user.click(retry)

    expect(await screen.findByLabelText('Monday')).toBeChecked()
  })
})

describe('find a professional', () => {
  const alex = { id: 2, name: 'Alex Professional', timezone: 'Asia/Singapore' }
  const zoe = { id: 3, name: 'Zoe Professional', timezone: 'Europe/London' }

  function stubMember(routes) {
    return stubApi({ 'GET /api/v1/me': () => json(200, { user: member }), ...routes })
  }

  it('links to the page from the navbar, for a member', async () => {
    stubMember({ 'GET /api/v1/professionals': () => json(200, { professionals: [] }) })
    const { user } = renderAt('/')

    await user.click(await screen.findByRole('link', { name: 'Find a professional' }))

    expect(await screen.findByRole('heading', { name: 'Find a professional' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Find a professional' })).toHaveAttribute('aria-current', 'page')
  })

  it('keeps a professional away from the page, with no link to it', async () => {
    const api = stubApi({ 'GET /api/v1/me': () => json(200, { user: professional }) })
    renderAt('/professionals')

    expect(await screen.findByRole('heading', { name: 'Welcome, Pat Professional' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Find a professional' })).not.toBeInTheDocument()
    expect(api.requests.map((request) => request.key)).not.toContain('GET /api/v1/professionals')
  })

  it('lists the professionals in the order the API sends them', async () => {
    stubMember({ 'GET /api/v1/professionals': () => json(200, { professionals: [zoe, alex] }) })
    renderAt('/professionals')

    const items = within(await screen.findByRole('list', { name: 'Professionals' })).getAllByRole('listitem')

    expect(items.map((item) => item.textContent)).toEqual([
      'Zoe ProfessionalEurope/London',
      'Alex ProfessionalAsia/Singapore',
    ])
  })

  it('says so when there are no professionals', async () => {
    stubMember({ 'GET /api/v1/professionals': () => json(200, { professionals: [] }) })
    renderAt('/professionals')

    expect(await screen.findByText(/There are no professionals to book yet/)).toBeInTheDocument()
    expect(screen.queryByRole('list', { name: 'Professionals' })).not.toBeInTheDocument()
  })

  it('offers a retry when the list fails to load', async () => {
    let respond = () => json(500, {})
    stubMember({ 'GET /api/v1/professionals': () => respond() })
    const { user } = renderAt('/professionals')

    const retry = await screen.findByRole('button', { name: 'Try again' })
    respond = () => json(200, { professionals: [alex] })
    await user.click(retry)

    expect(await screen.findByText('Alex Professional')).toBeInTheDocument()
  })
})
