import {
  Alert,
  Button,
  CircularProgress,
  Container,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  Paper,
  Stack,
  Typography,
} from '@mui/material'
import { Link as RouterLink } from 'react-router-dom'
import { errorMessage } from '../api/errors'
import { useGetProfessionalsQuery } from '../api/professionalsApi'

export function FindProfessionalPage() {
  const { data: professionals, error, isLoading, refetch } = useGetProfessionalsQuery()

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Typography variant="h5" component="h1" sx={{ fontWeight: 600 }}>
          Find a professional
        </Typography>
        {isLoading && <CircularProgress aria-label="Loading" sx={{ alignSelf: 'center' }} />}
        {error && !professionals && (
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
        {professionals?.length === 0 && (
          <Typography sx={{ color: 'text.secondary' }}>There are no professionals to book yet. Please check back soon.</Typography>
        )}
        {professionals?.length > 0 && (
          <Paper variant="outlined">
            <List disablePadding aria-label="Professionals">
              {professionals.map((professional, index) => (
                <ListItem key={professional.id} divider={index < professionals.length - 1} disablePadding>
                  <ListItemButton component={RouterLink} to={`/professionals/${professional.id}`}>
                    <ListItemText primary={professional.name} secondary={professional.timezone} />
                  </ListItemButton>
                </ListItem>
              ))}
            </List>
          </Paper>
        )}
      </Stack>
    </Container>
  )
}
