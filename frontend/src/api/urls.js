export const API_BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000'

export const API_URLS = {
  me: '/api/v1/me',
  login: '/api/v1/auth/login',
  signup: '/api/v1/auth/signup',
  logout: '/api/v1/auth/logout',
  availability: '/api/v1/availability',
  professionals: '/api/v1/professionals',
  professional: (id) => `/api/v1/professionals/${id}`,
  appointments: '/api/v1/appointments',
}
