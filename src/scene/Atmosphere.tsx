import { Environment, Lightformer, Stars } from '@react-three/drei'

/**
 * Shared lighting and sky for every level: a sun with a wide, sharp shadow,
 * a procedural reflection environment (no network fetch), distance fog, and
 * stars when there is no atmosphere to scatter light.
 */
export function Atmosphere({
  sky,
  ground,
  airless = false,
  sun = '#fff1d6',
  fogNear = 18,
  fogFar = 95,
}: {
  sky: string
  ground: string
  airless?: boolean
  sun?: string
  fogNear?: number
  fogFar?: number
}) {
  return (
    <>
      <color attach="background" args={[sky]} />
      <fog attach="fog" args={[sky, fogNear, fogFar]} />
      <hemisphereLight args={[sky, ground, airless ? 0.25 : 0.55]} />
      <directionalLight
        position={[16, 22, 9]}
        intensity={airless ? 3.2 : 2.3}
        color={sun}
        castShadow
        shadow-mapSize={[2048, 2048]}
        shadow-camera-left={-30}
        shadow-camera-right={30}
        shadow-camera-top={30}
        shadow-camera-bottom={-30}
        shadow-camera-near={1}
        shadow-camera-far={80}
        shadow-bias={-0.0004}
        shadow-normalBias={0.04}
      />
      <Environment resolution={128} environmentIntensity={airless ? 0.25 : 0.6}>
        <Lightformer form="rect" intensity={2.2} position={[0, 7, -9]} scale={[24, 7, 1]} color={sky} />
        <Lightformer form="rect" intensity={2.6} position={[11, 5, 5]} scale={[7, 7, 1]} color={sun} />
        <Lightformer form="rect" intensity={0.8} position={[-10, 3, 6]} scale={[8, 5, 1]} color={ground} />
      </Environment>
      {airless ? <Stars radius={110} depth={40} count={1800} factor={3.2} fade speed={0} /> : null}
    </>
  )
}
