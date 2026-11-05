import { SessionList } from './SessionList'
import { SessionsPageFrame } from './SessionsPageFrame'

const memberName = (session) => session.member.name

export function SchedulePage() {
  return (
    <SessionsPageFrame title="Schedule">
      {({ upcoming }) => (
        <SessionList title="Upcoming" sessions={upcoming} emptyText="You have no upcoming sessions." withName={memberName} />
      )}
    </SessionsPageFrame>
  )
}
