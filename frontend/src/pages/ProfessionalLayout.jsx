import { AppLayout } from './AppLayout'

const LINKS = [{ to: '/availability', label: 'Availability' }]

export function ProfessionalLayout() {
  return <AppLayout links={LINKS} />
}
