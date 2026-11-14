import { CuboidCollider, RigidBody, type RapierRigidBody } from '@react-three/rapier'
import { useFrame } from '@react-three/fiber'
import { useEffect, useRef } from 'react'
import { Vector3, type Group } from 'three'

const cameraTarget = new Vector3()
const cameraDesired = new Vector3()

export function useHeldKeys() {
  const keys = useRef(new Set<string>())
  useEffect(() => {
    const down = (event: KeyboardEvent) => {
      if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) return
      keys.current.add(event.code)
      if (event.code.startsWith('Arrow') || event.code === 'Space') event.preventDefault()
    }
    const up = (event: KeyboardEvent) => keys.current.delete(event.code)
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    return () => {
      window.removeEventListener('keydown', down)
      window.removeEventListener('keyup', up)
      keys.current.clear()
    }
  }, [])
  return keys
}

export function Walker({
  color,
  onMove,
}: {
  color: string
  onMove?: (x: number, z: number) => void
}) {
  const body = useRef<RapierRigidBody>(null)
  const model = useRef<Group>(null)
  const keys = useHeldKeys()

  useFrame(({ camera }) => {
    const actor = body.current
    if (!actor) return
    const pressed = keys.current
    let x = 0
    let z = 0
    if (pressed.has('KeyW') || pressed.has('ArrowUp')) z -= 1
    if (pressed.has('KeyS') || pressed.has('ArrowDown')) z += 1
    if (pressed.has('KeyA') || pressed.has('ArrowLeft')) x -= 1
    if (pressed.has('KeyD') || pressed.has('ArrowRight')) x += 1
    const length = Math.hypot(x, z) || 1
    const velocity = actor.linvel()
    const jumping = pressed.has('Space') && Math.abs(velocity.y) < 0.35
    actor.setLinvel(
      { x: (x / length) * 4.2, y: jumping ? 3.5 : velocity.y, z: (z / length) * 4.2 },
      true,
    )
    if (model.current && (x !== 0 || z !== 0)) {
      // The model faces -z at rotation 0. Turn it toward the direction of travel.
      const target = Math.atan2(-x, -z)
      let delta = target - model.current.rotation.y
      delta = Math.atan2(Math.sin(delta), Math.cos(delta))
      model.current.rotation.y += delta * 0.2
    }
    const position = actor.translation()
    onMove?.(position.x, position.z)
    cameraDesired.set(position.x, position.y + 3.2, position.z + 6.8)
    camera.position.lerp(cameraDesired, 0.14)
    cameraTarget.set(position.x, position.y + 0.7, position.z)
    camera.lookAt(cameraTarget)
  })

  return (
    <RigidBody ref={body} position={[0, 1.4, 2]} lockRotations colliders={false} ccd>
      <CuboidCollider args={[0.35, 0.7, 0.35]} />
      <group ref={model}>
        <mesh castShadow position={[0, -0.12, 0]}>
          <capsuleGeometry args={[0.3, 0.6, 6, 14]} />
          <meshStandardMaterial color={color} roughness={0.55} metalness={0.05} />
        </mesh>
        <mesh castShadow position={[0, 0.5, 0]}>
          <sphereGeometry args={[0.27, 20, 16]} />
          <meshStandardMaterial color={color} roughness={0.5} metalness={0.05} />
        </mesh>
        <mesh castShadow position={[0, 0.52, -0.16]} scale={[1, 0.8, 0.7]}>
          <sphereGeometry args={[0.21, 20, 16]} />
          <meshStandardMaterial color="#1b2430" roughness={0.12} metalness={0.9} envMapIntensity={1.6} />
        </mesh>
        <mesh castShadow position={[0, -0.02, 0.34]}>
          <boxGeometry args={[0.42, 0.55, 0.22]} />
          <meshStandardMaterial color="#b9b2a6" roughness={0.5} metalness={0.3} />
        </mesh>
        <mesh castShadow position={[0.36, -0.08, 0]}>
          <capsuleGeometry args={[0.09, 0.38, 4, 8]} />
          <meshStandardMaterial color={color} roughness={0.6} />
        </mesh>
        <mesh castShadow position={[-0.36, -0.08, 0]}>
          <capsuleGeometry args={[0.09, 0.38, 4, 8]} />
          <meshStandardMaterial color={color} roughness={0.6} />
        </mesh>
      </group>
    </RigidBody>
  )
}
