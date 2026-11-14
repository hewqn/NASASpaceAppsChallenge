import { useMemo, useState } from 'react'
import type { DifficultyId } from './types/difficulty'
import { clearedPlanetIds, readClears } from './progress'
import {
  BriefingScreen,
  DebriefScreen,
  DifficultySelect,
  PlaceholderScreen,
  PlanetSelect,
  StartScreen,
} from './ui/screens'
import { SimScreen } from './ui/SimScreen'

type Route =
  | { screen: 'start' }
  | { screen: 'planets' }
  | { screen: 'difficulty'; planetId: string }
  | { screen: 'briefing'; planetId: string; difficultyId: DifficultyId | null }
  | { screen: 'builder'; planetId: string; difficultyId: DifficultyId | null }
  | { screen: 'launch'; planetId: string; difficultyId: DifficultyId | null }
  | { screen: 'sim'; planetId: string; difficultyId: DifficultyId | null }
  | { screen: 'debrief'; planetId: string; difficultyId: DifficultyId | null }

export function App() {
  const [route, setRoute] = useState<Route>({ screen: 'start' })
  const clearedIds = useMemo(() => clearedPlanetIds(readClears()), [route])

  if (route.screen === 'start') {
    return <StartScreen onStart={() => setRoute({ screen: 'planets' })} />
  }

  if (route.screen === 'planets') {
    return (
      <PlanetSelect
        clearedIds={clearedIds}
        onBack={() => setRoute({ screen: 'start' })}
        onTutorial={() => setRoute({ screen: 'briefing', planetId: 'earth', difficultyId: null })}
        onDestination={(planetId) => setRoute({ screen: 'difficulty', planetId })}
      />
    )
  }

  if (route.screen === 'difficulty') {
    return (
      <DifficultySelect
        planetId={route.planetId}
        onBack={() => setRoute({ screen: 'planets' })}
        onPick={(difficultyId) =>
          setRoute({ screen: 'briefing', planetId: route.planetId, difficultyId })
        }
      />
    )
  }

  if (route.screen === 'briefing') {
    return (
      <BriefingScreen
        planetId={route.planetId}
        difficultyId={route.difficultyId}
        onBack={() =>
          route.difficultyId
            ? setRoute({ screen: 'difficulty', planetId: route.planetId })
            : setRoute({ screen: 'planets' })
        }
        onContinue={() =>
          setRoute({ screen: 'builder', planetId: route.planetId, difficultyId: route.difficultyId })
        }
      />
    )
  }

  if (route.screen === 'builder' || route.screen === 'launch') {
    const step = route.screen
    return (
      <PlaceholderScreen
        planetId={route.planetId}
        difficultyId={route.difficultyId}
        step={step}
        onBack={() =>
          step === 'builder'
            ? setRoute({ screen: 'briefing', planetId: route.planetId, difficultyId: route.difficultyId })
            : setRoute({ screen: 'builder', planetId: route.planetId, difficultyId: route.difficultyId })
        }
        onContinue={() =>
          step === 'builder'
            ? setRoute({ screen: 'launch', planetId: route.planetId, difficultyId: route.difficultyId })
            : setRoute({ screen: 'sim', planetId: route.planetId, difficultyId: route.difficultyId })
        }
      />
    )
  }

  if (route.screen === 'sim') {
    return (
      <SimScreen
        planetId={route.planetId}
        difficultyId={route.difficultyId}
        onBack={() =>
          setRoute({ screen: 'launch', planetId: route.planetId, difficultyId: route.difficultyId })
        }
        onFinish={() =>
          setRoute({ screen: 'debrief', planetId: route.planetId, difficultyId: route.difficultyId })
        }
      />
    )
  }

  return (
    <DebriefScreen
      planetId={route.planetId}
      difficultyId={route.difficultyId}
      onAgain={() => setRoute({ screen: 'sim', planetId: route.planetId, difficultyId: route.difficultyId })}
      onPlanets={() => setRoute({ screen: 'planets' })}
    />
  )
}
