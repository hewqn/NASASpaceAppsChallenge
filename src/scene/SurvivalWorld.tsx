import { CuboidCollider, Physics, RigidBody } from '@react-three/rapier'
import { Walker } from './Walker'

export function SurvivalWorld({
  gravityMs2,
  ground,
  sky,
}: {
  gravityMs2: number
  ground: string
  sky: string
}) {
  return (
    <Physics gravity={[0, -gravityMs2, 0]}>
      <color attach="background" args={[sky]} />
      <fog attach="fog" args={[sky, 12, 36]} />
      <hemisphereLight args={['#f0e2c8', ground, 0.65]} />
      <directionalLight position={[8, 16, 6]} intensity={1.4} castShadow />
      <RigidBody type="fixed" colliders={false} position={[0, -0.5, 0]}>
        <CuboidCollider args={[40, 0.5, 40]} />
        <mesh receiveShadow>
          <boxGeometry args={[80, 1, 80]} />
          <meshStandardMaterial color={ground} roughness={0.92} />
        </mesh>
      </RigidBody>
      <Walker color="#e7d3a1" />
    </Physics>
  )
}
