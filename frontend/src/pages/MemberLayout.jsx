import { AppLayout } from './AppLayout'

const LINKS = [
  { to: '/professionals', label: 'Find a professional' },
  { to: '/sessions', label: 'My sessions' },
]

export function MemberLayout() {
  return <AppLayout links={LINKS} />
}
