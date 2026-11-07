import { Navigate } from 'react-router-dom'
import { AvailabilityPage } from '../pages/AvailabilityPage'
import { HomePage } from '../pages/HomePage'
import { NotificationsPage } from '../pages/NotificationsPage'
import { ProfessionalLayout } from '../pages/ProfessionalLayout'
import { SchedulePage } from '../pages/SchedulePage'

/** Every page a professional can reach. Anything else, such as /professionals, goes home. */
export const professionalRoutes = [
  {
    element: <ProfessionalLayout />,
    children: [
      { path: '/', element: <HomePage /> },
      { path: '/notifications', element: <NotificationsPage /> },
      { path: '/schedule', element: <SchedulePage /> },
      { path: '/availability', element: <AvailabilityPage /> },
    ],
  },
  { path: '*', element: <Navigate to="/" replace /> },
]
