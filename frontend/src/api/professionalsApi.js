import { baseApi } from './baseApi'
import { API_URLS } from './urls'

const professionalsApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    getProfessionals: builder.query({
      query: () => API_URLS.professionals,
      transformResponse: (response) => response.professionals,
    }),

    getProfessionalCalendar: builder.query({
      query: (id) => API_URLS.professional(id),
      providesTags: ['ProfessionalCalendar'],
    }),
  }),
})

export const { useGetProfessionalsQuery, useGetProfessionalCalendarQuery } = professionalsApi
