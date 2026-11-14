import materialsJson from './materials.json'

export type Material = {
  id: string
  name: string
  blurb: string
  densityKgM3: number
  yieldPa: number
  conductivity: number
  meltingK: number
  structural: boolean
  color: string
  foundKg: number
  position: [number, number, number]
  sourceNote: string
}

export const MATERIALS = materialsJson as Material[]

export function materialById(id: string): Material {
  const found = MATERIALS.find((material) => material.id === id)
  if (!found) throw new Error(`Unknown material: ${id}`)
  return found
}

export type Inventory = Record<string, number>

export function emptyInventory(): Inventory {
  return Object.fromEntries(MATERIALS.map((material) => [material.id, 0]))
}
