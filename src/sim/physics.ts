import type { Planet, SheetSpan } from '../types/planet'

/** 1 bar, the pressure NASA uses as the giant-planet reference level. */
export const ONE_BAR_PA = 100_000

export function weightNewtons(massKg: number, gravityMs2: number): number {
  return massKg * gravityMs2
}

/** P = P_ref * exp(-h / H). Negative h is below the reference level. */
export function pressureAtAltitude(
  referencePa: number,
  scaleHeightM: number,
  altitudeM: number,
): number {
  return referencePa * Math.exp(-altitudeM / scaleHeightM)
}

export function solarPanelPowerW(
  irradianceWm2: number,
  areaM2: number,
  efficiency: number,
): number {
  return irradianceWm2 * areaM2 * efficiency
}

export function safetyFactor(yieldPa: number, stressPa: number): number {
  return yieldPa / stressPa
}

export function passesSafetyFactor(
  yieldPa: number,
  stressPa: number,
  minSafetyFactor: number,
): boolean {
  return safetyFactor(yieldPa, stressPa) >= minSafetyFactor
}

/** Time to fall a distance with no drag: t = sqrt(2h / g). */
export function freeFallTimeS(heightM: number, gravityMs2: number): number {
  return Math.sqrt((2 * heightM) / gravityMs2)
}

export function pointValue(span: SheetSpan): number | null {
  return span.value
}

export function referencePressurePa(planet: Planet): number | null {
  return planet.referencePressure.value
}
