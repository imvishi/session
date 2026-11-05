import { Box, Container, Paper, Typography } from '@mui/material'

export function AuthLayout({ title, subtitle, children }) {
  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', py: 4 }}>
      <Container maxWidth="xs">
        <Paper variant="outlined" sx={{ p: { xs: 3, sm: 4 } }}>
          <Typography variant="h5" component="h1" gutterBottom>
            {title}
          </Typography>
          <Typography sx={{ color: 'text.secondary', mb: 3 }}>
            {subtitle}
          </Typography>
          {children}
        </Paper>
      </Container>
    </Box>
  )
}
