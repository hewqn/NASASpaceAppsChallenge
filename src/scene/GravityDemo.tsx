import { CuboidCollider, Physics, RigidBody, type RapierRigidBody } from '@react-three/rapier'
import { useFrame } from '@react-three/fiber'
import { useEffect, useRef, type RefObject } from 'react'
import { Vector3 } from 'three'
import { freeFallTimeS } from '../sim/physics'

const DROP_HEIGHT_M = 6
const cameraTarget = new Vector3()
const cameraDesired = new Vector3()

export function predictedDropSeconds(gravityMs2: number): number {
  return freeFallTimeS(DROP_HEIGHT_M, gravityMs2)
}

export function GravityDemo({
  gravityMs2,
  ground,
  heightNode,
}: {
  gravityMs2: number
  ground: string
  heightNode: RefObject<HTMLSpanElement | null>
}) {
  const player = useRef<RapierRigidBody>(null)
  const drop = useRef<RapierRigidBody>(null)
  const keys = useRef(new Set<string>())

  useEffect(() => {
    const down = (event: KeyboardEvent) => {
      keys.current.add(event.code)
      if (event.code.startsWith('Arrow') || event.code === 'Space') event.preventDefault()
    }
    const up = (event: KeyboardEvent) => {
      keys.current.delete(event.code)
    }
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    return () => {
      window.removeEventListener('keydown', down)
      window.removeEventListener('keyup', up)
      keys.current.clear()
    }
  }, [])

  useFrame(({ camera }) => {
    const body = player.current
    if (!body) return
    const pressed = keys.current
    let x = 0
    let z = 0
    if (pressed.has('KeyW') || pressed.has('ArrowUp')) z -= 1
    if (pressed.has('KeyS') || pressed.has('ArrowDown')) z += 1
    if (pressed.has('KeyA') || pressed.has('ArrowLeft')) x -= 1
    if (pressed.has('KeyD') || pressed.has('ArrowRight')) x += 1
    const length = Math.hypot(x, z) || 1
    const velocity = body.linvel()
    const jumping = pressed.has('Space') && Math.abs(velocity.y) < 0.35
    body.setLinvel(
      {
        x: (x / length) * 4,
        y: jumping ? 3.4 : velocity.y,
        z: (z / length) * 4,
      },
      true,
    )

    const position = body.translation()
    cameraDesired.set(position.x, position.y + 3.4, position.z + 7.2)
    camera.position.lerp(cameraDesired, 0.12)
    cameraTarget.set(position.x, position.y + 0.8, position.z)
    camera.lookAt(cameraTarget)

    const dropped = drop.current?.translation().y
    if (heightNode.current && dropped != null) {
      heightNode.current.textContent = `${Math.max(0, dropped - 0.4).toFixed(1)} m`
    }
  })

  return (
    <Physics gravity={[0, -gravityMs2, 0]}>
      <color attach="background" args={['#14110e']} />
      <fog attach="fog" args={['#14110e', 14, 42]} />
      <hemisphereLight args={['#f3e6cf', '#3a2a22', 0.7]} />
      <directionalLight position={[8, 16, 6]} intensity={1.5} castShadow />
      <RigidBody type="fixed" colliders={false} position={[0, -0.5, 0]}>
        <CuboidCollider args={[40, 0.5, 40]} />
        <mesh receiveShadow>
          <boxGeometry args={[80, 1, 80]} />
          <meshStandardMaterial color={ground} roughness={0.9} metalness={0.02} />
        </mesh>
      </RigidBody>
      <RigidBody ref={player} position={[0, 1.2, 0]} lockRotations colliders={false} ccd>
        <CuboidCollider args={[0.35, 0.7, 0.35]} />
        <mesh castShadow position={[0, 0, 0]}>
          <capsuleGeometry args={[0.35, 0.7, 6, 12]} />
          <meshStandardMaterial color="#e7d3a1" roughness={0.55} metalness={0.05} />
        </mesh>
      </RigidBody>
      <RigidBody ref={drop} position={[2.2, DROP_HEIGHT_M, -1]} colliders="ball" restitution={0.15}>
        <mesh castShadow>
          <sphereGeometry args={[0.4, 24, 24]} />
          <meshStandardMaterial color="#e08a3c" roughness={0.4} metalness={0.1} />
        </mesh>
      </RigidBody>
    </Physics>
  )
}
