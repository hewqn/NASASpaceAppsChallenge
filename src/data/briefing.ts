import type { Planet, SheetSpan, TemperatureReading } from '../types/planet'

export type BriefingRow = {
  id: string
  label: string
  value: string
  sourceLine: string
  why: string
}

const WHY: Record<string, string> = {
  gravity: 'This sets how fast you fall and how hard the gear weighs. The physics engine uses this number.',
  pressure: 'This is the air pushing on the gear at the start of the level. A parachute needs air. A shell fails when this climbs past its strength.',
  temperature: 'This is the environment your insulation has to deal with. Black-body temperature is a different number and is listed on its own.',
  irradiance: 'A solar panel’s power is this irradiance times its area times its efficiency. The game uses the printed fact-sheet value.',
  day: 'This is how long one day-night cycle lasts on this body.',
  escape: 'The launch check compares your rocket with this escape speed, plus a stated margin for gravity and drag losses.',
  scale: 'Pressure changes by about a factor of e over one scale height. Deeper than the start means higher pressure.',
  molar: 'Mean molecular weight is used when the game computes how dense the air is.',
  composition: 'What the air is made of changes whether a balloon can float. Hydrogen atmospheres are the hard case.',
  blackbody: 'This is the temperature of a bare surface in balance with sunlight and no atmosphere. It is not the survival temperature.',
  density: 'This is how heavy a cubic meter of air is at the reference level. Lift has to beat the gear’s weight in that air.',
}

function formatKelvin(reading: TemperatureReading): string {
  if (reading.kelvin != null && reading.minK != null && reading.maxK != null && reading.minK === reading.maxK) {
    return `${reading.kelvin} K, almost no day-night change`
  }
  if (reading.minK != null && reading.maxK != null) {
    return `${reading.minK} K to ${reading.maxK} K`
  }
  if (reading.kelvin != null) return `${reading.kelvin} K`
  return 'Not printed as a single value'
}

function formatSpan(span: SheetSpan, unit: string): string {
  const write = (n: number) => {
    if (unit === 'kg/mol') return n.toFixed(5).replace(/0+$/, '').replace(/\.$/, '')
    if (Math.abs(n) >= 1000) return n.toLocaleString('en-US')
    return String(n)
  }
  if (span.value != null && span.min == null && span.max == null) return `${write(span.value)} ${unit}`
  if (span.value == null && span.min != null && span.max != null) {
    return `${write(span.min)} to ${write(span.max)} ${unit}`
  }
  if (span.value != null && span.min != null && span.max != null) {
    return `${write(span.value)} ${unit} (range ${write(span.min)} to ${write(span.max)})`
  }
  if (span.max != null && span.value == null) return `less than about ${write(span.max)} ${unit}`
  return 'Not on this fact sheet'
}

function formatDay(seconds: number): string {
  const hours = seconds / 3600
  if (hours >= 48) {
    const days = seconds / 86400
    return `${days.toLocaleString('en-US', { maximumFractionDigits: 2 })} Earth days`
  }
  return `${hours.toLocaleString('en-US', { maximumFractionDigits: 2 })} hours`
}

function formatPressure(span: SheetSpan): string {
  if (span.value == null && span.max != null && span.max < 1) {
    return `upper bound about ${span.max.toExponential(0)} Pa`
  }
  return formatSpan(span, 'Pa')
}

export function briefingRows(planet: Planet): BriefingRow[] {
  const datum =
    planet.gravityDatum === '1bar'
      ? 'Mean gravity at the 1 bar level'
      : 'Mean surface gravity'

  const rows: BriefingRow[] = [
    {
      id: 'gravity',
      label: datum,
      value: `${planet.gravityMs2} m/s²`,
      sourceLine: planet.gravityTranscribedFrom,
      why: WHY.gravity,
    },
    {
      id: 'pressure',
      label: planet.gravityDatum === '1bar' ? 'Pressure at the start of the probe' : 'Surface pressure',
      value: formatPressure(planet.referencePressure),
      sourceLine: planet.referencePressure.transcribedFrom,
      why: WHY.pressure,
    },
    ...planet.temperatures.map((reading, index) => ({
      id: `temperature-${index}`,
      label: `Temperature, ${reading.label}`,
      value: formatKelvin(reading),
      sourceLine: reading.transcribedFrom,
      why: WHY.temperature,
    })),
    {
      id: 'irradiance',
      label: 'Solar irradiance',
      value: `${planet.solarIrradianceWm2} W/m²`,
      sourceLine: planet.solarIrradianceTranscribedFrom,
      why: WHY.irradiance,
    },
    {
      id: 'day',
      label: 'Length of day',
      value: formatDay(planet.dayLengthS),
      sourceLine: planet.dayLengthTranscribedFrom,
      why: WHY.day,
    },
    {
      id: 'escape',
      label: 'Escape velocity',
      value: `${(planet.escapeVelocityMs / 1000).toLocaleString('en-US')} km/s`,
      sourceLine: planet.escapeVelocityTranscribedFrom,
      why: WHY.escape,
    },
    {
      id: 'scale',
      label: 'Scale height',
      value: formatSpan(
        {
          ...planet.scaleHeightM,
          value: planet.scaleHeightM.value == null ? null : planet.scaleHeightM.value / 1000,
          min: planet.scaleHeightM.min == null ? null : planet.scaleHeightM.min / 1000,
          max: planet.scaleHeightM.max == null ? null : planet.scaleHeightM.max / 1000,
        },
        'km',
      ),
      sourceLine: planet.scaleHeightM.transcribedFrom,
      why: WHY.scale,
    },
    {
      id: 'molar',
      label: 'Mean molecular weight',
      value: formatSpan(planet.meanMolarMassKgPerMol, 'kg/mol'),
      sourceLine: planet.meanMolarMassKgPerMol.transcribedFrom,
      why: WHY.molar,
    },
    {
      id: 'composition',
      label: 'Atmosphere',
      value: planet.atmosphereComposition,
      sourceLine: planet.atmosphereTranscribedFrom,
      why: WHY.composition,
    },
    {
      id: 'blackbody',
      label: 'Black-body temperature',
      value: `${planet.blackBodyK} K`,
      sourceLine: planet.blackBodyTranscribedFrom,
      why: WHY.blackbody,
    },
  ]

  if (planet.densityKgM3) {
    rows.push({
      id: 'density',
      label: planet.gravityDatum === '1bar' ? 'Density at 1 bar' : 'Surface air density',
      value: formatSpan(planet.densityKgM3, 'kg/m³'),
      sourceLine: planet.densityKgM3.transcribedFrom,
      why: WHY.density,
    })
  }

  return rows
}
