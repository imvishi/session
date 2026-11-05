import { AppLayout } from './AppLayout'

const LINKS = [{ to: '/professionals', label: 'Find a professional' }]

export function MemberLayout() {
  return <AppLayout links={LINKS} />
}
