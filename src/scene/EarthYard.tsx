import { CuboidCollider, Physics, RigidBody } from '@react-three/rapier'
import { useRef } from 'react'
import { MATERIALS } from '../data/materials'
import type { Inventory } from '../data/materials'
import { planetById } from '../data/catalog'
import { Walker } from './Walker'

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
      <color attach="background" args={['#9eb6c9']} />
      <fog attach="fog" args={['#9eb6c9', 18, 48]} />
      <hemisphereLight args={['#f4efe2', '#6f8f62', 0.75]} />
      <directionalLight position={[12, 18, 8]} intensity={1.35} castShadow />
      <RigidBody type="fixed" colliders={false} position={[0, -0.5, 0]}>
        <CuboidCollider args={[40, 0.5, 40]} />
        <mesh receiveShadow>
          <boxGeometry args={[80, 1, 80]} />
          <meshStandardMaterial color="#6f8f62" roughness={0.95} />
        </mesh>
      </RigidBody>
      <mesh position={[0, 1.3, -5.2]} castShadow>
        <boxGeometry args={[3.4, 2.2, 2.4]} />
        <meshStandardMaterial color="#8c5a3c" />
      </mesh>
      <mesh position={[0, 2.6, -5.2]}>
        <boxGeometry args={[3.8, 0.4, 2.8]} />
        <meshStandardMaterial color="#6e3b2a" />
      </mesh>
      {MATERIALS.map((material) =>
        (inventory[material.id] ?? 0) > 0 ? null : (
          <group key={material.id} position={material.position}>
            <mesh position={[0, 0.7, 0]}>
              <cylinderGeometry args={[0.05, 0.05, 1.4, 6]} />
              <meshStandardMaterial color={material.color} />
            </mesh>
            <mesh castShadow>
              <boxGeometry args={material.id === 'oxygen' ? [0.4, 0.85, 0.4] : [0.85, 0.5, 0.65]} />
              <meshStandardMaterial color={material.color} roughness={0.65} />
            </mesh>
          </group>
        ),
      )}
      <Walker color="#e7d3a1" onMove={(x, z) => reported.current(x, z)} />
    </Physics>
  )
}
