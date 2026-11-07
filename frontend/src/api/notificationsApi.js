import { baseApi } from './baseApi'
import { API_URLS } from './urls'

const notificationsApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    getNotifications: builder.query({
      query: () => API_URLS.notifications,
      providesTags: ['Notifications'],
    }),

    readAllNotifications: builder.mutation({
      // deliveredUntil is the newest delivered_at shown, so a reminder that arrived since stays unread.
      query: (deliveredUntil) => ({
        url: API_URLS.readAllNotifications,
        method: 'POST',
        body: { delivered_until: deliveredUntil },
      }),
      invalidatesTags: ['Notifications'],
    }),
  }),
})

export const { useGetNotificationsQuery, useReadAllNotificationsMutation } = notificationsApi
