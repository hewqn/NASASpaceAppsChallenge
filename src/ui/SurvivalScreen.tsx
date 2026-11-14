import { Canvas } from '@react-three/fiber'
import { Suspense, useEffect, useRef, useState } from 'react'
import { planetById, difficultyById } from '../data/catalog'
import type { DifficultyId } from '../types/difficulty'
import type { Design } from '../sim/design'
import { celsius, HUMAN } from '../sim/human'
import {
  MISSION_SECONDS,
  initialVitals,
  stepVitals,
  deathTitle,
  survived,
  type Side,
  type Vitals,
} from '../sim/survival'
import { SurvivalWorld } from '../scene/SurvivalWorld'

const TIME_SCALE = 30
const GROUND: Record<string, string> = {
  moon: '#c2bbb2',
  mercury: '#b1977a',
  venus: '#c6a15a',
  mars: '#b56545',
  jupiter: '#c9b089',
  saturn: '#d2c093',
  uranus: '#7f9aa8',
  neptune: '#3f6f98',
}
const SKY: Record<string, string> = {
  moon: '#1c1a17',
  mercury: '#3a2a22',
  venus: '#c48a3a',
  mars: '#c47a55',
  jupiter: '#8a6a45',
  saturn: '#c2a36a',
  uranus: '#6e8f98',
  neptune: '#1d3550',
}

function clock(seconds: number): string {
  const whole = Math.max(0, Math.floor(seconds))
  const minutes = Math.floor(whole / 60)
  const rest = whole % 60
  return `${minutes}:${rest.toString().padStart(2, '0')}`
}

export function SurvivalScreen({
  planetId,
  difficultyId,
  design,
  side,
  onBack,
  onFinish,
}: {
  planetId: string
  difficultyId: DifficultyId
  design: Design
  side: Side
  onBack: () => void
  onFinish: (vitals: Vitals) => void
}) {
  const planet = planetById(planetId)
  const difficulty = difficultyById(difficultyId)
  const vitals = useRef<Vitals>(initialVitals(design))
  const finished = useRef(false)
  const [display, setDisplay] = useState(vitals.current)
  const oxygenStart = design.oxygenKg + HUMAN.lungOxygenKg

  useEffect(() => {
    let frame = 0
    let last = performance.now()
    let renderAccum = 0
    const loop = (now: number) => {
      const realDt = Math.min(0.05, (now - last) / 1000)
      last = now
      const current = vitals.current
      if (current.alive && current.elapsedS < MISSION_SECONDS) {
        vitals.current = stepVitals(
          current,
          design,
          planet,
          difficulty.minSafetyFactor,
          side,
          realDt * TIME_SCALE,
        )
      }
      renderAccum += realDt
      if (renderAccum > 0.1) {
        renderAccum = 0
        setDisplay({ ...vitals.current })
      }
      frame = requestAnimationFrame(loop)
    }
    frame = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(frame)
  }, [design, difficulty.minSafetyFactor, planet, side])

  const done = !display.alive || survived(display)
  const temp = celsius(display.bodyTempK)
  const tempPct = Math.min(100, Math.max(0, ((temp - 30) / 15) * 100))
  const airPct = Math.min(100, Math.max(0, (display.oxygenKg / oxygenStart) * 100))

  return (
    <div className="sim-stage">
      <Suspense fallback={<p className="sim-loading">Loading the surface…</p>}>
        <Canvas shadows camera={{ position: [0, 4, 8], fov: 48 }}>
          <SurvivalWorld
            gravityMs2={planet.gravityMs2}
            ground={GROUND[planet.id] ?? '#8a8074'}
            sky={SKY[planet.id] ?? '#14110e'}
          />
        </Canvas>
      </Suspense>
      <div className="hud">
        <p className="kicker">
          {planet.name} · {side} side · {difficulty.label}
        </p>
        <p className="hud-g">{clock(display.elapsedS)} / {clock(MISSION_SECONDS)}</p>
        <p className="fine">{planet.gravityMs2} m/s² · walk with W A S D · jump with space</p>
        <label className="meter">
          Core {temp.toFixed(1)} °C
          <span className="track">
            <span className="fill" style={{ width: `${tempPct}%` }} />
          </span>
          <span className="fine">Death below 35 °C or above 40 °C. Earth keeps you near 37.</span>
        </label>
        <label className="meter">
          Oxygen {display.oxygenKg.toFixed(3)} kg
          <span className="track">
            <span className="fill air" style={{ width: `${airPct}%` }} />
          </span>
        </label>
        {!display.alive && display.cause ? <p>{deathTitle(display.cause)}</p> : null}
        {done ? (
          <button
            className="primary"
            type="button"
            onClick={() => {
              if (finished.current) return
              finished.current = true
              onFinish(vitals.current)
            }}
          >
            {display.alive ? 'You held on' : 'You died'}
          </button>
        ) : (
          <button className="ghost" type="button" onClick={onBack}>
            Abort
          </button>
        )}
      </div>
    </div>
  )
}
