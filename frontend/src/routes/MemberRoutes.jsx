import { Navigate } from 'react-router-dom'
import { FindProfessionalPage } from '../pages/FindProfessionalPage'
import { HomePage } from '../pages/HomePage'
import { MemberLayout } from '../pages/MemberLayout'

/** Every page a member can reach. Anything else, such as /availability, goes home. */
export const memberRoutes = [
  {
    element: <MemberLayout />,
    children: [
      { path: '/', element: <HomePage /> },
      { path: '/professionals', element: <FindProfessionalPage /> },
    ],
  },
  { path: '*', element: <Navigate to="/" replace /> },
]
