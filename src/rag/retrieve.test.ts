import { describe, expect, it } from 'vitest'
import { planetById } from '../data/catalog'
import { retrieve } from './retrieve'

describe('fact retrieval', () => {
  it('pulls the Moon pressure line and Earth air for a pressure death', () => {
    const facts = retrieve(planetById('moon'), 'pressure')
    expect(facts.some((fact) => fact.text.includes('3 x 10^-15 bar'))).toBe(true)
    expect(facts.some((fact) => fact.sourceUrl.endsWith('earthfact.html'))).toBe(true)
    expect(facts.every((fact) => fact.sourceUrl.includes('nssdc.gsfc.nasa.gov'))).toBe(true)
  })

  it('pulls the 390 K day range when the cause is heat', () => {
    const facts = retrieve(planetById('moon'), 'burn')
    expect(facts.some((fact) => fact.text.includes('95 K to 390 K'))).toBe(true)
  })
})
