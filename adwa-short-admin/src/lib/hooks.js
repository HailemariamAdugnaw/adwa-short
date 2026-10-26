import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  get,
  publishEpisode,
  unpublishEpisode,
  getCreators,
  getCreator,
  createCreator,
  updateCreator,
  deleteCreator,
  setCreatorSplit,
  getCreatorRevenue,
  getCreatorContent,
  processPayout,
  getCreatorPayouts,
  getRevenueOverview,
  getRevenueByCreator,
  getRevenueByContent,
  getRevenueByMethod,
  getRevenueTransactions,
  processExpiredPasses,
  getReviews,
  deleteReview,
  getStaff,
  getStaffMember,
  createStaff,
  updateStaff,
  toggleStaffActive,
  deleteStaff,
  getStaffActivity,
  getCreatorPortalDashboard,
  getCreatorPortalContent,
  getCreatorPortalReviews,
  getCreatorPortalPayoutAccount,
  getCreatorPortalTransactions,
  getCreatorPortalProfile,
  getAdUnlockLogs,
  errMsg,
} from './api'
import { useAuthStore } from './store'

export function useDebouncedValue(value, delay = 300) {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(t)
  }, [value, delay])
  return debounced
}

export function useMe() {
  const accessToken = useAuthStore((s) => s.accessToken)
  return useQuery({
    queryKey: ['me'],
    queryFn: () => get('/users/me'),
    enabled: !!accessToken,
    retry: false,
  })
}

export function useAnalyticsOverview() {
  return useQuery({
    queryKey: ['analytics', 'overview'],
    queryFn: () => get('/admin/analytics/overview'),
  })
}

export function useContentPerformance() {
  return useQuery({
    queryKey: ['analytics', 'content'],
    queryFn: () => get('/admin/analytics/content'),
  })
}

export function useContentEpisodesPerformance(seriesId) {
  return useQuery({
    queryKey: ['analytics', 'content', 'episodes', seriesId],
    queryFn: () => get('/admin/analytics/content/episodes', seriesId ? { series_id: seriesId } : undefined),
  })
}

export function useAdminPayouts(params) {
  return useQuery({
    queryKey: ['admin', 'revenue', 'payouts', params],
    queryFn: () => get('/admin/revenue/payouts', params),
  })
}

export function useCategories() {
  return useQuery({
    queryKey: ['categories'],
    queryFn: async () => {
      const data = await get('/categories')
      return Array.isArray(data) ? data : []
    },
  })
}

export function useSeriesList(params) {
  return useQuery({
    queryKey: ['series', 'list', params],
    queryFn: async () => {
      const data = await get('/series', params)
      return Array.isArray(data) ? data : []
    },
    placeholderData: (prev) => prev,
  })
}

export function useSeries(id) {
  return useQuery({
    queryKey: ['series', id],
    queryFn: () => get(`/series/${id}`),
    enabled: !!id,
  })
}

export function useEpisodes(seriesId) {
  return useQuery({
    queryKey: ['series', seriesId, 'episodes'],
    queryFn: async () => {
      const data = await get('/episodes', { series_id: seriesId })
      return Array.isArray(data) ? data : []
    },
    enabled: !!seriesId,
  })
}

export function usePublishEpisode() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id) => publishEpisode(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['series'] }),
  })
}

export function useUnpublishEpisode() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id) => unpublishEpisode(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['series'] }),
  })
}

export function useCoinPackages() {
  return useQuery({
    queryKey: ['coin-packages'],
    queryFn: async () => {
      const data = await get('/coins/packages')
      return Array.isArray(data) ? data : []
    },
  })
}

export function useTimePasses() {
  return useQuery({
    queryKey: ['passes'],
    queryFn: async () => {
      const data = await get('/passes')
      return Array.isArray(data) ? data : []
    },
  })
}

export function useSubscriptionPlans() {
  return useQuery({
    queryKey: ['subscription-plans'],
    queryFn: async () => {
      const data = await get('/subscriptions/plans')
      return Array.isArray(data) ? data : []
    },
  })
}

export function useAdUnlockRule() {
  return useQuery({
    queryKey: ['ad-unlock-rule'],
    queryFn: () => get('/ad-unlocks/rule'),
  })
}

export function useAdUnlockLogs(params) {
  return useQuery({
    queryKey: ['ad-unlock-logs', params],
    queryFn: () => getAdUnlockLogs(params),
  })
}

export function useLoyaltyConfig() {
  return useQuery({
    queryKey: ['loyalty-config'],
    queryFn: () => get('/loyalty/config'),
  })
}

export function useSettings() {
  return useQuery({
    queryKey: ['settings'],
    queryFn: async () => {
      const data = await get('/settings')
      return Array.isArray(data) ? data : []
    },
  })
}

export function useManualDeposits(page = 1) {
  return useQuery({
    queryKey: ['manual-deposits', page],
    queryFn: async () => {
      const data = await get('/admin/wallet/manual-deposits', { page })
      return Array.isArray(data) ? data : []
    },
    placeholderData: (prev) => prev,
  })
}

export function useUsers(params) {
  return useQuery({
    queryKey: ['users', params],
    queryFn: async () => {
      const data = await get('/admin/users', params)
      return Array.isArray(data) ? data : []
    },
    placeholderData: (prev) => prev,
  })
}

export function useUser(id) {
  return useQuery({
    queryKey: ['users', id],
    queryFn: () => get(`/admin/users/${id}`),
    enabled: !!id,
  })
}

export function useUserWallet(id) {
  return useQuery({
    queryKey: ['users', id, 'wallet'],
    queryFn: () => get(`/admin/users/${id}/wallet`),
    enabled: !!id,
  })
}

export function useUserDevices(userId) {
  return useQuery({
    queryKey: ['users', userId, 'devices'],
    queryFn: async () => {
      const data = await get('/devices', { user_id: userId })
      return Array.isArray(data) ? data : []
    },
    enabled: !!userId,
  })
}

export function useCreators(params) {
  return useQuery({
    queryKey: ['creators', params],
    queryFn: async () => {
      const data = await getCreators(params)
      return Array.isArray(data) ? data : []
    },
    placeholderData: (prev) => prev,
  })
}

export function useCreator(id) {
  return useQuery({
    queryKey: ['creators', id],
    queryFn: () => getCreator(id),
    enabled: !!id,
  })
}

export function useCreateCreator() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data) => createCreator(data),
    onSuccess: () => {
      toast.success('Creator created')
      qc.invalidateQueries({ queryKey: ['creators'] })
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to create creator')),
  })
}

export function useUpdateCreator() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }) => updateCreator(id, data),
    onSuccess: (_d, { id }) => {
      toast.success('Creator updated')
      qc.invalidateQueries({ queryKey: ['creators'] })
      qc.invalidateQueries({ queryKey: ['creators', id] })
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to update creator')),
  })
}

export function useDeleteCreator() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id) => deleteCreator(id),
    onSuccess: () => {
      toast.success('Creator deleted')
      qc.invalidateQueries({ queryKey: ['creators'] })
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to delete creator')),
  })
}

export function useSetCreatorSplit() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }) => setCreatorSplit(id, data),
    onSuccess: (_d, { id }) => {
      toast.success('Split rule saved')
      qc.invalidateQueries({ queryKey: ['creators', id] })
      qc.invalidateQueries({ queryKey: ['creators'] })
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to save split rule')),
  })
}

export function useCreatorRevenue(id, options = {}) {
  return useQuery({
    queryKey: ['creators', id, 'revenue'],
    queryFn: () => getCreatorRevenue(id),
    enabled: !!id && (options.enabled !== false),
    ...options,
  })
}

export function useCreatorContent(id) {
  return useQuery({
    queryKey: ['creators', id, 'content'],
    queryFn: async () => {
      const data = await getCreatorContent(id)
      return Array.isArray(data) ? data : []
    },
    enabled: !!id,
  })
}

export function useProcessPayout() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }) => processPayout(id, data),
    onSuccess: (_d, { id }) => {
      toast.success('Payout processed')
      qc.invalidateQueries({ queryKey: ['creators', id, 'payouts'] })
      qc.invalidateQueries({ queryKey: ['creators', id] })
      qc.invalidateQueries({ queryKey: ['revenue-overview'] })
      qc.invalidateQueries({ queryKey: ['revenue-by-creator'] })
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to process payout')),
  })
}

export function useCreatorPayouts(id, options = {}) {
  return useQuery({
    queryKey: ['creators', id, 'payouts'],
    queryFn: async () => {
      const data = await getCreatorPayouts(id)
      return Array.isArray(data) ? data : []
    },
    enabled: !!id && (options.enabled !== false),
    ...options,
  })
}

export function useRevenueOverview() {
  return useQuery({
    queryKey: ['revenue-overview'],
    queryFn: () => getRevenueOverview(),
  })
}

export function useRevenueByCreator() {
  return useQuery({
    queryKey: ['revenue-by-creator'],
    queryFn: async () => {
      const data = await getRevenueByCreator()
      return Array.isArray(data) ? data : []
    },
  })
}

export function useRevenueByContent(params) {
  return useQuery({
    queryKey: ['revenue-by-content', params],
    queryFn: async () => {
      const data = await getRevenueByContent(params)
      return Array.isArray(data) ? data : []
    },
    placeholderData: (prev) => prev,
  })
}

export function useRevenueByMethod() {
  return useQuery({
    queryKey: ['revenue-by-method'],
    queryFn: async () => {
      const data = await getRevenueByMethod()
      return Array.isArray(data) ? data : []
    },
  })
}

export function useRevenueTransactions(params) {
  return useQuery({
    queryKey: ['revenue-transactions', params],
    queryFn: async () => {
      const data = await getRevenueTransactions(params)
      if (Array.isArray(data)) return { items: data, total: data.length }
      return data ?? { items: [], total: 0 }
    },
    placeholderData: (prev) => prev,
  })
}

export function useProcessExpiredPasses() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: () => processExpiredPasses(),
    onSuccess: (data) => {
      const count = data?.processed ?? data?.count ?? 0
      toast.success(`Processed ${count} expired pass(es)`)
      qc.invalidateQueries({ queryKey: ['revenue-overview'] })
      qc.invalidateQueries({ queryKey: ['revenue-transactions'] })
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to process expired passes')),
  })
}

export function useReviews(params) {
  return useQuery({
    queryKey: ['reviews', params],
    queryFn: async () => {
      const data = await getReviews(params)
      if (Array.isArray(data)) return { items: data, total: data.length }
      return data ?? { items: [], total: 0 }
    },
    placeholderData: (prev) => prev,
  })
}

export function useDeleteReview() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id) => deleteReview(id),
    onSuccess: () => {
      toast.success('Review deleted')
      qc.invalidateQueries({ queryKey: ['reviews'] })
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to delete review')),
  })
}

export function useStaffList() {
  return useQuery({
    queryKey: ['admin', 'staff'],
    queryFn: async () => {
      const data = await getStaff()
      return Array.isArray(data) ? data : []
    },
  })
}

export function useStaffMember(id) {
  return useQuery({
    queryKey: ['admin', 'staff', id],
    queryFn: () => getStaffMember(id),
    enabled: !!id,
  })
}

export function useStaffActivity(params) {
  return useQuery({
    queryKey: ['admin', 'staff', 'activity', params],
    queryFn: () => getStaffActivity(params),
    placeholderData: (prev) => prev,
  })
}

export function useCreatorPortalDashboard() {
  return useQuery({
    queryKey: ['creator', 'dashboard'],
    queryFn: () => getCreatorPortalDashboard(),
  })
}

export function useCreatorPortalContent(params) {
  return useQuery({
    queryKey: ['creator', 'content', params],
    queryFn: () => getCreatorPortalContent(params),
  })
}

export function useCreatorPortalReviews(params) {
  return useQuery({
    queryKey: ['creator', 'reviews', params],
    queryFn: () => getCreatorPortalReviews(params),
  })
}

export function useCreatorPortalPayoutAccount() {
  return useQuery({
    queryKey: ['creator', 'payout-account'],
    queryFn: () => getCreatorPortalPayoutAccount(),
  })
}

export function useCreatorPortalTransactions(params) {
  return useQuery({
    queryKey: ['creator', 'transactions', params],
    queryFn: () => getCreatorPortalTransactions(params),
  })
}

export function useCreatorPortalProfile() {
  return useQuery({
    queryKey: ['creator', 'profile'],
    queryFn: () => getCreatorPortalProfile(),
  })
}
