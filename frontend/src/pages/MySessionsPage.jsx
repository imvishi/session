import { SessionList } from './SessionList'
import { SessionsPageFrame } from './SessionsPageFrame'

const professionalName = (session) => session.professional.name

export function MySessionsPage() {
  return (
    <SessionsPageFrame title="My sessions">
      {({ upcoming, past }) => (
        <>
          <SessionList title="Upcoming" sessions={upcoming} emptyText="You have no upcoming sessions." withName={professionalName} />
          <SessionList title="Past" sessions={past} emptyText="You have no past sessions." withName={professionalName} />
        </>
      )}
    </SessionsPageFrame>
  )
}
