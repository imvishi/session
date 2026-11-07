import { baseApi } from './baseApi'
import { API_URLS } from './urls'

// Each change refreshes the sessions and the calendar, after a failure too, because that means they were out of date.
const CHANGED = ['ProfessionalCalendar', 'MySessions']

const appointmentsApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    // The logged-in person's own sessions: upcoming and past for a member, upcoming for a professional.
    getMySessions: builder.query({
      query: () => API_URLS.appointments,
      providesTags: ['MySessions'],
    }),

    createAppointment: builder.mutation({
      query: (appointment) => ({ url: API_URLS.appointments, method: 'POST', body: appointment }),
      invalidatesTags: CHANGED,
    }),

    cancelAppointment: builder.mutation({
      query: (id) => ({ url: API_URLS.cancelAppointment(id), method: 'POST' }),
      invalidatesTags: CHANGED,
    }),

    // slot is the new time, exactly as the calendar gave it.
    rescheduleAppointment: builder.mutation({
      query: ({ id, ...slot }) => ({ url: API_URLS.rescheduleAppointment(id), method: 'POST', body: slot }),
      invalidatesTags: CHANGED,
    }),
  }),
})

export const {
  useGetMySessionsQuery,
  useCreateAppointmentMutation,
  useCancelAppointmentMutation,
  useRescheduleAppointmentMutation,
} = appointmentsApi
