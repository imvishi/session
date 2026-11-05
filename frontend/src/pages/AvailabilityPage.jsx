import {
  Alert,
  Box,
  Button,
  Checkbox,
  CircularProgress,
  Container,
  FormControlLabel,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useState } from 'react'
import { useGetAvailabilityQuery, useUpdateAvailabilityMutation } from '../api/availabilityApi'
import { errorMessage, fieldErrors } from '../api/errors'

function TimeSelect({ label, value, options, disabled, onChange }) {
  return (
    <TextField
      select
      size="small"
      value={value}
      disabled={disabled}
      onChange={(event) => onChange(Number(event.target.value))}
      sx={{ width: 120 }}
      slotProps={{
        select: { native: true },
        htmlInput: { 'aria-label': label },
      }}
    >
      {options.map((option) => (
        <option key={option.value} value={option.value}>
          {option.label}
        </option>
      ))}
    </TextField>
  )
}

function DayRow({ day, saved, timeOptions, onChange }) {
  // The count describes the saved times, so it's hidden while this row shows different ones.
  const showsSavedTimes = day.start_minute === saved.start_minute && day.end_minute === saved.end_minute
  const slots = day.working && showsSavedTimes ? saved.slot_count : null

  return (
    <Box sx={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', columnGap: 1.5, rowGap: 0.5 }}>
      <FormControlLabel
        label={day.name}
        sx={{ width: 150, mr: 0 }}
        control={<Checkbox checked={day.working} onChange={(event) => onChange({ working: event.target.checked })} />}
      />
      <Box sx={{ display: 'flex', alignItems: 'center', columnGap: 1.5 }}>
        <TimeSelect
          label={`${day.name} start time`}
          value={day.start_minute}
          options={timeOptions}
          disabled={!day.working}
          onChange={(start_minute) => onChange({ start_minute })}
        />
        <Typography sx={{ color: 'text.secondary' }}>to</Typography>
        <TimeSelect
          label={`${day.name} end time`}
          value={day.end_minute}
          options={timeOptions}
          disabled={!day.working}
          onChange={(end_minute) => onChange({ end_minute })}
        />
      </Box>
      {slots !== null && (
        <Typography variant="body2" sx={{ color: 'text.secondary' }}>
          {slots} {slots === 1 ? 'slot' : 'slots'}
        </Typography>
      )}
    </Box>
  )
}

function WeekForm({ availability }) {
  const [save, { error, isLoading, isSuccess, reset }] = useUpdateAvailabilityMutation()
  const [days, setDays] = useState(availability.days)

  const errors = error ? (fieldErrors(error).working_hours ?? [errorMessage(error)]) : []

  function changeDay(index, changes) {
    setDays((current) => current.map((day, i) => (i === index ? { ...day, ...changes } : day)))
    // The last save's message no longer describes what's on screen.
    reset()
  }

  function handleSubmit(event) {
    event.preventDefault()
    save(
      days
        .filter((day) => day.working)
        .map(({ day_of_week, start_minute, end_minute }) => ({ day_of_week, start_minute, end_minute })),
    )
  }

  return (
    <form onSubmit={handleSubmit}>
      <Stack spacing={1.5} sx={{ alignItems: 'flex-start' }}>
        {days.map((day, index) => (
          <DayRow
            key={day.day_of_week}
            day={day}
            saved={availability.days[index]}
            timeOptions={availability.time_options}
            onChange={(changes) => changeDay(index, changes)}
          />
        ))}
        {errors.length > 0 && (
          <Alert severity="error" sx={{ alignSelf: 'stretch' }}>
            {errors.map((message) => (
              <div key={message}>{message}</div>
            ))}
          </Alert>
        )}
        {isSuccess && (
          <Alert severity="success" sx={{ alignSelf: 'stretch' }}>
            Your availability is saved.
          </Alert>
        )}
        <Button type="submit" variant="contained" size="large" disabled={isLoading}>
          {isLoading ? 'Saving…' : 'Save availability'}
        </Button>
      </Stack>
    </form>
  )
}

export function AvailabilityPage() {
  const { data, error, isLoading, refetch } = useGetAvailabilityQuery()

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Typography variant="h5" component="h1" sx={{ fontWeight: 600 }}>
          Availability
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
              Set your weekly hours in your own time zone (<strong>{data.timezone_label}</strong>). Members book sessions
              of {data.session_minutes} minutes that start every {data.slot_interval_minutes} minutes from your start
              time, which leaves a {data.break_minutes}-minute break between sessions.
            </Typography>
            <Paper variant="outlined" sx={{ p: { xs: 2, sm: 3 } }}>
              <WeekForm availability={data} />
            </Paper>
          </>
        )}
      </Stack>
    </Container>
  )
}
