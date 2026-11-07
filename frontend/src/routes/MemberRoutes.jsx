import { Navigate } from 'react-router-dom'
import { FindProfessionalPage } from '../pages/FindProfessionalPage'
import { HomePage } from '../pages/HomePage'
import { MemberLayout } from '../pages/MemberLayout'
import { MySessionsPage } from '../pages/MySessionsPage'
import { ProfessionalProfilePage } from '../pages/ProfessionalProfilePage'

/** Every page a member can reach. Anything else, such as /availability, goes home. */
export const memberRoutes = [
  {
    element: <MemberLayout />,
    children: [
      { path: '/', element: <HomePage /> },
      { path: '/professionals', element: <FindProfessionalPage /> },
      { path: '/professionals/:id', element: <ProfessionalProfilePage /> },
      { path: '/professionals/:id/reschedule/:appointmentId', element: <ProfessionalProfilePage /> },
      { path: '/sessions', element: <MySessionsPage /> },
    ],
  },
  { path: '*', element: <Navigate to="/" replace /> },
]
