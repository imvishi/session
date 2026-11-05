import { baseApi } from './baseApi'
import { API_URLS } from './urls'

const availabilityApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    getAvailability: builder.query({
      query: () => API_URLS.availability,
    }),

    // Replaces the whole week. A day left out of the list is a day off.
    updateAvailability: builder.mutation({
      query: (workingHours) => ({
        url: API_URLS.availability,
        method: 'PUT',
        body: { working_hours: workingHours },
      }),
      onQueryStarted: async (_arg, { dispatch, queryFulfilled }) => {
        try {
          const { data } = await queryFulfilled
          dispatch(baseApi.util.upsertQueryEntries([{ endpointName: 'getAvailability', arg: undefined, value: data }]))
        } catch {
          // The page shows the error from the mutation hook.
        }
      },
    }),
  }),
})

export const { useGetAvailabilityQuery, useUpdateAvailabilityMutation } = availabilityApi
