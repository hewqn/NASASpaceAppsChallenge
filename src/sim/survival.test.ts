import { describe, expect, it } from 'vitest'
import { planetById } from '../data/catalog'
import { emptyDesign, type Design } from './design'
import { celsius } from './human'
import { exposure, outsidePressurePa, runMission, survived } from './survival'

const normal = 1.5

function suited(extra: Partial<Design> = {}): Design {
  return {
    ...emptyDesign(),
    shellMaterialId: 'aluminum',
    shellRadiusM: 0.55,
    shellThicknessM: 0.004,
    insulationMaterialId: 'aerogel',
    insulationThicknessM: 0.02,
    oxygenKg: 1,
    ...extra,
  }
}

describe('survival against an Earth body', () => {
  it('lets you stand on Earth', () => {
    const result = runMission(emptyDesign(), planetById('earth'), normal, 'hot')
    expect(survived(result)).toBe(true)
    expect(celsius(result.bodyTempK)).toBeCloseTo(37, 0)
  })

  it('kills an unprotected person on the Moon by pressure, not by a gentle chill', () => {
    const result = runMission(emptyDesign(), planetById('moon'), normal, 'hot')
    expect(result.cause).toBe('pressure')
    expect(outsidePressurePa(planetById('moon'))).toBeLessThan(6300)
  })

  it('burns a bare metal shell on the Moon day side and lets aerogel last', () => {
    const bare = runMission(suited({ insulationMaterialId: null }), planetById('moon'), normal, 'hot')
    const wrapped = runMission(suited(), planetById('moon'), normal, 'hot')
    expect(bare.cause).toBe('burn')
    expect(survived(wrapped)).toBe(true)
    expect(exposure(planetById('moon'), 'hot').kelvin).toBe(390)
    expect(exposure(planetById('moon'), 'cold').kelvin).toBe(95)
  })

  it('runs out of oxygen when the only air is what you brought', () => {
    const result = runMission(suited({ oxygenKg: 0 }), planetById('moon'), normal, 'cold')
    expect(result.cause).toBe('oxygen')
  })

  it('crushes a thin shell on Venus and freezes an open suit at Jupiter’s 1 bar level', () => {
    const venus = runMission(suited(), planetById('venus'), normal, 'hot')
    const jupiter = runMission(suited({ shellMaterialId: null, insulationMaterialId: null }), planetById('jupiter'), normal, 'hot')
    expect(venus.cause).toBe('crush')
    expect(jupiter.cause).toBe('freeze')
    expect(exposure(planetById('jupiter'), 'hot').kelvin).toBe(165)
  })
})
