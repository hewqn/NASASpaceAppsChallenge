import { DESTINATION_ORDER } from './data/sources'

const STORAGE_KEY = 'codag.clears'

export type MissionClear = {
  planetId: string
  difficultyId: string
}

export function isDestinationUnlocked(
  planetId: string,
  clearedPlanetIds: ReadonlySet<string>,
): boolean {
  const index = DESTINATION_ORDER.indexOf(planetId as (typeof DESTINATION_ORDER)[number])
  if (index < 0) return false
  if (index === 0) return true
  return clearedPlanetIds.has(DESTINATION_ORDER[index - 1])
}

export function readClears(): MissionClear[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as unknown
    if (!Array.isArray(parsed)) return []
    return parsed.filter(
      (entry): entry is MissionClear =>
        typeof entry === 'object' &&
        entry !== null &&
        typeof (entry as MissionClear).planetId === 'string' &&
        typeof (entry as MissionClear).difficultyId === 'string',
    )
  } catch {
    return []
  }
}

export function clearedPlanetIds(clears: readonly MissionClear[]): Set<string> {
  return new Set(clears.map((entry) => entry.planetId))
}

export function recordClear(entry: MissionClear): MissionClear[] {
  const clears = readClears()
  const already = clears.some(
    (saved) => saved.planetId === entry.planetId && saved.difficultyId === entry.difficultyId,
  )
  if (already) return clears
  const next = [...clears, entry]
  localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
  return next
}
