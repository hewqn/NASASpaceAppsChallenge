import { useLayoutEffect, useMemo, useRef } from 'react'
import {
  CanvasTexture,
  Color,
  InstancedMesh,
  MathUtils,
  Object3D,
  RepeatWrapping,
  SRGBColorSpace,
} from 'three'

/** Small deterministic random generator so the scenery is the same every load. */
function mulberry32(seed: number) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function hash(x: number, y: number, seed: number): number {
  let h = Math.imul(x, 374761393) ^ Math.imul(y, 668265263) ^ Math.imul(seed, 2147483647)
  h = Math.imul(h ^ (h >>> 13), 1274126177)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296
}

/** Value noise whose lattice repeats every `period` cells, so the texture tiles without a seam. */
function valueNoise(x: number, y: number, seed: number, period: number): number {
  const xi = Math.floor(x)
  const yi = Math.floor(y)
  const xf = x - xi
  const yf = y - yi
  const u = xf * xf * (3 - 2 * xf)
  const v = yf * yf * (3 - 2 * yf)
  const wrap = (value: number) => ((value % period) + period) % period
  const a = hash(wrap(xi), wrap(yi), seed)
  const b = hash(wrap(xi + 1), wrap(yi), seed)
  const c = hash(wrap(xi), wrap(yi + 1), seed)
  const d = hash(wrap(xi + 1), wrap(yi + 1), seed)
  return MathUtils.lerp(MathUtils.lerp(a, b, u), MathUtils.lerp(c, d, u), v)
}

/** Tileable-enough multi-octave noise painted into a canvas, tinted around the base color. */
function makeGroundTexture(base: string, seed: number): { color: CanvasTexture; bump: CanvasTexture } {
  const size = 256
  const colorCanvas = document.createElement('canvas')
  const bumpCanvas = document.createElement('canvas')
  colorCanvas.width = colorCanvas.height = bumpCanvas.width = bumpCanvas.height = size
  const colorCtx = colorCanvas.getContext('2d')
  const bumpCtx = bumpCanvas.getContext('2d')
  if (!colorCtx || !bumpCtx) throw new Error('2D canvas unavailable')
  const colorImage = colorCtx.createImageData(size, size)
  const bumpImage = bumpCtx.createImageData(size, size)
  const tint = new Color(base)
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      let n = 0
      let amplitude = 0.5
      let frequency = 4
      for (let octave = 0; octave < 4; octave += 1) {
        n += valueNoise((x / size) * frequency, (y / size) * frequency, seed + octave, frequency) * amplitude
        amplitude *= 0.5
        frequency *= 2
      }
      const shade = 0.72 + n * 0.55
      const index = (y * size + x) * 4
      colorImage.data[index] = Math.min(255, tint.r * 255 * shade)
      colorImage.data[index + 1] = Math.min(255, tint.g * 255 * shade)
      colorImage.data[index + 2] = Math.min(255, tint.b * 255 * shade)
      colorImage.data[index + 3] = 255
      const height = Math.min(255, Math.max(0, n * 255 * 1.4))
      bumpImage.data[index] = bumpImage.data[index + 1] = bumpImage.data[index + 2] = height
      bumpImage.data[index + 3] = 255
    }
  }
  colorCtx.putImageData(colorImage, 0, 0)
  bumpCtx.putImageData(bumpImage, 0, 0)
  const color = new CanvasTexture(colorCanvas)
  const bump = new CanvasTexture(bumpCanvas)
  for (const texture of [color, bump]) {
    texture.wrapS = texture.wrapT = RepeatWrapping
    texture.repeat.set(40, 40)
    texture.anisotropy = 4
  }
  color.colorSpace = SRGBColorSpace
  return { color, bump }
}

function shade(base: string, amount: number): Color {
  const c = new Color(base)
  return c.multiplyScalar(amount)
}

const FIELD = 200
const WALK_LIMIT = 36

/**
 * Visual ground, scattered low-poly rocks, and a ring of far hills for a horizon.
 * The physics collider stays in the parent scene; this is only what you see.
 */
export function Terrain({
  base,
  seed = 7,
  rocks = 70,
  avoid = [],
  rockTint = 0.8,
}: {
  base: string
  seed?: number
  rocks?: number
  /** Points [x, z] that must stay clear, such as pickup caches. */
  avoid?: Array<[number, number]>
  rockTint?: number
}) {
  const textures = useMemo(() => makeGroundTexture(base, seed), [base, seed])
  const rockMesh = useRef<InstancedMesh>(null)
  const hillMesh = useRef<InstancedMesh>(null)

  const rockSpecs = useMemo(() => {
    const random = mulberry32(seed * 9973)
    const out: Array<{ x: number; z: number; s: number; ry: number; tint: number }> = []
    let guard = 0
    while (out.length < rocks && guard < rocks * 20) {
      guard += 1
      const x = (random() * 2 - 1) * WALK_LIMIT
      const z = (random() * 2 - 1) * WALK_LIMIT
      if (Math.hypot(x, z - 2) < 3.2) continue
      if (avoid.some(([ax, az]) => Math.hypot(x - ax, z - az) < 2.2)) continue
      const big = random() > 0.88
      out.push({
        x,
        z,
        s: big ? 0.9 + random() * 1.1 : 0.15 + random() * 0.5,
        ry: random() * Math.PI * 2,
        tint: 0.75 + random() * 0.45,
      })
    }
    return out
  }, [avoid, rocks, seed])

  const hillSpecs = useMemo(() => {
    const random = mulberry32(seed * 31)
    return Array.from({ length: 22 }, (_, index) => {
      const angle = (index / 22) * Math.PI * 2 + random() * 0.2
      const radius = 78 + random() * 22
      return {
        x: Math.cos(angle) * radius,
        z: Math.sin(angle) * radius,
        w: 14 + random() * 16,
        h: 8 + random() * 14,
        ry: random() * Math.PI,
      }
    })
  }, [seed])

  useLayoutEffect(() => {
    const dummy = new Object3D()
    const rockInstances = rockMesh.current
    if (rockInstances) {
      rockSpecs.forEach((spec, index) => {
        dummy.position.set(spec.x, spec.s * 0.32, spec.z)
        dummy.rotation.set(0, spec.ry, 0)
        dummy.scale.set(spec.s * 1.2, spec.s * 0.8, spec.s)
        dummy.updateMatrix()
        rockInstances.setMatrixAt(index, dummy.matrix)
        rockInstances.setColorAt(index, shade(base, rockTint * spec.tint))
      })
      rockInstances.instanceMatrix.needsUpdate = true
      if (rockInstances.instanceColor) rockInstances.instanceColor.needsUpdate = true
    }
    const hillInstances = hillMesh.current
    if (hillInstances) {
      hillSpecs.forEach((spec, index) => {
        dummy.position.set(spec.x, spec.h * 0.5 - 0.4, spec.z)
        dummy.rotation.set(0, spec.ry, 0)
        dummy.scale.set(spec.w, spec.h, spec.w)
        dummy.updateMatrix()
        hillInstances.setMatrixAt(index, dummy.matrix)
        hillInstances.setColorAt(index, shade(base, 0.55))
      })
      hillInstances.instanceMatrix.needsUpdate = true
      if (hillInstances.instanceColor) hillInstances.instanceColor.needsUpdate = true
    }
  }, [base, hillSpecs, rockSpecs, rockTint])

  return (
    <group>
      <mesh rotation-x={-Math.PI / 2} position={[0, 0.002, 0]} receiveShadow>
        <planeGeometry args={[FIELD, FIELD]} />
        <meshStandardMaterial
          map={textures.color}
          bumpMap={textures.bump}
          bumpScale={1.6}
          roughness={0.95}
          metalness={0}
        />
      </mesh>
      <instancedMesh ref={rockMesh} args={[undefined, undefined, rockSpecs.length]} castShadow receiveShadow>
        <dodecahedronGeometry args={[1, 0]} />
        <meshStandardMaterial flatShading roughness={0.9} />
      </instancedMesh>
      <instancedMesh ref={hillMesh} args={[undefined, undefined, hillSpecs.length]}>
        <coneGeometry args={[1, 1, 6]} />
        <meshStandardMaterial flatShading roughness={1} />
      </instancedMesh>
    </group>
  )
}
