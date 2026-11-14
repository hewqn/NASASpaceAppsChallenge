import { describe, expect, it } from 'vitest'
import { assertFactSheetRecords, planetById, PLANETS } from './catalog'
import { DESTINATION_ORDER } from './sources'
import { ONE_BAR_PA, pressureAtAltitude, solarPanelPowerW } from '../sim/physics'

describe('fact sheet records', () => {
  it('accepts only NSSDC fact-sheet bodies', () => {
    expect(() => assertFactSheetRecords(PLANETS)).not.toThrow()
    expect(PLANETS.map((planet) => planet.id)).toEqual([
      'earth',
      'moon',
      'mercury',
      'venus',
      'mars',
      'jupiter',
      'saturn',
      'uranus',
      'neptune',
    ])
    for (const id of DESTINATION_ORDER) {
      expect(PLANETS.some((planet) => planet.id === id)).toBe(true)
    }
  })

  it('keeps published point values', () => {
    const moon = planetById('moon')
    const venus = planetById('venus')
    const jupiter = planetById('jupiter')
    const neptune = planetById('neptune')
    const mercury = planetById('mercury')

    expect(moon.gravityMs2).toBe(1.62)
    expect(moon.solarIrradianceWm2).toBe(1361)
    expect(moon.temperatures[0]?.minK).toBe(95)
    expect(moon.temperatures[0]?.maxK).toBe(390)
    expect(venus.referencePressure.value).toBe(92 * ONE_BAR_PA)
    expect(jupiter.gravityDatum).toBe('1bar')
    expect(jupiter.gravityMs2).toBe(25.92)
    expect(jupiter.referencePressure.value).toBe(ONE_BAR_PA)
    expect(jupiter.temperatures[0]?.kelvin).toBe(165)
    expect(jupiter.scaleHeightM.value).toBe(27_000)
    expect(neptune.scaleHeightM.value).toBeNull()
    expect(neptune.scaleHeightM.min).toBe(19_100)
    expect(neptune.scaleHeightM.max).toBe(20_300)
    expect(mercury.referencePressure.value).toBeNull()
    expect(mercury.referencePressure.max).toBe(5e-10)
  })

  it('uses sheet irradiance for solar power and the 1-bar start for Jupiter', () => {
    const moon = planetById('moon')
    const jupiter = planetById('jupiter')
    expect(solarPanelPowerW(moon.solarIrradianceWm2, 1, 0.2)).toBeCloseTo(272.2)
    expect(pressureAtAltitude(jupiter.referencePressure.value ?? 0, jupiter.scaleHeightM.value ?? 1, 0)).toBe(
      ONE_BAR_PA,
    )
    expect(
      pressureAtAltitude(ONE_BAR_PA, 27_000, -27_000),
    ).toBeCloseTo(ONE_BAR_PA * Math.E)
  })
})
