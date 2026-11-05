import { Alert, Box, Button, CircularProgress, Container, Link, Paper, Stack, Tooltip, Typography } from '@mui/material'
import { useState } from 'react'
import { Link as RouterLink, useParams } from 'react-router-dom'
import { useCreateAppointmentMutation } from '../api/appointmentsApi'
import { errorMessage } from '../api/errors'
import { useGetProfessionalCalendarQuery } from '../api/professionalsApi'

function DayGrid({ weekdays, days, selectedDate, onSelect }) {
  return (
    <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, minmax(0, 1fr))', gap: { xs: 0.5, sm: 1 } }}>
      {weekdays.map((weekday) => (
        <Typography key={weekday} variant="caption" align="center" sx={{ color: 'text.secondary' }}>
          {weekday}
        </Typography>
      ))}
      {days.map((day) => (
        <Button
          key={day.date}
          aria-label={day.label}
          aria-pressed={day.date === selectedDate}
          disabled={day.slots.length === 0}
          variant={day.date === selectedDate ? 'contained' : 'outlined'}
          onClick={() => onSelect(day.date)}
          sx={{ minWidth: 0, px: 0, py: { xs: 0.5, sm: 1 }, fontSize: { xs: 11, sm: 14 }, lineHeight: 1.3 }}
        >
          {day.short_label}
        </Button>
      ))}
    </Box>
  )
}

function TimeList({ day, onSelect }) {
  return (
    <Stack spacing={1}>
      <Typography component="h2" sx={{ fontWeight: 600 }}>
        {day.label}
      </Typography>
      {day.slots.length === 0 && (
        <Typography sx={{ color: 'text.secondary' }}>There are no times left on this day. Please choose another.</Typography>
      )}
      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
        {day.slots.map((slot) => (
          <Tooltip key={`${slot.appointment_date} ${slot.start_at}`} title={`Professional's time: ${slot.professional_label}`} describeChild>
            <Button variant="outlined" onClick={() => onSelect(slot)}>
              {slot.label}
            </Button>
          </Tooltip>
        ))}
      </Box>
    </Stack>
  )
}

function AppointmentDetails({ calendar, choice }) {
  return (
    <Stack spacing={0.5}>
      <Typography>With {calendar.professional.name}</Typography>
      <Typography>
        {choice.day.label} at {choice.slot.label}
      </Typography>
      <Typography sx={{ color: 'text.secondary' }}>
        {calendar.session_minutes} minutes, in your time zone ({calendar.timezone_label})
      </Typography>
      <Typography sx={{ color: 'text.secondary' }}>
        Professional's time: {choice.slot.professional_label}
      </Typography>
    </Stack>
  )
}

function AppointmentFlow({ calendar }) {
  const [book, { error, isLoading, reset }] = useCreateAppointmentMutation()
  const [selectedDate, setSelectedDate] = useState(null)
  const [choice, setChoice] = useState(null)
  const [isBooked, setIsBooked] = useState(false)

  const selectedDay = calendar.days.find((day) => day.date === selectedDate)
  const hasSlots = calendar.days.some((day) => day.slots.length > 0)

  async function confirm() {
    try {
      const { appointment_date, start_at, end_at } = choice.slot
      await book({ professional_id: calendar.professional.id, appointment_date, start_at, end_at }).unwrap()
      setIsBooked(true)
    } catch {
      // Back to the calendar, which refreshes, with the reason shown above it.
      setChoice(null)
    }
  }

  function selectDate(date) {
    reset()
    setSelectedDate(date)
  }

  function bookAnother() {
    setIsBooked(false)
    setChoice(null)
    setSelectedDate(null)
  }

  if (isBooked) {
    return (
      <Stack spacing={2} sx={{ alignItems: 'flex-start' }}>
        <Alert severity="success" sx={{ alignSelf: 'stretch' }}>
          Your appointment is booked.
        </Alert>
        <AppointmentDetails calendar={calendar} choice={choice} />
        <Stack direction="row" spacing={1}>
          <Button variant="contained" component={RouterLink} to="/sessions">
            View my sessions
          </Button>
          <Button variant="outlined" onClick={bookAnother}>
            Book another appointment
          </Button>
        </Stack>
      </Stack>
    )
  }

  if (choice) {
    return (
      <Stack spacing={2} sx={{ alignItems: 'flex-start' }}>
        <Typography component="h2" variant="h6">
          Confirm your appointment
        </Typography>
        <AppointmentDetails calendar={calendar} choice={choice} />
        <Stack direction="row" spacing={1}>
          <Button variant="contained" disabled={isLoading} onClick={confirm}>
            {isLoading ? 'Confirming…' : 'Confirm appointment'}
          </Button>
          <Button disabled={isLoading} onClick={() => setChoice(null)}>
            Go back
          </Button>
        </Stack>
      </Stack>
    )
  }

  return (
    <Stack spacing={2.5}>
      {error && <Alert severity="error">{errorMessage(error)}</Alert>}
      {hasSlots ? (
        <>
          <Typography sx={{ color: 'text.secondary' }}>Choose a date, then a time.</Typography>
          <DayGrid weekdays={calendar.weekdays} days={calendar.days} selectedDate={selectedDate} onSelect={selectDate} />
          {selectedDay && <TimeList day={selectedDay} onSelect={(slot) => setChoice({ day: selectedDay, slot })} />}
        </>
      ) : (
        <Typography sx={{ color: 'text.secondary' }}>There are no times available in the next 4 weeks.</Typography>
      )}
    </Stack>
  )
}

export function ProfessionalProfilePage() {
  const { id } = useParams()
  const { data: calendar, error, isLoading, refetch } = useGetProfessionalCalendarQuery(id)

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Link component={RouterLink} to="/professionals" variant="body2">
          All professionals
        </Link>
        {isLoading && <CircularProgress aria-label="Loading" sx={{ alignSelf: 'center' }} />}
        {error && !calendar && (
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
        {calendar && (
          <>
            <Typography variant="h5" component="h1" sx={{ fontWeight: 600 }}>
              {calendar.professional.name}
            </Typography>
            <Typography sx={{ color: 'text.secondary' }}>
              Times are shown in your time zone (<strong>{calendar.timezone_label}</strong>).
            </Typography>
            <Paper variant="outlined" sx={{ p: { xs: 2, sm: 3 } }}>
              <AppointmentFlow calendar={calendar} />
            </Paper>
          </>
        )}
      </Stack>
    </Container>
  )
}
