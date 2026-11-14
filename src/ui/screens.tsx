import { briefingRows } from '../data/briefing'
import { difficultyById, DIFFICULTIES, planetById, PLANETS } from '../data/catalog'
import { DESTINATION_ORDER, NASA_FACT_SHEET_NOTES } from '../data/sources'
import type { DifficultyId } from '../types/difficulty'
import { isDestinationUnlocked } from '../progress'
import { celsius } from '../sim/human'
import { deathDetail, deathTitle, exposure, survived, type Side, type Vitals } from '../sim/survival'
import { Frame } from './Frame'

export function StartScreen({ onStart }: { onStart: () => void }) {
  return (
    <Frame
      kicker="Earth"
      title="You are built for this planet."
      lede="The air here is breathable, the pressure is about one bar, and a person can stand in the temperature the Earth fact sheet lists. Leave, and that stops being true. You die if the oxygen runs out, if your core freezes, or if it burns."
      footer={
        <button className="primary" type="button" onClick={onStart}>
          Step outside
        </button>
      }
    >
      <ol className="steps">
        <li>Walk the yard and pick up metal, insulation, and oxygen.</li>
        <li>Build a shell and a wrap from only what you found.</li>
        <li>Take it to a planet. Last twenty minutes, or die for a reason you can name.</li>
      </ol>
    </Frame>
  )
}

export function PlanetSelect({
  clearedIds,
  onBack,
  onDestination,
}: {
  clearedIds: ReadonlySet<string>
  onBack: () => void
  onDestination: (planetId: string) => void
}) {
  const earth = planetById('earth')
  return (
    <Frame
      kicker="Leave Earth"
      title="The Moon is the first place that can kill you."
      lede="You stay on Earth to build. Each body after the Moon opens when you survive the one before it."
      onBack={onBack}
    >
      <div className="card-list">
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
  onDepart,
}: {
  planetId: string
  difficultyId: DifficultyId
  onBack: () => void
  onDepart: (side: Side) => void
}) {
  const planet = planetById(planetId)
  const difficulty = difficultyById(difficultyId)
  const rows = briefingRows(planet)
  const hot = exposure(planet, 'hot')
  const cold = exposure(planet, 'cold')
  return (
    <Frame
      kicker={`${planet.name} · ${difficulty.label}`}
      title={planet.gravityDatum === '1bar' ? 'There is no ground here.' : 'Your body does not belong here.'}
      lede={
        planet.gravityDatum === '1bar'
          ? 'You start at the 1 bar level from the fact sheet. The air is not oxygen, and the temperature is not Earth’s. Hold twenty minutes.'
          : 'Earth keeps a person near 37 °C in air that contains oxygen. This sheet is what you have to survive for twenty minutes.'
      }
      onBack={onBack}
      footer={
        <>
          <button className="primary" type="button" onClick={() => onDepart('hot')}>
            Hot side, {celsius(hot.kelvin).toFixed(0)} °C
          </button>
          {cold.kelvin !== hot.kelvin ? (
            <button className="ghost" type="button" onClick={() => onDepart('cold')}>
              Cold side, {celsius(cold.kelvin).toFixed(0)} °C
            </button>
          ) : null}
        </>
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
  side,
  vitals,
  onAgain,
  onWorkshop,
  onEarth,
}: {
  planetId: string
  difficultyId: DifficultyId
  side: Side
  vitals: Vitals
  onAgain: () => void
  onWorkshop: () => void
  onEarth: () => void
}) {
  const planet = planetById(planetId)
  const madeIt = survived(vitals)
  const cause = vitals.cause
  return (
    <Frame
      kicker={madeIt ? 'You survived' : 'You died'}
      title={madeIt ? `Twenty minutes on ${planet.name}.` : deathTitle(cause ?? 'oxygen')}
      lede={
        madeIt
          ? `Your core stayed near 37 °C and you still had oxygen. ${planet.name} is cleared on this difficulty.`
          : deathDetail(planet, side, cause ?? 'oxygen')
      }
      footer={
        <>
          <button className="ghost" type="button" onClick={onWorkshop}>
            Change the suit
          </button>
          <button className="ghost" type="button" onClick={onAgain}>
            Try again
          </button>
          <button className="primary" type="button" onClick={onEarth}>
            Back to Earth
          </button>
        </>
      }
    >
      <p>
        <a href={planet.sourceUrl} target="_blank" rel="noreferrer">
          {planet.name} fact sheet
        </a>
      </p>
      <p className="fine">
        {difficultyById(difficultyId).label} asks for a safety factor of {difficultyById(difficultyId).minSafetyFactor}.
        The planet numbers did not change.
      </p>
    </Frame>
  )
}
