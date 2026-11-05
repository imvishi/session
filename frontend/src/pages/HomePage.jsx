import { Container, Stack, Typography } from '@mui/material'
import { useCurrentUser } from '../api/usersApi'

export function HomePage() {
  const user = useCurrentUser()

  if (!user) return null

  return (
    <Container maxWidth="sm" sx={{ py: 6 }}>
      <Stack spacing={2} sx={{ alignItems: 'flex-start' }}>
        <Typography variant="h5" component="h1">
          Welcome, {user.name}
        </Typography>
        <Typography sx={{ color: 'text.secondary' }}>
          You're logged in as a {user.role}. Your timezone is {user.timezone}.
        </Typography>
      </Stack>
    </Container>
  )
}
