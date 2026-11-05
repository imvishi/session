import { AppLayout } from './AppLayout'

const LINKS = [
  { to: '/schedule', label: 'Schedule' },
  { to: '/availability', label: 'Availability' },
]

export function ProfessionalLayout() {
  return <AppLayout links={LINKS} />
}
