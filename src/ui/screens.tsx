import { briefingRows } from '../data/briefing'
import { difficultyById, DIFFICULTIES, planetById, PLANETS } from '../data/catalog'
import { DESTINATION_ORDER, NASA_FACT_SHEET_NOTES } from '../data/sources'
import type { DifficultyId } from '../types/difficulty'
import { isDestinationUnlocked } from '../progress'
import { Frame } from './Frame'

export function StartScreen({ onStart }: { onStart: () => void }) {
  return (
    <Frame
      kicker="Single player"
      title="Design for the planet in front of you."
      lede="Each destination uses numbers from its NASA fact sheet. Difficulty changes your budget and safety margin. It does not change the planet."
      footer={
        <button className="primary" type="button" onClick={onStart}>
          Begin
        </button>
      }
    >
      <ol className="steps">
        <li>Read the briefing. Every stat links to the sheet it came from.</li>
        <li>Pick Easy, Normal, or Hard.</li>
        <li>Build gear, check the rocket, then drop in that gravity.</li>
      </ol>
    </Frame>
  )
}

export function PlanetSelect({
  clearedIds,
  onBack,
  onTutorial,
  onDestination,
}: {
  clearedIds: ReadonlySet<string>
  onBack: () => void
  onTutorial: () => void
  onDestination: (planetId: string) => void
}) {
  const earth = planetById('earth')
  return (
    <Frame
      kicker="Choose a body"
      title="Earth is the tutorial. The Moon is the first mission."
      lede="Later planets open after you clear the one before them, on any difficulty."
      onBack={onBack}
    >
      <div className="card-list">
        <article className="choice">
          <div>
            <h2>{earth.name}</h2>
            <p>Tutorial. Gravity {earth.gravityMs2} m/s² from the Earth fact sheet.</p>
          </div>
          <button className="primary" type="button" onClick={onTutorial}>
            Start tutorial
          </button>
        </article>
        {DESTINATION_ORDER.map((planetId) => {
          const planet = planetById(planetId)
          const open = isDestinationUnlocked(planetId, clearedIds)
          const index = DESTINATION_ORDER.indexOf(planetId)
          const previous = index > 0 ? planetById(DESTINATION_ORDER[index - 1]).name : null
          return (
            <article className="choice" key={planet.id}>
              <div>
                <h2>{planet.name}</h2>
                <p>
                  {planet.gravityMs2} m/s²
                  {planet.gravityDatum === '1bar' ? ' at 1 bar' : ' at the surface'}
                  {open ? '' : ` · Locked until you clear ${previous}`}
                </p>
              </div>
              <button
                className="primary"
                type="button"
                disabled={!open}
                onClick={() => onDestination(planet.id)}
              >
                {open ? 'Select' : 'Locked'}
              </button>
            </article>
          )
        })}
      </div>
      <p className="fine">
        {PLANETS.length} fact sheets cached in this build.{' '}
        <a href={earth.sourceUrl}>Earth sheet</a>
      </p>
    </Frame>
  )
}

export function DifficultySelect({
  planetId,
  onBack,
  onPick,
}: {
  planetId: string
  onBack: () => void
  onPick: (difficultyId: DifficultyId) => void
}) {
  const planet = planetById(planetId)
  return (
    <Frame
      kicker={planet.name}
      title="Pick a difficulty."
      lede="These rules change the mission around you. Gravity, pressure, and temperature stay on the fact sheet."
      onBack={onBack}
    >
      <div className="card-list">
        {DIFFICULTIES.map((profile) => (
          <article className="choice" key={profile.id}>
            <div>
              <h2>
                {profile.label} · score ×{profile.scoreMultiplier}
              </h2>
              <p>{profile.summary}</p>
              <p className="fine">
                Budgets ×{profile.budgetScale} · safety factor {profile.minSafetyFactor} ·{' '}
                {profile.maxAttempts == null ? 'unlimited attempts' : `${profile.maxAttempts} attempts`}
              </p>
            </div>
            <button className="primary" type="button" onClick={() => onPick(profile.id)}>
              Use {profile.label}
            </button>
          </article>
        ))}
      </div>
    </Frame>
  )
}

export function BriefingScreen({
  planetId,
  difficultyId,
  onBack,
  onContinue,
}: {
  planetId: string
  difficultyId: DifficultyId | null
  onBack: () => void
  onContinue: () => void
}) {
  const planet = planetById(planetId)
  const difficulty = difficultyId ? difficultyById(difficultyId) : null
  const rows = briefingRows(planet)
  return (
    <Frame
      kicker={difficulty ? `${planet.name} · ${difficulty.label}` : `${planet.name} tutorial`}
      title={planet.gravityDatum === '1bar' ? 'There is no ground here.' : 'Read the planet before you build.'}
      lede={
        planet.gravityDatum === '1bar'
          ? 'NASA gives gravity and temperature at the 1 bar level. The probe starts there. The sheet does not locate a solid surface.'
          : 'The figures below are copied from this body’s NASA fact sheet. The “why this matters” lines are the game, not extra NASA claims.'
      }
      onBack={onBack}
      footer={
        <button className="primary" type="button" onClick={onContinue}>
          Continue to gear
        </button>
      }
    >
      <ul className="stat-list">
        {rows.map((row) => (
          <li key={row.id}>
            <p className="stat-label">{row.label}</p>
            <p className="stat-value">{row.value}</p>
            <p className="why">{row.why}</p>
            <a href={planet.sourceUrl} target="_blank" rel="noreferrer">
              {row.sourceLine}
            </a>
          </li>
        ))}
      </ul>
      {planet.gravityDatum === '1bar' ? (
        <p className="fine">
          The 1 bar definition is from the{' '}
          <a href={NASA_FACT_SHEET_NOTES} target="_blank" rel="noreferrer">
            fact sheet notes
          </a>
          .
        </p>
      ) : null}
    </Frame>
  )
}

export function PlaceholderScreen({
  planetId,
  difficultyId,
  step,
  onBack,
  onContinue,
}: {
  planetId: string
  difficultyId: DifficultyId | null
  step: 'builder' | 'launch'
  onBack: () => void
  onContinue: () => void
}) {
  const planet = planetById(planetId)
  const difficulty = difficultyId ? difficultyById(difficultyId) : null
  const title = step === 'builder' ? 'Gear builder' : 'Launch check'
  const lede =
    step === 'builder'
      ? 'The 3D builder is next. Mass will be density times volume, shown against this difficulty’s budget.'
      : 'The rocket check is next. It will compare loadout mass with a rocket and this body’s escape speed.'
  return (
    <Frame
      kicker={difficulty ? `${planet.name} · ${difficulty.label}` : `${planet.name} tutorial`}
      title={title}
      lede={lede}
      onBack={onBack}
      footer={
        <button className="primary" type="button" onClick={onContinue}>
          {step === 'builder' ? 'Continue to launch check' : 'Drop in'}
        </button>
      }
    >
      <p className="fine">
        Gravity ready for the drop: {planet.gravityMs2} m/s².{' '}
        <a href={planet.sourceUrl} target="_blank" rel="noreferrer">
          {planet.gravityTranscribedFrom}
        </a>
      </p>
    </Frame>
  )
}

export function DebriefScreen({
  planetId,
  difficultyId,
  onAgain,
  onPlanets,
}: {
  planetId: string
  difficultyId: DifficultyId | null
  onAgain: () => void
  onPlanets: () => void
}) {
  const planet = planetById(planetId)
  const difficulty = difficultyId ? difficultyById(difficultyId) : null
  return (
    <Frame
      kicker="Practice drop"
      title="You felt the gravity. A mission report comes after the gear exists."
      lede={`This drop used ${planet.gravityMs2} m/s² from the ${planet.name} fact sheet. It does not clear the destination.`}
      footer={
        <>
          <button className="ghost" type="button" onClick={onAgain}>
            Drop again
          </button>
          <button className="primary" type="button" onClick={onPlanets}>
            Back to bodies
          </button>
        </>
      }
    >
      <p>
        <a href={planet.sourceUrl} target="_blank" rel="noreferrer">
          {planet.gravityTranscribedFrom}
        </a>
      </p>
      {difficulty ? (
        <p className="fine">
          {difficulty.label} is stored with the mission later. Score multiplier ×{difficulty.scoreMultiplier}. Safety
          factor required: {difficulty.minSafetyFactor}.
        </p>
      ) : (
        <p className="fine">The Earth hop is a tutorial, so it has no difficulty multiplier.</p>
      )}
    </Frame>
  )
}
