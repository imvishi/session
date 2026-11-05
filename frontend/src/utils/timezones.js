export function browserTimezone() {
  return Intl.DateTimeFormat().resolvedOptions().timeZone
}

/** The browser's own timezone isn't always in its list (UTC often isn't), so it's added. */
export function timezoneOptions() {
  return [...new Set([...Intl.supportedValuesOf('timeZone'), browserTimezone()])].sort()
}
