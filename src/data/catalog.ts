import difficultyJson from './difficulty.json'
import planetsJson from './planets.json'
import type { DifficultyId, DifficultyProfile } from '../types/difficulty'
import type { Planet } from '../types/planet'

export const PLANETS = planetsJson as Planet[]
export const DIFFICULTIES = difficultyJson as DifficultyProfile[]

const FACT_SHEET_HOST = 'https://nssdc.gsfc.nasa.gov/planetary/factsheet/'

export function planetById(id: string): Planet {
  const found = PLANETS.find((planet) => planet.id === id)
  if (!found) throw new Error(`Unknown body: ${id}`)
  return found
}

export function difficultyById(id: DifficultyId): DifficultyProfile {
  const found = DIFFICULTIES.find((profile) => profile.id === id)
  if (!found) throw new Error(`Unknown difficulty: ${id}`)
  return found
}

export function assertFactSheetRecords(planets: readonly Planet[]): void {
  const ids = new Set<string>()
  for (const planet of planets) {
    if (ids.has(planet.id)) throw new Error(`Duplicate body id: ${planet.id}`)
    ids.add(planet.id)
    if (!planet.sourceUrl.startsWith(FACT_SHEET_HOST)) {
      throw new Error(`${planet.id} source is not an NSSDC fact sheet`)
    }
    if (!(planet.gravityMs2 > 0)) throw new Error(`${planet.id} is missing gravity`)
    if (!(planet.solarIrradianceWm2 > 0)) {
      throw new Error(`${planet.id} is missing solar irradiance`)
    }
    if (planet.gravityDatum === '1bar' && planet.referencePressure.value !== 100_000) {
      throw new Error(`${planet.id} 1-bar datum must start at 100000 Pa`)
    }
    if (planet.texture !== null) {
      throw new Error(`${planet.id} texture is not loaded yet`)
    }
  }
}
