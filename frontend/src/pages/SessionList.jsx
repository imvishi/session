import {
  Alert,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  List,
  ListItem,
  ListItemText,
  Paper,
  Stack,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { Link as RouterLink } from 'react-router-dom'
import { useCancelAppointmentMutation } from '../api/appointmentsApi'
import { errorMessage } from '../api/errors'

function CancelDialog({ session, withName, onClose }) {
  const [cancel, { isLoading }] = useCancelAppointmentMutation()

  async function confirm() {
    try {
      await cancel(session.id).unwrap()
      onClose(null)
    } catch (error) {
      onClose(errorMessage(error))
    }
  }

  return (
    <Dialog open onClose={() => !isLoading && onClose(null)} aria-labelledby="cancel-title">
      <DialogTitle id="cancel-title">Cancel this session?</DialogTitle>
      <DialogContent>
        <DialogContentText>
          {session.date_label}, {session.time_label}, with {withName(session)}.
        </DialogContentText>
      </DialogContent>
      <DialogActions>
        <Button disabled={isLoading} onClick={() => onClose(null)}>
          Keep it
        </Button>
        <Button color="error" variant="contained" disabled={isLoading} onClick={confirm}>
          {isLoading ? 'Cancelling…' : 'Cancel session'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}

function SessionActions({ session, onCancel }) {
  if (session.notice) {
    return <Typography variant="body2" sx={{ color: 'text.secondary' }}>{session.notice}</Typography>
  }

  return (
    <Stack direction="row" spacing={1}>
      {session.can_reschedule && (
        <Button
          size="small"
          component={RouterLink}
          to={`/professionals/${session.professional.id}/reschedule/${session.id}`}
        >
          Reschedule
        </Button>
      )}
      {session.can_cancel && (
        <Button size="small" color="error" onClick={onCancel}>
          Cancel
        </Button>
      )}
    </Stack>
  )
}

/** One heading and its sessions. withName gives who each session is with. */
export function SessionList({ title, sessions, emptyText, withName }) {
  const [cancelling, setCancelling] = useState(null)
  const [error, setError] = useState(null)

  function closeDialog(message) {
    setCancelling(null)
    setError(message)
  }

  return (
    <Stack spacing={1}>
      <Typography component="h2" variant="h6">
        {title}
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}
      {sessions.length === 0 ? (
        <Typography sx={{ color: 'text.secondary' }}>{emptyText}</Typography>
      ) : (
        <Paper variant="outlined">
          <List disablePadding aria-label={title}>
            {sessions.map((session, index) => (
              <ListItem
                key={session.id}
                divider={index < sessions.length - 1}
                sx={{ flexWrap: 'wrap', gap: 1 }}
              >
                <ListItemText
                  primary={`${session.date_label}, ${session.time_label}`}
                  secondary={`With ${withName(session)}`}
                />
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  {session.status === 'cancelled' && <Chip label="Cancelled" size="small" />}
                  <SessionActions session={session} onCancel={() => setCancelling(session)} />
                </Box>
              </ListItem>
            ))}
          </List>
        </Paper>
      )}
      {cancelling && <CancelDialog session={cancelling} withName={withName} onClose={closeDialog} />}
    </Stack>
  )
}
