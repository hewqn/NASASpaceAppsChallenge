import { describe, expect, it } from 'vitest'
import { freeFallTimeS, passesSafetyFactor, pressureAtAltitude, weightNewtons } from './physics'

describe('physics helpers', () => {
  it('weights a mass with the planet gravity', () => {
    expect(weightNewtons(10, 1.62)).toBeCloseTo(16.2)
  })

  it('holds Venus surface pressure at altitude zero and raises it below', () => {
    const venusPa = 92 * 100_000
    const scaleM = 15_900
    expect(pressureAtAltitude(venusPa, scaleM, 0)).toBe(venusPa)
    expect(pressureAtAltitude(venusPa, scaleM, scaleM)).toBeCloseTo(venusPa / Math.E)
  })

  it('changes the pass threshold with difficulty and leaves the stress alone', () => {
    const stress = 100
    const yieldStrength = 140
    expect(passesSafetyFactor(yieldStrength, stress, 1.1)).toBe(true)
    expect(passesSafetyFactor(yieldStrength, stress, 1.5)).toBe(false)
    expect(stress).toBe(100)
  })

  it('predicts a longer Moon fall than an Earth fall from the same height', () => {
    expect(freeFallTimeS(6, 1.62)).toBeGreaterThan(freeFallTimeS(6, 9.82))
  })
})
