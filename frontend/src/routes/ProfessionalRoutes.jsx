import { Navigate } from 'react-router-dom'
import { AvailabilityPage } from '../pages/AvailabilityPage'
import { HomePage } from '../pages/HomePage'
import { ProfessionalLayout } from '../pages/ProfessionalLayout'

/** Every page a professional can reach. Anything else, such as /professionals, goes home. */
export const professionalRoutes = [
  {
    element: <ProfessionalLayout />,
    children: [
      { path: '/', element: <HomePage /> },
      { path: '/availability', element: <AvailabilityPage /> },
    ],
  },
  { path: '*', element: <Navigate to="/" replace /> },
]
