import { Alert, Button, Link, Stack, TextField, Typography } from '@mui/material'
import { useState } from 'react'
import { Link as RouterLink } from 'react-router-dom'
import { useLoginMutation } from '../api/usersApi'
import { errorMessage } from '../api/errors'
import { AuthLayout } from './AuthLayout'

export function LoginPage() {
  const [login, { error, isLoading }] = useLoginMutation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  function handleSubmit(event) {
    event.preventDefault()
    // On success the current user is set, and the route redirects away from this page.
    login({ email, password })
  }

  return (
    <AuthLayout title="Log in" subtitle="Welcome back. Log in to manage your sessions.">
      <form onSubmit={handleSubmit}>
        <Stack spacing={2}>
          {error && <Alert severity="error">{errorMessage(error)}</Alert>}
          <TextField
            label="Email"
            type="email"
            autoComplete="email"
            required
            autoFocus
            value={email}
            onChange={(event) => setEmail(event.target.value)}
          />
          <TextField
            label="Password"
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          <Button type="submit" variant="contained" size="large" disabled={isLoading}>
            {isLoading ? 'Logging in…' : 'Log in'}
          </Button>
          <Typography variant="body2" align="center">
            New here?{' '}
            <Link component={RouterLink} to="/signup">
              Create an account
            </Link>
          </Typography>
        </Stack>
      </form>
    </AuthLayout>
  )
}
