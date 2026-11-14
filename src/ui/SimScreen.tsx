import { Canvas } from '@react-three/fiber'
import { Suspense, useRef } from 'react'
import { planetById, difficultyById } from '../data/catalog'
import type { DifficultyId } from '../types/difficulty'
import { GravityDemo, predictedDropSeconds } from '../scene/GravityDemo'

const GROUND: Record<string, string> = {
  earth: '#6f8f62',
  moon: '#c2bbb2',
  mercury: '#b1977a',
  venus: '#c6a15a',
  mars: '#b56545',
  jupiter: '#c9b089',
  saturn: '#d2c093',
  uranus: '#8fb8c4',
  neptune: '#3f6f98',
}

export function SimScreen({
  planetId,
  difficultyId,
  onBack,
  onFinish,
}: {
  planetId: string
  difficultyId: DifficultyId | null
  onBack: () => void
  onFinish: () => void
}) {
  const planet = planetById(planetId)
  const difficulty = difficultyId ? difficultyById(difficultyId) : null
  const heightNode = useRef<HTMLSpanElement>(null)
  const dropSeconds = predictedDropSeconds(planet.gravityMs2)

  return (
    <div className="sim-stage">
      <Suspense fallback={<p className="sim-loading">Loading physics…</p>}>
        <Canvas shadows camera={{ position: [0, 4, 8], fov: 48 }}>
          <GravityDemo
            gravityMs2={planet.gravityMs2}
            ground={GROUND[planet.id] ?? '#8a8074'}
            heightNode={heightNode}
          />
        </Canvas>
      </Suspense>
      <div className="hud">
        <p className="kicker">{difficulty ? `${planet.name} · ${difficulty.label}` : `${planet.name} tutorial`}</p>
        <p className="hud-g">{planet.gravityMs2} m/s²</p>
        <p>
          Ball height <span ref={heightNode}>—</span>
        </p>
        <p className="fine">
          From 6 m with no drag, the fall takes about {dropSeconds.toFixed(1)} s. Same jump on every body. Lower
          gravity keeps you up longer.
        </p>
        <p className="fine">
          W A S D or arrows to walk. Space to jump.
        </p>
        <a href={planet.sourceUrl} target="_blank" rel="noreferrer">
          {planet.gravityTranscribedFrom}
        </a>
        <div className="hud-actions">
          <button className="ghost" type="button" onClick={onBack}>
            Back
          </button>
          <button className="primary" type="button" onClick={onFinish}>
            End drop
          </button>
        </div>
      </div>
    </div>
  )
}
