import { QueryClient } from '@tanstack/react-query'
import { errMsg } from './api'

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
      staleTime: 30_000,
      gcTime: 5 * 60_000,
      meta: {
        onError: (err) => {
          console.error('[query error]', errMsg(err))
        },
      },
    },
    mutations: {
      retry: 0,
    },
  },
})

export function invalidateAll(client, keys) {
  return Promise.all(keys.map((k) => client.invalidateQueries({ queryKey: [k] })))
}
