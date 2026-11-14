import { Canvas } from '@react-three/fiber'
import { Suspense, useEffect, useRef, useState } from 'react'
import { materialById, MATERIALS, type Inventory } from '../data/materials'
import { EarthYard, nearestCache } from '../scene/EarthYard'

export function EarthScreen({
  inventory,
  onCollect,
  onWorkshop,
}: {
  inventory: Inventory
  onCollect: (materialId: string) => void
  onWorkshop: () => void
}) {
  const [nearId, setNearId] = useState<string | null>(null)
  const near = useRef<string | null>(null)
  const inventoryRef = useRef(inventory)
  inventoryRef.current = inventory
  const found = MATERIALS.filter((material) => (inventory[material.id] ?? 0) > 0).length

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.code !== 'KeyE' || !near.current) return
      onCollect(near.current)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onCollect])

  const prompt = nearId ? materialById(nearId) : null

  return (
    <div className="sim-stage">
      <Suspense fallback={<p className="sim-loading">Opening the yard…</p>}>
        <Canvas shadows dpr={[1, 1.75]} camera={{ position: [0, 4, 9], fov: 48 }}>
          <EarthYard
            inventory={inventory}
            onMove={(x, z) => {
              const next = nearestCache(x, z, inventoryRef.current)
              if (next === near.current) return
              near.current = next
              setNearId(next)
            }}
          />
        </Canvas>
      </Suspense>
      <div className="hud">
        <p className="kicker">Earth</p>
        <p className="hud-g">Find what you can carry.</p>
        <p>
          This air is about 15 °C and one bar, with oxygen in it. Your body is built for that. Other planets are not.
        </p>
        <p className="fine">W A S D to walk. Space to jump. E to pick up.</p>
        <p className="fine">
          {found} / {MATERIALS.length} caches found.
        </p>
        {prompt ? (
          <p className="prompt">
            E · {prompt.name}. {prompt.blurb}
          </p>
        ) : null}
        <button className="primary" type="button" onClick={onWorkshop}>
          Go to the workshop
        </button>
      </div>
    </div>
  )
}
