import {
  Alert,
  Button,
  CircularProgress,
  Container,
  List,
  ListItem,
  ListItemText,
  Paper,
  Stack,
  Typography,
} from '@mui/material'
import { errorMessage } from '../api/errors'
import { useGetNotificationsQuery, useReadAllNotificationsMutation } from '../api/notificationsApi'

export function NotificationsPage() {
  // The navbar keeps this query cached, so refetch on opening the page to show newly delivered ones.
  const { data, error, isLoading, refetch } = useGetNotificationsQuery(undefined, { refetchOnMountOrArgChange: true })
  const [readAll, readAllState] = useReadAllNotificationsMutation()

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Stack direction="row" sx={{ alignItems: 'center', justifyContent: 'space-between' }}>
          <Typography variant="h5" component="h1" sx={{ fontWeight: 600 }}>
            Notifications
          </Typography>
          {data?.unread_count > 0 && (
            <Button disabled={readAllState.isLoading} onClick={() => readAll(data.notifications[0]?.delivered_at)}>
              Mark all as read
            </Button>
          )}
        </Stack>
        {readAllState.error && <Alert severity="error">{errorMessage(readAllState.error)}</Alert>}
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
        {data?.notifications.length === 0 && (
          <Typography sx={{ color: 'text.secondary' }}>
            You have no notifications yet. Reminders arrive 24 hours and 1 hour before each session.
          </Typography>
        )}
        {data?.notifications.length > 0 && (
          <Paper variant="outlined">
            <List disablePadding aria-label="Notifications">
              {data.notifications.map((notification, index) => (
                <ListItem
                  key={notification.id}
                  divider={index < data.notifications.length - 1}
                  sx={{ bgcolor: notification.read ? undefined : 'action.hover' }}
                >
                  <ListItemText
                    primary={notification.message}
                    secondary={notification.read ? notification.delivered_label : `${notification.delivered_label} · New`}
                    slotProps={{ primary: { sx: { fontWeight: notification.read ? 400 : 600 } } }}
                  />
                </ListItem>
              ))}
            </List>
          </Paper>
        )}
      </Stack>
    </Container>
  )
}
