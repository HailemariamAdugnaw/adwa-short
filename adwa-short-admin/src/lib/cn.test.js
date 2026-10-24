import { describe, it, expect } from 'vitest'
import { cn } from './cn'

describe('cn', () => {
  it('joins class names', () => {
    expect(cn('a', 'b')).toBe('a b')
  })
  it('handles conditional classes', () => {
    const hide = false
    expect(cn('a', hide && 'b', undefined, 'c')).toBe('a c')
  })
  it('deduplicates conflicting tailwind classes', () => {
    expect(cn('text-white', 'text-red-500')).toBe('text-red-500')
  })
})
