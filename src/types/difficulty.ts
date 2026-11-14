export type DifficultyId = 'easy' | 'normal' | 'hard'
export type HintLevel = 'preview' | 'warnings' | 'none'
export type CatalogSize = 'starter' | 'full'
export type EventMode = 'off' | 'once' | 'interval'

export type DifficultyProfile = {
  id: DifficultyId
  label: string
  budgetScale: number
  minSafetyFactor: number
  hintLevel: HintLevel
  catalog: CatalogSize
  maxAttempts: number | null
  eventMode: EventMode
  eventIntervalS: number | null
  scoreMultiplier: number
  summary: string
}
