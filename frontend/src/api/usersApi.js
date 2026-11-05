import { baseApi, clearLoggedInState, setCurrentUser } from './baseApi'
import { API_URLS } from './urls'

async function setCurrentUserOnSuccess(_arg, { dispatch, queryFulfilled }) {
  try {
    const { data } = await queryFulfilled
    setCurrentUser(dispatch, data)
  } catch {
    // The page shows the error from the mutation hook.
  }
}

const usersApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    getMe: builder.query({
      queryFn: async (_arg, _queryApi, _extraOptions, baseQuery) => {
        const result = await baseQuery(API_URLS.me)
        return { data: result.error ? null : result.data.user }
      },
    }),

    login: builder.mutation({
      query: (credentials) => ({ url: API_URLS.login, method: 'POST', body: { user: credentials } }),
      transformResponse: (response) => response.user,
      onQueryStarted: setCurrentUserOnSuccess,
    }),

    signup: builder.mutation({
      query: (details) => ({ url: API_URLS.signup, method: 'POST', body: { user: details } }),
      transformResponse: (response) => response.user,
      onQueryStarted: setCurrentUserOnSuccess,
    }),

    logout: builder.mutation({
      query: () => ({ url: API_URLS.logout, method: 'DELETE' }),
      onQueryStarted: async (_arg, { dispatch, queryFulfilled }) => {
        try {
          await queryFulfilled
          clearLoggedInState(dispatch)
        } catch {
          // Still logged in. The page shows the error from the mutation hook.
        }
      },
    }),
  }),
})

export const { useGetMeQuery, useLoginMutation, useSignupMutation, useLogoutMutation } = usersApi

/** undefined while the first check is in flight, null when logged out. */
export function useCurrentUser() {
  return useGetMeQuery().data
}
