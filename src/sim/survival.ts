import { planetById } from '../data/catalog'
import { materialById } from '../data/materials'
import type { DifficultyProfile } from '../types/difficulty'
import type { Planet, TemperatureReading } from '../types/planet'
import { isSealed, type Design } from './design'
import { HUMAN, STEFAN_BOLTZMANN, celsius } from './human'

/** A short surface stay. Long enough to run out of a lungful of air. */
export const MISSION_SECONDS = 20 * 60

export type Side = 'hot' | 'cold'
export type DeathCause = 'pressure' | 'crush' | 'oxygen' | 'burn' | 'freeze'

export type Vitals = {
  bodyTempK: number
  oxygenKg: number
  elapsedS: number
  alive: boolean
  cause: DeathCause | null
}

export type Exposure = {
  kelvin: number
  transcribedFrom: string
}

export function outsidePressurePa(planet: Planet): number {
  if (planet.referencePressure.value != null) return planet.referencePressure.value
  if (planet.referencePressure.max != null) return planet.referencePressure.max
  return 0
}

export function oxygenFraction(planet: Planet): number {
  const match = planet.atmosphereComposition.match(/(\d+(?:\.\d+)?)%\s+oxygen/i)
  return match ? Number(match[1]) / 100 : 0
}

function extreme(reading: TemperatureReading, side: Side): number | null {
  if (side === 'hot') return reading.maxK ?? reading.kelvin
  return reading.minK ?? reading.kelvin
}

export function exposure(planet: Planet, side: Side): Exposure {
  let best: Exposure | null = null
  for (const reading of planet.temperatures) {
    const kelvin = extreme(reading, side)
    if (kelvin == null) continue
    if (!best || (side === 'hot' ? kelvin > best.kelvin : kelvin < best.kelvin)) {
      best = { kelvin, transcribedFrom: reading.transcribedFrom }
    }
  }
  return best ?? { kelvin: HUMAN.coreK, transcribedFrom: 'This sheet does not list a temperature.' }
}

export function shellSafetyFactor(design: Design, outsidePa: number): number | null {
  if (!isSealed(design) || !design.shellMaterialId) return null
  const material = materialById(design.shellMaterialId)
  const earthPa = planetById('earth').referencePressure.value ?? 101_400
  const deltaPa = Math.abs(outsidePa - earthPa)
  const radius = design.shellRadiusM - design.shellThicknessM
  const stress = (deltaPa * radius) / (2 * design.shellThicknessM)
  if (stress <= 0) return Number.POSITIVE_INFINITY
  return material.yieldPa / stress
}

function breathableAir(planet: Planet, outsidePa: number): boolean {
  return oxygenFraction(planet) * outsidePa >= HUMAN.minOxygenPartialPa
}

function earthlikeComfort(planet: Planet, outsidePa: number, ambientK: number): boolean {
  return (
    breathableAir(planet, outsidePa) &&
    outsidePa >= HUMAN.armstrongPa &&
    ambientK >= HUMAN.comfortMinK &&
    ambientK <= HUMAN.comfortMaxK
  )
}

function heatFlowW(design: Design, sealed: boolean, outsidePa: number, bodyK: number, ambientK: number): number {
  const area = HUMAN.areaM2
  if (!sealed && outsidePa < 100) {
    return HUMAN.emissivity * STEFAN_BOLTZMANN * area * (ambientK ** 4 - bodyK ** 4)
  }
  const wrap =
    design.insulationMaterialId && design.insulationThicknessM > 0
      ? materialById(design.insulationMaterialId)
      : null
  const wrapHolds = wrap != null && ambientK < wrap.meltingK
  if (sealed && wrapHolds && wrap) {
    return (wrap.conductivity * area * (ambientK - bodyK)) / design.insulationThicknessM
  }
  if (sealed && design.shellMaterialId && design.shellThicknessM > 0) {
    const shell = materialById(design.shellMaterialId)
    return (shell.conductivity * area * (ambientK - bodyK)) / design.shellThicknessM
  }
  return 10 * area * (ambientK - bodyK)
}

export function initialVitals(design: Design): Vitals {
  return {
    bodyTempK: HUMAN.coreK,
    oxygenKg: design.oxygenKg + HUMAN.lungOxygenKg,
    elapsedS: 0,
    alive: true,
    cause: null,
  }
}

export function stepVitals(
  vitals: Vitals,
  design: Design,
  planet: Planet,
  minSafetyFactor: number,
  side: Side,
  dt: number,
): Vitals {
  if (!vitals.alive || dt <= 0) return vitals
  const outsidePa = outsidePressurePa(planet)
  const ambientK = exposure(planet, side).kelvin
  const sealed = isSealed(design)
  let cause: DeathCause | null = null
  let bodyTempK = vitals.bodyTempK
  let oxygenKg = vitals.oxygenKg

  if (!sealed && outsidePa < HUMAN.armstrongPa) {
    cause = 'pressure'
  } else if (sealed && design.shellMaterialId && ambientK >= materialById(design.shellMaterialId).meltingK) {
    cause = 'burn'
  } else if (sealed) {
    const factor = shellSafetyFactor(design, outsidePa)
    if (factor != null && factor < minSafetyFactor) cause = 'crush'
  }

  if (!cause) {
    const regulating = !sealed && earthlikeComfort(planet, outsidePa, ambientK)
    if (!regulating) {
      const flow = heatFlowW(design, sealed, outsidePa, bodyTempK, ambientK) + HUMAN.metabolicW
      bodyTempK += (flow * dt) / (HUMAN.massKg * HUMAN.specificHeatJPerKgK)
    }
    if (!(breathableAir(planet, outsidePa) && !sealed)) {
      oxygenKg -= (HUMAN.oxygenKgPerDay / 86400) * dt
      if (oxygenKg <= 0) {
        oxygenKg = 0
        cause = 'oxygen'
      }
    }
    if (bodyTempK >= HUMAN.burnK) cause = cause ?? 'burn'
    if (bodyTempK <= HUMAN.freezeK) cause = cause ?? 'freeze'
  }

  return {
    bodyTempK,
    oxygenKg: Math.max(0, oxygenKg),
    elapsedS: vitals.elapsedS + dt,
    alive: cause == null,
    cause,
  }
}

export function runMission(
  design: Design,
  planet: Planet,
  minSafetyFactor: number,
  side: Side,
): Vitals {
  let state = initialVitals(design)
  while (state.alive && state.elapsedS < MISSION_SECONDS) {
    const dt = Math.min(5, MISSION_SECONDS - state.elapsedS)
    state = stepVitals(state, design, planet, minSafetyFactor, side, dt)
  }
  return state
}

export function deathTitle(cause: DeathCause): string {
  switch (cause) {
    case 'pressure':
      return 'The air pressure gave out.'
    case 'oxygen':
      return 'You ran out of oxygen.'
    case 'burn':
      return 'You burned.'
    case 'freeze':
      return 'You froze.'
    case 'crush':
      return 'The shell was crushed.'
  }
}

export function deathDetail(planet: Planet, side: Side, cause: DeathCause): string {
  const earth = planetById('earth')
  const stay = exposure(planet, side)
  const earthAverage = earth.temperatures.find((reading) => reading.kelvin != null)?.kelvin ?? exposure(earth, 'hot').kelvin
  const earthAir = `Your body is used to Earth: about ${celsius(earthAverage).toFixed(0)} °C, ${earth.referencePressure.transcribedFrom}, and air that is ${Math.round(oxygenFraction(earth) * 100)}% oxygen.`
  if (cause === 'pressure') {
    return `${earthAir} Here the pressure is too low to keep a human body intact (the Armstrong limit is about 6.3 kPa). ${planet.referencePressure.transcribedFrom}`
  }
  if (cause === 'oxygen') {
    return `${earthAir} This stay does not give you that oxygen, and the bottles you packed ran out. A person needs about ${HUMAN.oxygenKgPerDay} kg per day.`
  }
  if (cause === 'burn') {
    return `${earthAir} Your core climbed through ${celsius(HUMAN.burnK).toFixed(0)} °C. The place you stood was ${stay.kelvin} K. ${stay.transcribedFrom}`
  }
  if (cause === 'freeze') {
    return `${earthAir} Your core fell through ${celsius(HUMAN.freezeK).toFixed(0)} °C. The place you stood was ${stay.kelvin} K. ${stay.transcribedFrom}`
  }
  return `${earthAir} Outside pressure overcame the shell. ${planet.referencePressure.transcribedFrom}`
}

export function survived(vitals: Vitals): boolean {
  return vitals.alive && vitals.elapsedS >= MISSION_SECONDS - 1e-6
}

export function previewLine(design: Design, planet: Planet, profile: DifficultyProfile, side: Side): string {
  const result = runMission(design, planet, profile.minSafetyFactor, side)
  const where = `${planet.name}, ${side} side`
  if (survived(result)) return `${where}: you last the ${MISSION_SECONDS / 60} minutes.`
  return `${where}: ${deathTitle(result.cause ?? 'oxygen').replace(/\.$/, '')}.`
}
