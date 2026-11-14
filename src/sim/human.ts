/** Limits of an unprotected human used to Earth. These are not planet-sheet numbers. */
export const HUMAN = {
  massKg: 70,
  /** Resting metabolic heat. */
  metabolicW: 100,
  specificHeatJPerKgK: 3470,
  areaM2: 1.8,
  emissivity: 0.97,
  /** 37 °C core. */
  coreK: 310.15,
  /** Clinical hypothermia. */
  freezeK: 308.15,
  /** Clinical heat stroke. */
  burnK: 313.15,
  /** Earth fact-sheet diurnal range (283 K to 293 K) sits inside this band. */
  comfortMinK: 282,
  comfortMaxK: 303.15,
  /** Armstrong limit: water boils at body temperature near 6.3 kPa. */
  armstrongPa: 6300,
  /** Rough partial pressure of oxygen below which a person cannot stay conscious. */
  minOxygenPartialPa: 16000,
  /** NASA life-support planning value, about 0.84 kg of oxygen per person per day. */
  oxygenKgPerDay: 0.84,
  /** One lungful. Runs out in a few minutes if you bring no bottles. */
  lungOxygenKg: 0.002,
}

export const STEFAN_BOLTZMANN = 5.670374419e-8

export function celsius(kelvin: number): number {
  return kelvin - 273.15
}
