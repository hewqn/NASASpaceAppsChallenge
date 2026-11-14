import { planetById } from '../data/catalog'
import type { DeathCause } from '../sim/survival'
import type { Planet } from '../types/planet'

/** One looked-up line. The debrief may quote these and nothing else as a "fact." */
export type FactChunk = {
  id: string
  planetId: string
  tags: string[]
  text: string
  sourceUrl: string
}

const CAUSE_TAGS: Record<DeathCause | 'survive', string[]> = {
  pressure: ['pressure', 'oxygen'],
  oxygen: ['oxygen'],
  burn: ['temperature'],
  freeze: ['temperature'],
  crush: ['pressure'],
  survive: ['pressure', 'temperature', 'oxygen'],
}

function chunksFor(planet: Planet): FactChunk[] {
  return [
    {
      id: `${planet.id}-pressure`,
      planetId: planet.id,
      tags: ['pressure'],
      text: planet.referencePressure.transcribedFrom,
      sourceUrl: planet.sourceUrl,
    },
    {
      id: `${planet.id}-air`,
      planetId: planet.id,
      tags: ['oxygen', 'pressure'],
      text: planet.atmosphereTranscribedFrom,
      sourceUrl: planet.sourceUrl,
    },
    ...planet.temperatures.map((reading, index) => ({
      id: `${planet.id}-temp-${index}`,
      planetId: planet.id,
      tags: ['temperature'],
      text: reading.transcribedFrom,
      sourceUrl: planet.sourceUrl,
    })),
    {
      id: `${planet.id}-gravity`,
      planetId: planet.id,
      tags: ['gravity'],
      text: planet.gravityTranscribedFrom,
      sourceUrl: planet.sourceUrl,
    },
  ]
}

/**
 * Structured retrieval: planet plus the failure tag, then Earth's matching lines
 * so the report can compare. No model is asked to invent a number.
 */
export function retrieve(planet: Planet, cause: DeathCause | 'survive'): FactChunk[] {
  const tags = new Set(CAUSE_TAGS[cause])
  const matches = (chunk: FactChunk) => chunk.tags.some((tag) => tags.has(tag))
  const here = chunksFor(planet).filter(matches)
  if (planet.id === 'earth') return here.slice(0, 4)
  const home = chunksFor(planetById('earth')).filter(matches)
  return [...here, ...home].slice(0, 4)
}
