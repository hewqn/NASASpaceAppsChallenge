import { useCallback, useMemo, useState } from 'react'
import type { DifficultyId } from './types/difficulty'
import { emptyInventory, materialById, type Inventory } from './data/materials'
import { emptyDesign, type Design } from './sim/design'
import type { Side, Vitals } from './sim/survival'
import { survived } from './sim/survival'
import { clearedPlanetIds, readClears, recordClear } from './progress'
import { EarthScreen } from './ui/EarthScreen'
import { Workshop } from './ui/Workshop'
import { SurvivalScreen } from './ui/SurvivalScreen'
import { BriefingScreen, DebriefScreen, DifficultySelect, PlanetSelect, StartScreen } from './ui/screens'

type Route =
  | { screen: 'start' }
  | { screen: 'earth' }
  | { screen: 'workshop' }
  | { screen: 'planets' }
  | { screen: 'difficulty'; planetId: string }
  | { screen: 'briefing'; planetId: string; difficultyId: DifficultyId }
  | { screen: 'survive'; planetId: string; difficultyId: DifficultyId; side: Side }
  | { screen: 'debrief'; planetId: string; difficultyId: DifficultyId; side: Side; vitals: Vitals }

export function App() {
  const [route, setRoute] = useState<Route>({ screen: 'start' })
  const [inventory, setInventory] = useState<Inventory>(emptyInventory)
  const [design, setDesign] = useState<Design>(emptyDesign)
  const [clearTick, setClearTick] = useState(0)
  const clearedIds = useMemo(() => clearedPlanetIds(readClears()), [clearTick, route])

  const collect = useCallback((materialId: string) => {
    setInventory((current) => {
      if ((current[materialId] ?? 0) > 0) return current
      return { ...current, [materialId]: materialById(materialId).foundKg }
    })
  }, [])

  if (route.screen === 'start') {
    return <StartScreen onStart={() => setRoute({ screen: 'earth' })} />
  }
  if (route.screen === 'earth') {
    return <EarthScreen inventory={inventory} onCollect={collect} onWorkshop={() => setRoute({ screen: 'workshop' })} />
  }
  if (route.screen === 'workshop') {
    return (
      <Workshop
        design={design}
        inventory={inventory}
        onChange={setDesign}
        onBack={() => setRoute({ screen: 'earth' })}
        onPlanets={() => setRoute({ screen: 'planets' })}
      />
    )
  }
  if (route.screen === 'planets') {
    return (
      <PlanetSelect
        clearedIds={clearedIds}
        onBack={() => setRoute({ screen: 'workshop' })}
        onDestination={(planetId) => setRoute({ screen: 'difficulty', planetId })}
      />
    )
  }
  if (route.screen === 'difficulty') {
    return (
      <DifficultySelect
        planetId={route.planetId}
        onBack={() => setRoute({ screen: 'planets' })}
        onPick={(difficultyId) => setRoute({ screen: 'briefing', planetId: route.planetId, difficultyId })}
      />
    )
  }
  if (route.screen === 'briefing') {
    return (
      <BriefingScreen
        planetId={route.planetId}
        difficultyId={route.difficultyId}
        onBack={() => setRoute({ screen: 'difficulty', planetId: route.planetId })}
        onDepart={(side) =>
          setRoute({ screen: 'survive', planetId: route.planetId, difficultyId: route.difficultyId, side })
        }
      />
    )
  }
  if (route.screen === 'survive') {
    return (
      <SurvivalScreen
        planetId={route.planetId}
        difficultyId={route.difficultyId}
        design={design}
        side={route.side}
        onBack={() =>
          setRoute({ screen: 'briefing', planetId: route.planetId, difficultyId: route.difficultyId })
        }
        onFinish={(vitals) => {
          if (survived(vitals)) {
            recordClear({ planetId: route.planetId, difficultyId: route.difficultyId })
            setClearTick((tick) => tick + 1)
          }
          setRoute({
            screen: 'debrief',
            planetId: route.planetId,
            difficultyId: route.difficultyId,
            side: route.side,
            vitals,
          })
        }}
      />
    )
  }
  return (
    <DebriefScreen
      planetId={route.planetId}
      difficultyId={route.difficultyId}
      side={route.side}
      vitals={route.vitals}
      onAgain={() =>
        setRoute({
          screen: 'survive',
          planetId: route.planetId,
          difficultyId: route.difficultyId,
          side: route.side,
        })
      }
      onWorkshop={() => setRoute({ screen: 'workshop' })}
      onEarth={() => setRoute({ screen: 'earth' })}
    />
  )
}
