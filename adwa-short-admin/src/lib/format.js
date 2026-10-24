import { format, formatDistanceToNow, parseISO } from 'date-fns'

export function formatBirr(amount, opts) {
  if (amount === null || amount === undefined || Number.isNaN(amount)) return 'Br 0'
  const value = Number(amount)
  if (opts?.compact && value >= 1000) {
    const k = value / 1000
    return `Br ${k >= 100 ? k.toFixed(0) : k.toFixed(1)}k`
  }
  return `Br ${value.toLocaleString('en-US', {
    minimumFractionDigits: value % 1 === 0 ? 0 : 2,
    maximumFractionDigits: 2,
  })}`
}

export function formatNumber(n, opts) {
  if (n === null || n === undefined || Number.isNaN(n)) return '0'
  if (opts?.compact) {
    return new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 }).format(n)
  }
  return n.toLocaleString('en-US')
}

export function formatPercent(value, digits = 1) {
  if (value === null || value === undefined || Number.isNaN(value)) return '—'
  return `${Number(value).toFixed(digits)}%`
}

export function formatDate(iso, pattern = 'MMM d, yyyy') {
  if (!iso) return '—'
  try {
    return format(parseISO(iso), pattern)
  } catch {
    return '—'
  }
}

export function formatDateTime(iso) {
  return formatDate(iso, 'MMM d, yyyy · HH:mm')
}

export function formatRelative(iso) {
  if (!iso) return '—'
  try {
    return formatDistanceToNow(parseISO(iso), { addSuffix: true })
  } catch {
    return '—'
  }
}

export function formatDuration(seconds) {
  if (!seconds || seconds <= 0) return '0m'
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = Math.floor(seconds % 60)
  if (h > 0) return `${h}h ${m}m`
  if (m > 0) return `${m}m ${s}s`
  return `${s}s`
}

export function formatViews(n) {
  if (!n) return '0'
  return formatNumber(n, { compact: true })
}

export function formatBytes(bytes) {
  if (!bytes || bytes <= 0 || Number.isNaN(bytes)) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  const v = bytes / Math.pow(1024, i)
  return `${v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)} ${units[i]}`
}

export function truncate(str, max = 60) {
  if (!str) return ''
  return str.length > max ? `${str.slice(0, max - 1)}…` : str
}

export function initials(name, phone) {
  if (name) {
    const parts = name.trim().split(/\s+/).slice(0, 2)
    return parts.map((p) => p[0]?.toUpperCase() ?? '').join('') || '—'
  }
  if (phone) return phone.slice(-2)
  return '—'
}
