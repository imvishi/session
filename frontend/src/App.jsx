import { Box, CircularProgress } from '@mui/material'
import { useRoutes } from 'react-router-dom'
import { useCurrentUser } from './api/usersApi'
import { memberRoutes } from './routes/MemberRoutes'
import { professionalRoutes } from './routes/ProfessionalRoutes'
import { publicRoutes } from './routes/PublicRoutes'

// This only tidies the UI: the API enforces every role itself.
const ROUTES_BY_ROLE = { member: memberRoutes, professional: professionalRoutes }

export default function App() {
  const user = useCurrentUser()
  const page = useRoutes(user ? ROUTES_BY_ROLE[user.role] : publicRoutes)

  // Waits for the login check, so a page refresh doesn't redirect away from the current URL.
  if (user === undefined) {
    return (
      <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
        <CircularProgress aria-label="Loading" />
      </Box>
    )
  }

  return page
}
