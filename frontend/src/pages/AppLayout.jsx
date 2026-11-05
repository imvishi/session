import { Alert, AppBar, Box, Button, Container, Link, Toolbar } from '@mui/material'
import { Outlet, NavLink, Link as RouterLink } from 'react-router-dom'
import { errorMessage } from '../api/errors'
import { useLogoutMutation } from '../api/usersApi'

const activeLinkStyle = {
  '&.active': { color: 'text.primary', bgcolor: 'action.selected' },
}

/** The navbar and page area shared by each role's layout, which chooses the links. */
export function AppLayout({ links }) {
  const [logout, { error, isLoading }] = useLogoutMutation()

  return (
    <>
      <AppBar
        position="sticky"
        color="inherit"
        elevation={0}
        sx={{ borderBottom: 1, borderColor: 'divider' }}
      >
        <Container maxWidth="md" disableGutters>
          <Toolbar component="nav" aria-label="Main" sx={{ gap: 1.5 }}>
            <Link component={RouterLink} to="/" variant="h6" underline="none" sx={{ fontWeight: 600 }}>
              ThoughtFull
            </Link>
            {links.map(({ to, label }) => (
              <Button
                key={to}
                component={NavLink}
                to={to}
                size="large"
                sx={{ color: 'text.secondary', fontWeight: 500, ...activeLinkStyle }}
              >
                {label}
              </Button>
            ))}
            <Box sx={{ flexGrow: 1 }} />
            <Button color="inherit" disabled={isLoading} onClick={() => logout()}>
              Log out
            </Button>
          </Toolbar>
        </Container>
      </AppBar>
      {error && (
        <Container maxWidth="md" sx={{ pt: 2 }}>
          <Alert severity="error">{errorMessage(error)}</Alert>
        </Container>
      )}
      <Outlet />
    </>
  )
}
