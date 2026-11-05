import { baseApi } from './baseApi'
import { API_URLS } from './urls'

const appointmentsApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    // The logged-in person's own sessions: upcoming and past for a member, upcoming for a professional.
    getMySessions: builder.query({
      query: () => API_URLS.appointments,
      providesTags: ['MySessions'],
    }),

    // Refreshes the calendar after a failure too, because that means it was out of date.
    createAppointment: builder.mutation({
      query: (appointment) => ({ url: API_URLS.appointments, method: 'POST', body: appointment }),
      invalidatesTags: ['ProfessionalCalendar', 'MySessions'],
    }),
  }),
})

export const { useGetMySessionsQuery, useCreateAppointmentMutation } = appointmentsApi
