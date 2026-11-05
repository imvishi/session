import { baseApi } from './baseApi'
import { API_URLS } from './urls'

const professionalsApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    getProfessionals: builder.query({
      query: () => API_URLS.professionals,
      transformResponse: (response) => response.professionals,
    }),
  }),
})

export const { useGetProfessionalsQuery } = professionalsApi
