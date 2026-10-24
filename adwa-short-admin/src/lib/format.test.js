import { describe, it, expect } from 'vitest'
import { formatBirr, formatNumber, formatPercent, formatDuration, truncate, initials, formatBytes } from './format'

describe('formatters', () => {
  it('formats Birr amounts', () => {
    expect(formatBirr(0)).toBe('Br 0')
    expect(formatBirr(1500)).toBe('Br 1,500')
    expect(formatBirr(99.5)).toBe('Br 99.50')
    expect(formatBirr(null)).toBe('Br 0')
    expect(formatBirr(undefined)).toBe('Br 0')
    expect(formatBirr(15000, { compact: true })).toBe('Br 15.0k')
  })

  it('formats numbers', () => {
    expect(formatNumber(1234567)).toBe('1,234,567')
    expect(formatNumber(0)).toBe('0')
    expect(formatNumber(2500, { compact: true })).toBe('2.5K')
  })

  it('formats percentages', () => {
    expect(formatPercent(42.123)).toBe('42.1%')
    expect(formatPercent(0)).toBe('0.0%')
    expect(formatPercent(null)).toBe('—')
  })

  it('formats durations', () => {
    expect(formatDuration(0)).toBe('0m')
    expect(formatDuration(45)).toBe('45s')
    expect(formatDuration(75)).toBe('1m 15s')
    expect(formatDuration(3661)).toBe('1h 1m')
  })

  it('truncates text', () => {
    expect(truncate('hello world', 5)).toBe('hell…')
    expect(truncate('hi', 5)).toBe('hi')
    expect(truncate(null)).toBe('')
  })

  it('computes initials', () => {
    expect(initials('Selam Tesfaye')).toBe('ST')
    expect(initials(null, '+251912345678')).toBe('78')
    expect(initials(null, null)).toBe('—')
  })

  it('formats bytes', () => {
    expect(formatBytes(0)).toBe('0 B')
    expect(formatBytes(512)).toBe('512 B')
    expect(formatBytes(1024)).toBe('1.0 KB')
    expect(formatBytes(1536)).toBe('1.5 KB')
    expect(formatBytes(1048576)).toBe('1.0 MB')
    expect(formatBytes(15728640)).toBe('15 MB')
    expect(formatBytes(null)).toBe('0 B')
  })
})
