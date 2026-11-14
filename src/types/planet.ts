export type Archetype = 'rocky' | 'gas' | 'ice'
export type GravityDatum = 'surface' | '1bar'
export type BodyRole = 'tutorial' | 'destination'

/** A number copied from a fact sheet. Ranges stay ranges; missing cells stay null. */
export type SheetSpan = {
  value: number | null
  min: number | null
  max: number | null
  transcribedFrom: string
}

export type TemperatureReading = {
  label: string
  kelvin: number | null
  minK: number | null
  maxK: number | null
  transcribedFrom: string
}

export type Planet = {
  id: string
  name: string
  role: BodyRole
  archetype: Archetype
  sourceUrl: string
  gravityMs2: number
  gravityDatum: GravityDatum
  gravityTranscribedFrom: string
  referencePressure: SheetSpan
  solarIrradianceWm2: number
  solarIrradianceTranscribedFrom: string
  blackBodyK: number
  blackBodyTranscribedFrom: string
  temperatures: TemperatureReading[]
  scaleHeightM: SheetSpan
  meanMolarMassKgPerMol: SheetSpan
  densityKgM3: SheetSpan | null
  atmosphereComposition: string
  atmosphereTranscribedFrom: string
  escapeVelocityMs: number
  escapeVelocityTranscribedFrom: string
  dayLengthS: number
  dayLengthTranscribedFrom: string
  semimajorAxisAu: number | null
  semimajorAxisTranscribedFrom: string
  massKg: number
  massTranscribedFrom: string
  equatorialRadiusM: number
  equatorialRadiusTranscribedFrom: string
  texture: null
}
