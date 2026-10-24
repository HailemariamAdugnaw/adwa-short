const VIDEO_MIME = {
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.webm': 'video/webm',
  '.m4v': 'video/x-m4v',
  '.mkv': 'video/x-matroska',
  '.avi': 'video/x-msvideo',
  '.flv': 'video/x-flv',
  '.wmv': 'video/x-ms-wmv',
  '.mpeg': 'video/mpeg',
  '.mpg': 'video/mpeg',
  '.3gp': 'video/3gpp',
  '.ts': 'video/mp2t',
  '.m3u8': 'application/vnd.apple.mpegurl',
}

const UNPLAYABLE_VIDEO_EXTS = new Set([
  '.mkv',
  '.avi',
  '.flv',
  '.wmv',
  '.3gp',
  '.ts',
  '.m3u8',
])

export function extOf(nameOrUrl) {
  if (!nameOrUrl) return ''
  const clean = String(nameOrUrl).split('?')[0].split('#')[0]
  const slash = clean.lastIndexOf('/')
  const base = slash >= 0 ? clean.slice(slash + 1) : clean
  const dot = base.lastIndexOf('.')
  return dot >= 0 ? base.slice(dot).toLowerCase() : ''
}

export function getVideoMime(nameOrUrl) {
  return VIDEO_MIME[extOf(nameOrUrl)] || 'video/mp4'
}

export function isUnplayableVideo(nameOrUrl) {
  return UNPLAYABLE_VIDEO_EXTS.has(extOf(nameOrUrl))
}

export function getVideoDuration(file) {
  return new Promise((resolve) => {
    if (!file || typeof document === 'undefined' || !document.createElement) {
      resolve(null)
      return
    }
    const video = document.createElement('video')
    video.preload = 'metadata'
    let settled = false
    const finish = (value) => {
      if (settled) return
      settled = true
      const src = video.src
      if (src && src.startsWith('blob:')) {
        setTimeout(() => URL.revokeObjectURL(src), 0)
      }
      resolve(value)
    }
    video.onloadedmetadata = () => {
      const d = video.duration
      finish(Number.isFinite(d) && d > 0 ? Math.round(d) : null)
    }
    video.onerror = () => finish(null)
    try {
      video.src = URL.createObjectURL(file)
    } catch {
      finish(null)
      return
    }
    setTimeout(() => finish(null), 5000)
  })
}
