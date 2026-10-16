import { describe, it, expect } from 'vitest'
import { extOf, getVideoMime, isUnplayableVideo } from './media'

describe('media helpers', () => {
  it('extracts extension from filename or url', () => {
    expect(extOf('foo.mp4')).toBe('.mp4')
    expect(extOf('foo.MKV')).toBe('.mkv')
    expect(extOf('/uploads/videos/abc123.webm')).toBe('.webm')
    expect(extOf('/uploads/videos/abc123.webm?token=1')).toBe('.webm')
    expect(extOf('noext')).toBe('')
    expect(extOf('')).toBe('')
    expect(extOf(null)).toBe('')
  })

  it('returns mime for known video extensions', () => {
    expect(getVideoMime('foo.mp4')).toBe('video/mp4')
    expect(getVideoMime('foo.mov')).toBe('video/quicktime')
    expect(getVideoMime('foo.mkv')).toBe('video/x-matroska')
    expect(getVideoMime('foo.webm')).toBe('video/webm')
    expect(getVideoMime('foo.avi')).toBe('video/x-msvideo')
  })

  it('falls back to video/mp4 for unknown extensions', () => {
    expect(getVideoMime('foo.xyz')).toBe('video/mp4')
    expect(getVideoMime('')).toBe('video/mp4')
  })

  it('flags unplayable video extensions', () => {
    expect(isUnplayableVideo('foo.mkv')).toBe(true)
    expect(isUnplayableVideo('foo.avi')).toBe(true)
    expect(isUnplayableVideo('foo.flv')).toBe(true)
    expect(isUnplayableVideo('foo.wmv')).toBe(true)
    expect(isUnplayableVideo('foo.3gp')).toBe(true)
    expect(isUnplayableVideo('foo.ts')).toBe(true)
    expect(isUnplayableVideo('foo.m3u8')).toBe(true)
    expect(isUnplayableVideo('foo.mp4')).toBe(false)
    expect(isUnplayableVideo('foo.mov')).toBe(false)
    expect(isUnplayableVideo('foo.webm')).toBe(false)
  })
})
