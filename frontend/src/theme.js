import { createTheme } from '@mui/material/styles'

export const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: { main: '#5eb8a5' },
    background: { default: '#14191c', paper: '#1c2327' },
  },
  shape: { borderRadius: 10 },
  typography: {
    button: { textTransform: 'none', fontWeight: 600 },
  },
})
