import { Navigate } from 'react-router-dom'
import { LoginPage } from '../pages/LoginPage'
import { SignupPage } from '../pages/SignupPage'

/** Every page a logged-out visitor can reach. Anything else goes to the login page. */
export const publicRoutes = [
  { path: '/login', element: <LoginPage /> },
  { path: '/signup', element: <SignupPage /> },
  { path: '*', element: <Navigate to="/login" replace /> },
]
