import axios from 'axios'
import toast from 'react-hot-toast'
import { useAuthStore } from './store'

const RAW_BASE = import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, '') ?? ''
export const API_BASE = RAW_BASE || ''

export const api = axios.create({
  baseURL: API_BASE ? `${RAW_BASE}/api` : '/api',
  withCredentials: false,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 30000,
})

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().accessToken
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  let deviceId = localStorage.getItem('adwa_device_id')
  if (!deviceId) {
    deviceId =
      crypto.randomUUID?.() ??
      `dev-${Date.now()}-${Math.random().toString(16).slice(2)}`
    localStorage.setItem('adwa_device_id', deviceId)
  }
  config.headers['X-Device-Id'] = deviceId
  return config
})

let isRefreshing = false
let pendingQueue = []

function flushQueue(token) {
  pendingQueue.forEach((cb) => cb(token))
  pendingQueue = []
}

api.interceptors.response.use(
  (res) => res,
  async (error) => {
    const original = error.config
    const status = error.response?.status

    const msg =
      error.response?.data?.detail ??
      error.response?.data?.message ??
      error.message

    if (status === 401 && !original._retry && !original.url?.includes('/auth/')) {
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          pendingQueue.push((token) => {
            if (!token) return reject(error)
            original.headers = { ...original.headers, Authorization: `Bearer ${token}` }
            resolve(api(original))
          })
        })
      }

      original._retry = true
      isRefreshing = true

      const refreshToken = useAuthStore.getState().refreshToken
      try {
        if (!refreshToken) throw new Error('No refresh token')

        const res = await axios.post(
          `${API_BASE ? `${RAW_BASE}/api` : '/api'}/auth/refresh`,
          { refresh_token: refreshToken },
          { headers: { 'X-Device-Id': localStorage.getItem('adwa_device_id') ?? '' } },
        )
        const { access_token, refresh_token } = res.data
        useAuthStore.getState().setTokens(access_token, refresh_token)
        flushQueue(access_token)
        original.headers = { ...original.headers, Authorization: `Bearer ${access_token}` }
        return api(original)
      } catch (err) {
        flushQueue(null)
        useAuthStore.getState().logout()
        toast.error('Session expired. Please sign in again.')
        if (!window.location.pathname.startsWith('/login')) {
          window.location.href = '/login'
        }
        return Promise.reject(err)
      } finally {
        isRefreshing = false
      }
    }

    if (status && status >= 500) {
      toast.error(`Server error: ${msg}`)
    }
    return Promise.reject(error)
  },
)

export async function get(url, params) {
  const res = await api.get(url, { params })
  return res.data
}

export async function post(url, body, config) {
  const res = await api.post(url, body, config)
  return res.data
}

export async function put(url, body, config) {
  const res = await api.put(url, body, config)
  return res.data
}

export async function del(url, config) {
  const res = await api.delete(url, config)
  return res.data
}

export async function upload(url, file, field = 'file') {
  const form = new FormData()
  form.append(field, file)
  const res = await api.post(url, form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return res.data
}

export function resolveUrl(url) {
  if (!url) return ''
  if (/^(https?:|blob:|data:)/i.test(url)) return url
  if (url.startsWith('/')) return `${API_BASE}${url}`
  return url
}

export const publishEpisode = (id) => post(`/admin/content/episodes/${id}/publish`)
export const unpublishEpisode = (id) => post(`/admin/content/episodes/${id}/unpublish`)

export const getCreators = (params) => api.get('/creators', { params }).then((r) => r.data)
export const getCreator = (id) => api.get(`/creators/${id}`).then((r) => r.data)
export const createCreator = (data) => api.post('/creators', data).then((r) => r.data)
export const updateCreator = (id, data) => api.put(`/creators/${id}`, data).then((r) => r.data)
export const deleteCreator = (id) => api.delete(`/creators/${id}`).then((r) => r.data)
export const setCreatorSplit = (id, data) => api.put(`/creators/${id}/split`, data).then((r) => r.data)
export const getCreatorRevenue = (id) => api.get(`/creators/${id}/revenue`).then((r) => r.data)
export const getCreatorContent = (id) => api.get(`/creators/${id}/content`).then((r) => r.data)
export const processPayout = (id, data) => api.post(`/creators/${id}/payouts`, data).then((r) => r.data)
export const getCreatorPayouts = (id) => api.get(`/creators/${id}/payouts`).then((r) => r.data)
export const getRevenueOverview = () => api.get('/admin/revenue/overview').then((r) => r.data)
export const getRevenueByCreator = () => api.get('/admin/revenue/by-creator').then((r) => r.data)
export const getRevenueByContent = (params) => api.get('/admin/revenue/by-content', { params }).then((r) => r.data)
export const getRevenueByMethod = () => api.get('/admin/revenue/by-method').then((r) => r.data)
export const getRevenueTransactions = (params) => api.get('/admin/revenue/transactions', { params }).then((r) => r.data)
export const processExpiredPasses = () => api.post('/admin/revenue/process-expired').then((r) => r.data)

export const getReviews = (params) => api.get('/reviews/admin', { params }).then((r) => r.data)
export const deleteReview = (id) => api.delete(`/reviews/admin/${id}`).then((r) => r.data)

export const getStaff = () => api.get('/admin/staff').then((r) => r.data)
export const getStaffMember = (id) => api.get(`/admin/staff/${id}`).then((r) => r.data)
export const createStaff = (payload) => api.post('/admin/staff', payload).then((r) => r.data)
export const updateStaff = (id, payload) => api.put(`/admin/staff/${id}`, payload).then((r) => r.data)
export const toggleStaffActive = (id) => api.post(`/admin/staff/${id}/toggle-active`).then((r) => r.data)
export const deleteStaff = (id) => api.delete(`/admin/staff/${id}`).then((r) => r.data)
export const getStaffActivity = (params) => api.get('/admin/staff/activity', { params }).then((r) => r.data)

export function errMsg(err, fallback = 'Something went wrong') {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data
    return data?.detail ?? data?.message ?? err.message ?? fallback
  }
  if (err instanceof Error) return err.message
  return fallback
}
