import { CuboidCollider, Physics, RigidBody } from '@react-three/rapier'
import { useRef } from 'react'
import { MATERIALS } from '../data/materials'
import type { Inventory } from '../data/materials'
import { planetById } from '../data/catalog'
import { Atmosphere } from './Atmosphere'
import { Terrain } from './Terrain'
import { Walker } from './Walker'

const YARD_GROUND = '#6f8f62'
const YARD_SKY = '#9eb6c9'
const CACHE_POINTS: Array<[number, number]> = MATERIALS.map((material) => [
  material.position[0],
  material.position[2],
])

export function nearestCache(x: number, z: number, inventory: Inventory): string | null {
  let best: string | null = null
  let bestDistance = 1.7
  for (const material of MATERIALS) {
    if ((inventory[material.id] ?? 0) > 0) continue
    const [cx, , cz] = material.position
    const distance = Math.hypot(x - cx, z - cz)
    if (distance < bestDistance) {
      best = material.id
      bestDistance = distance
    }
  }
  return best
}

export function EarthYard({
  inventory,
  onMove,
}: {
  inventory: Inventory
  onMove: (x: number, z: number) => void
}) {
  const gravity = planetById('earth').gravityMs2
  const reported = useRef(onMove)
  reported.current = onMove

  return (
    <Physics gravity={[0, -gravity, 0]}>
      <Atmosphere sky={YARD_SKY} ground={YARD_GROUND} sun="#fff4dc" />
      <RigidBody type="fixed" colliders={false} position={[0, -0.5, 0]}>
        <CuboidCollider args={[40, 0.5, 40]} />
      </RigidBody>
      <Terrain base={YARD_GROUND} seed={11} rocks={40} avoid={CACHE_POINTS} rockTint={0.62} />
      <mesh position={[0, 1.3, -5.2]} castShadow receiveShadow>
        <boxGeometry args={[3.4, 2.2, 2.4]} />
        <meshStandardMaterial color="#8c5a3c" roughness={0.85} />
      </mesh>
      <mesh position={[0, 2.6, -5.2]} castShadow>
        <boxGeometry args={[3.8, 0.4, 2.8]} />
        <meshStandardMaterial color="#6e3b2a" roughness={0.8} />
      </mesh>
      {MATERIALS.map((material) =>
        (inventory[material.id] ?? 0) > 0 ? null : (
          <group key={material.id} position={material.position}>
            <mesh position={[0, 0.7, 0]}>
              <cylinderGeometry args={[0.05, 0.05, 1.4, 6]} />
              <meshStandardMaterial color={material.color} emissive={material.color} emissiveIntensity={0.35} />
            </mesh>
            <mesh castShadow>
              <boxGeometry args={material.id === 'oxygen' ? [0.4, 0.85, 0.4] : [0.85, 0.5, 0.65]} />
              <meshStandardMaterial color={material.color} roughness={0.35} metalness={0.45} />
            </mesh>
          </group>
        ),
      )}
      <Walker color="#e7d3a1" onMove={(x, z) => reported.current(x, z)} />
    </Physics>
  )
}
