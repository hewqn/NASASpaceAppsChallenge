import { describe, expect, it } from 'vitest'
import { isDestinationUnlocked } from './progress'

describe('destination unlocks', () => {
  it('opens the Moon first and then the next cleared body', () => {
    const none = new Set<string>()
    expect(isDestinationUnlocked('moon', none)).toBe(true)
    expect(isDestinationUnlocked('mars', none)).toBe(false)
    expect(isDestinationUnlocked('mars', new Set(['moon']))).toBe(true)
    expect(isDestinationUnlocked('mercury', new Set(['moon']))).toBe(false)
    expect(isDestinationUnlocked('earth', none)).toBe(false)
  })
})
