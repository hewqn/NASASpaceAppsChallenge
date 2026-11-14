import { CuboidCollider, Physics, RigidBody } from '@react-three/rapier'
import { Atmosphere } from './Atmosphere'
import { Terrain } from './Terrain'
import { Walker } from './Walker'

export function SurvivalWorld({
  gravityMs2,
  ground,
  sky,
  airless = false,
  seed = 7,
}: {
  gravityMs2: number
  ground: string
  sky: string
  /** True where there is no atmosphere to scatter light: stars show and shadows go hard. */
  airless?: boolean
  seed?: number
}) {
  return (
    <Physics gravity={[0, -gravityMs2, 0]}>
      <Atmosphere sky={sky} ground={ground} airless={airless} />
      <RigidBody type="fixed" colliders={false} position={[0, -0.5, 0]}>
        <CuboidCollider args={[40, 0.5, 40]} />
      </RigidBody>
      <Terrain base={ground} seed={seed} rocks={80} />
      <Walker color="#e7d3a1" />
    </Physics>
  )
}
