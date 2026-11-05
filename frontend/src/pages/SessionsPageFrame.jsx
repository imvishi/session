import { Alert, Button, CircularProgress, Container, Stack, Typography } from '@mui/material'
import { errorMessage } from '../api/errors'
import { useGetMySessionsQuery } from '../api/appointmentsApi'

/** Loads the logged-in person's sessions and gives them to children once they arrive. */
export function SessionsPageFrame({ title, children }) {
  const { data, error, isLoading, refetch } = useGetMySessionsQuery()

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Stack spacing={3}>
        <Typography variant="h5" component="h1" sx={{ fontWeight: 600 }}>
          {title}
        </Typography>
        {isLoading && <CircularProgress aria-label="Loading" sx={{ alignSelf: 'center' }} />}
        {error && !data && (
          <Alert
            severity="error"
            action={
              <Button color="inherit" size="small" onClick={() => refetch()}>
                Try again
              </Button>
            }
          >
            {errorMessage(error)}
          </Alert>
        )}
        {data && (
          <>
            <Typography sx={{ color: 'text.secondary' }}>
              Times are shown in your time zone (<strong>{data.timezone}</strong>).
            </Typography>
            {children(data)}
          </>
        )}
      </Stack>
    </Container>
  )
}
