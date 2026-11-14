import { materialById } from '../data/materials'
import type { Inventory } from '../data/materials'

export type Design = {
  shellMaterialId: string | null
  shellRadiusM: number
  shellThicknessM: number
  insulationMaterialId: string | null
  insulationThicknessM: number
  oxygenKg: number
}

export const TANK_KG_PER_OXYGEN_KG = 5

export function emptyDesign(): Design {
  return {
    shellMaterialId: null,
    shellRadiusM: 0.48,
    shellThicknessM: 0.0016,
    insulationMaterialId: null,
    insulationThicknessM: 0.012,
    oxygenKg: 0,
  }
}

export function shellVolumeM3(design: Design): number {
  if (!design.shellMaterialId || design.shellThicknessM <= 0 || design.shellRadiusM <= design.shellThicknessM) {
    return 0
  }
  const outer = design.shellRadiusM
  const inner = outer - design.shellThicknessM
  return (4 / 3) * Math.PI * (outer ** 3 - inner ** 3)
}

export function shellAreaM2(design: Design): number {
  const radius = design.shellMaterialId ? design.shellRadiusM : 0.45
  return 4 * Math.PI * radius * radius
}

export function insulationVolumeM3(design: Design): number {
  if (!design.insulationMaterialId || design.insulationThicknessM <= 0) return 0
  return shellAreaM2(design) * design.insulationThicknessM
}

export function shellMassKg(design: Design): number {
  if (!design.shellMaterialId) return 0
  return materialById(design.shellMaterialId).densityKgM3 * shellVolumeM3(design)
}

export function insulationMassKg(design: Design): number {
  if (!design.insulationMaterialId) return 0
  return materialById(design.insulationMaterialId).densityKgM3 * insulationVolumeM3(design)
}

export function oxygenHardwareKg(design: Design): number {
  return design.oxygenKg * TANK_KG_PER_OXYGEN_KG
}

export function designMassKg(design: Design): number {
  return shellMassKg(design) + insulationMassKg(design) + design.oxygenKg + oxygenHardwareKg(design)
}

export function stockProblem(design: Design, inventory: Inventory): string | null {
  if (design.shellMaterialId) {
    const have = inventory[design.shellMaterialId] ?? 0
    const need = shellMassKg(design)
    if (need > have + 1e-6) {
      return `That shell is heavier than the ${materialById(design.shellMaterialId).name.toLowerCase()} you found. Try a smaller suit.`
    }
  }
  if (design.insulationMaterialId) {
    const have = inventory[design.insulationMaterialId] ?? 0
    const need = insulationMassKg(design)
    if (need > have + 1e-6) {
      return `That wrap is heavier than the ${materialById(design.insulationMaterialId).name.toLowerCase()} you found. Try a smaller suit.`
    }
  }
  const oxygen = inventory.oxygen ?? 0
  if (design.oxygenKg > oxygen + 1e-6) {
    return 'You packed more oxygen than you found.'
  }
  return null
}

export function isSealed(design: Design): boolean {
  if (!design.shellMaterialId || design.shellThicknessM <= 0) return false
  if (design.shellRadiusM <= design.shellThicknessM) return false
  return materialById(design.shellMaterialId).structural
}
