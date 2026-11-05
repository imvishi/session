import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react'
import { API_BASE_URL } from './urls'

const fetchWithCookie = fetchBaseQuery({
  baseUrl: API_BASE_URL,
  credentials: 'include',
  headers: { Accept: 'application/json' },
})

async function fetchHandlingExpiredLogin(args, queryApi, extraOptions) {
  const result = await fetchWithCookie(args, queryApi, extraOptions)

  if (result.error?.status === 401) {
    // getMe is added to this same api object by usersApi.js.
    const currentUser = baseApi.endpoints.getMe.select()(queryApi.getState()).data
    if (currentUser) clearLoggedInState(queryApi.dispatch)
  }

  return result
}

/** Each feature adds its own endpoints to this, in its own file, using injectEndpoints. */
export const baseApi = createApi({
  baseQuery: fetchHandlingExpiredLogin,
  tagTypes: ['ProfessionalCalendar', 'MySessions'],
  endpoints: () => ({}),
})

export function setCurrentUser(dispatch, user) {
  dispatch(baseApi.util.upsertQueryEntries([{ endpointName: 'getMe', arg: undefined, value: user }]))
}

// Empties the whole cache, so that one person's sessions and notifications can
// never be shown to whoever uses this browser next.
export function clearLoggedInState(dispatch) {
  dispatch(baseApi.util.resetApiState())
  setCurrentUser(dispatch, null)
}
