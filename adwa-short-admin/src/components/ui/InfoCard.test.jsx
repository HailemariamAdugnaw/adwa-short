import { describe, it, expect } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { InfoCard } from './InfoCard'

describe('InfoCard Collapsible', () => {
  const items = [
    'Rule 1: First instruction item',
    'Rule 2: Second instruction item',
    'Rule 3: Third instruction item',
    'Rule 4: Fourth instruction item',
  ]

  it('renders collapsed state with Read More button by default', () => {
    render(<InfoCard title="How it works" items={items} previewCount={1} />)

    expect(screen.getByText(/how it works/i)).toBeDefined()
    expect(screen.getByText('Rule 1: First instruction item')).toBeDefined()
    // Second item should not be visible when collapsed
    expect(screen.queryByText('Rule 2: Second instruction item')).toBeNull()

    // Read More toggle button is present
    const readMoreBtns = screen.getAllByRole('button', { name: /Read More/i })
    expect(readMoreBtns.length).toBeGreaterThan(0)
  })

  it('expands to show all items when Read More is clicked, and toggles to Read Less', () => {
    render(<InfoCard title="How it works" items={items} previewCount={1} />)

    const toggleBtn = screen.getAllByRole('button', { name: /Read More/i })[0]
    fireEvent.click(toggleBtn)

    // All items are now visible
    expect(screen.getByText('Rule 1: First instruction item')).toBeDefined()
    expect(screen.getByText('Rule 2: Second instruction item')).toBeDefined()
    expect(screen.getByText('Rule 3: Third instruction item')).toBeDefined()
    expect(screen.getByText('Rule 4: Fourth instruction item')).toBeDefined()

    // Button label is now Read Less
    expect(screen.getByRole('button', { name: /Read Less/i })).toBeDefined()

    // Clicking Read Less collapses it again
    fireEvent.click(screen.getByRole('button', { name: /Read Less/i }))
    expect(screen.queryByText('Rule 2: Second instruction item')).toBeNull()
  })
})
