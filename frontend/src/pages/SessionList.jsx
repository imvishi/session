import { Chip, List, ListItem, ListItemText, Paper, Stack, Typography } from '@mui/material'

/** One heading and its sessions. withName gives who each session is with. */
export function SessionList({ title, sessions, emptyText, withName }) {
  return (
    <Stack spacing={1}>
      <Typography component="h2" variant="h6">
        {title}
      </Typography>
      {sessions.length === 0 ? (
        <Typography sx={{ color: 'text.secondary' }}>{emptyText}</Typography>
      ) : (
        <Paper variant="outlined">
          <List disablePadding aria-label={title}>
            {sessions.map((session, index) => (
              <ListItem key={session.id} divider={index < sessions.length - 1}>
                <ListItemText
                  primary={`${session.date_label}, ${session.time_label}`}
                  secondary={`With ${withName(session)}`}
                />
                {session.status === 'cancelled' && <Chip label="Cancelled" size="small" />}
              </ListItem>
            ))}
          </List>
        </Paper>
      )}
    </Stack>
  )
}
