/** A sentence to show the user, for any error a request can produce. */
export function errorMessage(error) {
  if (error?.status === 'FETCH_ERROR') return "We couldn't reach the server. Please try again."
  return error?.data?.error ?? 'Something went wrong. Please try again.'
}

/** The API's per-field validation errors, such as { email: ["has already been taken"] }. */
export function fieldErrors(error) {
  return error?.data?.errors ?? {}
}
