import { useEffect, useRef, useState } from 'react'
import { Upload, X, ImageIcon, Film, AlertTriangle } from 'lucide-react'
import { cn } from '../../lib/cn'
import { resolveUrl } from '../../lib/api'
import { getVideoMime, isUnplayableVideo, extOf } from '../../lib/media'
import { formatBytes } from '../../lib/format'

export function FileDropzone({
  accept = 'all',
  maxSizeMB = 0,
  currentUrl,
  previewFile,
  onFile,
  onClear,
  className,
  label,
  helperText,
  uploading,
  previewType,
  previewAspect = 'video',
  children,
}) {
  const inputRef = useRef(null)
  const [drag, setDrag] = useState(false)
  const [error, setError] = useState(null)
  const [localUrl, setLocalUrl] = useState(null)
  const [videoError, setVideoError] = useState(false)

  const acceptStr =
    accept === 'image' ? 'image/*' : accept === 'video' ? 'video/*' : '*/*'

  const aspectClass =
    previewAspect === 'vertical'
      ? 'aspect-[9/16]'
      : previewAspect === 'poster'
        ? 'aspect-[2/3]'
        : 'aspect-video'

  const isVideo = previewType === 'video' || accept === 'video'
  const resolvedUrl = currentUrl ? resolveUrl(currentUrl) : null
  const displayUrl = localUrl || resolvedUrl
  const fileName = previewFile?.name
    || (currentUrl ? decodeURIComponent(String(currentUrl).split('/').pop() || '') : '')
  const fileExt = extOf(fileName)
  const unplayable = isVideo && !!displayUrl && isUnplayableVideo(fileName)

  useEffect(() => {
    if (!previewFile) {
      setLocalUrl(null)
      return
    }
    const url = URL.createObjectURL(previewFile)
    setLocalUrl(url)
    return () => {
      URL.revokeObjectURL(url)
      setLocalUrl(null)
    }
  }, [previewFile])

  useEffect(() => {
    setVideoError(false)
  }, [displayUrl])

  const handleFile = (file) => {
    if (!file) return
    setError(null)
    if (maxSizeMB && file.size > maxSizeMB * 1024 * 1024) {
      setError(`File too large. Max ${maxSizeMB}MB.`)
      return
    }
    onFile(file)
  }

  const onDrop = (e) => {
    e.preventDefault()
    setDrag(false)
    const file = e.dataTransfer.files?.[0]
    handleFile(file)
  }

  const Icon = accept === 'video' ? Film : accept === 'image' ? ImageIcon : Upload

  return (
    <div className={cn('w-full', className)}>
      {label && (
        <label className="mb-1.5 block text-xs font-medium uppercase tracking-wide text-text-secondary">
          {label}
        </label>
      )}
      {displayUrl ? (
        <div className="relative group rounded-md border border-border overflow-hidden bg-surface-2">
          {isVideo ? (
            unplayable || videoError ? (
              <div className={cn('flex flex-col items-center justify-center gap-2 bg-black p-4 text-center', aspectClass)}>
                <AlertTriangle className="h-5 w-5 text-amber-400" />
                <p className="text-xs font-medium text-white/90">
                  {videoError ? 'Preview not available in this browser' : `Preview not available for ${fileExt || 'this format'}`}
                </p>
                <p className="text-[11px] text-white/60">
                  Browser preview is not available. The file will play in the mobile app.
                </p>
                {resolvedUrl && (
                  <a
                    href={resolvedUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="mt-1 rounded-md bg-surface-2 px-2 py-1 text-[11px] text-white hover:bg-surface-3"
                  >
                    Download
                  </a>
                )}
              </div>
            ) : (
              <video
                controls
                playsInline
                preload="metadata"
                onError={() => setVideoError(true)}
                className={cn('w-full h-full object-contain bg-black', aspectClass)}
              >
                <source src={displayUrl} type={getVideoMime(fileName)} />
                Your browser does not support the video tag.
              </video>
            )
          ) : (
            <img
              src={displayUrl}
              alt="preview"
              className={cn('w-full object-cover', aspectClass)}
            />
          )}
          {previewFile && (
            <div className="absolute left-2 top-2 max-w-[80%] truncate rounded-md bg-black/70 px-2 py-1 text-[10px] font-medium text-white">
              {previewFile.name} · {formatBytes(previewFile.size)}
            </div>
          )}
          <div className="absolute inset-0 flex items-center justify-center gap-2 bg-black/70 opacity-0 transition-opacity group-hover:opacity-100">
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="rounded-md bg-surface-2 px-2 py-1 text-xs text-text-primary hover:bg-surface-3"
            >
              Replace
            </button>
            {onClear && (
              <button
                type="button"
                onClick={onClear}
                className="rounded-md bg-danger px-2 py-1 text-xs text-white hover:opacity-90"
              >
                Clear
              </button>
            )}
          </div>
          <button
            type="button"
            onClick={onClear}
            className="absolute right-1 top-1 rounded-md bg-black/60 p-1 text-white opacity-0 transition-opacity group-hover:opacity-100 hover:bg-black/80"
          >
            <X className="h-3 w-3" />
          </button>
        </div>
      ) : (
        <div
          onDragOver={(e) => {
            e.preventDefault()
            setDrag(true)
          }}
          onDragLeave={() => setDrag(false)}
          onDrop={onDrop}
          onClick={() => inputRef.current?.click()}
          className={cn(
            'flex cursor-pointer flex-col items-center justify-center rounded-md border border-dashed px-4 py-8 text-center transition-colors',
            drag ? 'border-accent bg-accent-soft' : 'border-border bg-surface-2/40 hover:border-border-strong hover:bg-surface-2',
          )}
        >
          <div className="mb-2 flex h-10 w-10 items-center justify-center rounded-full bg-surface-2 border border-border text-text-secondary">
            <Icon className="h-5 w-5" />
          </div>
          {children ?? (
            <>
              <p className="text-sm font-medium text-text-primary">
                {uploading ? 'Uploading…' : 'Click to upload or drag & drop'}
              </p>
              {helperText && <p className="mt-1 text-xs text-text-muted">{helperText}</p>}
            </>
          )}
        </div>
      )}
      <input
        ref={inputRef}
        type="file"
        accept={acceptStr}
        className="hidden"
        onChange={(e) => handleFile(e.target.files?.[0] ?? undefined)}
      />
      {error && <p className="mt-1 text-xs text-danger">{error}</p>}
    </div>
  )
}
