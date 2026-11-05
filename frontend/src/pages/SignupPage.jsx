import {
  Alert,
  Autocomplete,
  Button,
  FormControl,
  FormHelperText,
  FormLabel,
  Link,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material'
import { useMemo, useState } from 'react'
import { Link as RouterLink } from 'react-router-dom'
import { useSignupMutation } from '../api/usersApi'
import { errorMessage, fieldErrors } from '../api/errors'
import { browserTimezone, timezoneOptions } from '../utils/timezones'
import { AuthLayout } from './AuthLayout'

export function SignupPage() {
  const [signup, { error, isLoading }] = useSignupMutation()
  const timezones = useMemo(() => timezoneOptions(), [])
  const [role, setRole] = useState('member')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [timezone, setTimezone] = useState(browserTimezone)

  const errorsByField = fieldErrors(error)
  const hasFieldErrors = Object.keys(errorsByField).length > 0

  function handleSubmit(event) {
    event.preventDefault()
    // On success the current user is set, and the route redirects away from this page.
    signup({ name, email, password, role, timezone })
  }

  /** Turns the API's "has already been taken" into "Email has already been taken". */
  function fieldError(field, label) {
    const messages = errorsByField[field]
    return messages ? `${label} ${messages.join(', ')}` : undefined
  }

  const nameError = fieldError('name', 'Name')
  const emailError = fieldError('email', 'Email')
  const passwordError = fieldError('password', 'Password')
  const timezoneError = fieldError('timezone', 'Timezone')
  const roleError = fieldError('role', 'Role')

  return (
    <AuthLayout title="Create your account" subtitle="Book sessions, or offer them as a professional.">
      <form onSubmit={handleSubmit}>
        <Stack spacing={2}>
          {error && !hasFieldErrors && <Alert severity="error">{errorMessage(error)}</Alert>}
          <FormControl error={Boolean(roleError)}>
            <FormLabel id="role-label" sx={{ mb: 1 }}>
              I am a
            </FormLabel>
            <ToggleButtonGroup
              aria-labelledby="role-label"
              color="primary"
              exclusive
              fullWidth
              size="small"
              value={role}
              // MUI passes null when the selected button is clicked again. A role is always required.
              onChange={(_event, value) => value && setRole(value)}
            >
              <ToggleButton value="member">Member</ToggleButton>
              <ToggleButton value="professional">Professional</ToggleButton>
            </ToggleButtonGroup>
            {roleError && <FormHelperText>{roleError}</FormHelperText>}
          </FormControl>
          <TextField
            label="Full name"
            autoComplete="name"
            required
            value={name}
            onChange={(event) => setName(event.target.value)}
            error={Boolean(nameError)}
            helperText={nameError}
          />
          <TextField
            label="Email"
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            error={Boolean(emailError)}
            helperText={emailError}
          />
          <TextField
            label="Password"
            type="password"
            autoComplete="new-password"
            required
            slotProps={{ htmlInput: { minLength: 8, maxLength: 72 } }}
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            error={Boolean(passwordError)}
            helperText={passwordError ?? 'At least 8 characters'}
          />
          <Autocomplete
            options={timezones}
            disableClearable
            value={timezone}
            onChange={(_event, value) => setTimezone(value)}
            renderInput={(params) => (
              <TextField
                {...params}
                label="Timezone"
                required
                error={Boolean(timezoneError)}
                helperText={timezoneError ?? 'Session times are shown in this timezone'}
              />
            )}
          />
          <Button type="submit" variant="contained" size="large" disabled={isLoading}>
            {isLoading ? 'Creating account…' : 'Create account'}
          </Button>
          <Typography variant="body2" align="center">
            Already have an account?{' '}
            <Link component={RouterLink} to="/login">
              Log in
            </Link>
          </Typography>
        </Stack>
      </form>
    </AuthLayout>
  )
}
