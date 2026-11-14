import { useMemo } from 'react'
import { materialById, MATERIALS, type Inventory } from '../data/materials'
import { planetById, difficultyById } from '../data/catalog'
import {
  designMassKg,
  insulationMassKg,
  shellMassKg,
  stockProblem,
  type Design,
} from '../sim/design'
import { previewLine } from '../sim/survival'
import { Frame } from './Frame'

export function Workshop({
  design,
  inventory,
  onChange,
  onBack,
  onPlanets,
}: {
  design: Design
  inventory: Inventory
  onChange: (design: Design) => void
  onBack: () => void
  onPlanets: () => void
}) {
  const found = MATERIALS.filter((material) => (inventory[material.id] ?? 0) > 0)
  const structural = found.filter((material) => material.structural)
  const wraps = found.filter((material) => !material.structural && material.id !== 'oxygen')
  const problem = stockProblem(design, inventory)
  const moon = planetById('moon')
  const normal = difficultyById('normal')
  const preview = useMemo(
    () => [previewLine(design, moon, normal, 'hot'), previewLine(design, moon, normal, 'cold')],
    [design, moon, normal],
  )

  return (
    <Frame
      kicker="Earth workshop"
      title="Build from what you found."
      lede="Your core wants to stay near 37 °C, and your lungs want Earth oxygen. A shell holds pressure. A wrap slows the heat. Bottles are the air you take with you."
      onBack={onBack}
      footer={
        <button className="primary" type="button" onClick={onPlanets} disabled={problem != null}>
          Choose a planet
        </button>
      }
    >
      <p className="fine">
        {found.length === 0
          ? 'You have not picked anything up yet.'
          : found.map((material) => `${material.name}: ${inventory[material.id]} kg`).join(' · ')}
      </p>
      <label className="field">
        Pressure shell
        <select
          value={design.shellMaterialId ?? ''}
          onChange={(event) => onChange({ ...design, shellMaterialId: event.target.value || null })}
        >
          <option value="">No shell</option>
          {structural.map((material) => (
            <option key={material.id} value={material.id}>
              {material.name}
            </option>
          ))}
        </select>
      </label>
      <div className="split">
        <label className="field">
          Radius (m)
          <input
            type="number"
            min={0.4}
            max={1}
            step={0.05}
            value={design.shellRadiusM}
            onChange={(event) => onChange({ ...design, shellRadiusM: Number(event.target.value) })}
          />
        </label>
        <label className="field">
          Wall (m)
          <input
            type="number"
            min={0.001}
            max={0.05}
            step={0.001}
            value={design.shellThicknessM}
            onChange={(event) => onChange({ ...design, shellThicknessM: Number(event.target.value) })}
          />
        </label>
      </div>
      <label className="field">
        Insulation wrap
        <select
          value={design.insulationMaterialId ?? ''}
          onChange={(event) =>
            onChange({ ...design, insulationMaterialId: event.target.value || null })
          }
        >
          <option value="">No wrap</option>
          {wraps.map((material) => (
            <option key={material.id} value={material.id}>
              {material.name}
            </option>
          ))}
        </select>
      </label>
      <label className="field">
        Wrap thickness (m)
        <input
          type="number"
          min={0.005}
          max={0.08}
          step={0.005}
          value={design.insulationThicknessM}
          onChange={(event) =>
            onChange({ ...design, insulationThicknessM: Number(event.target.value) })
          }
        />
      </label>
      <label className="field">
        Oxygen to pack (kg)
        <input
          type="number"
          min={0}
          max={inventory.oxygen ?? 0}
          step={0.1}
          value={design.oxygenKg}
          onChange={(event) => onChange({ ...design, oxygenKg: Number(event.target.value) })}
        />
      </label>
      <p>
        Suit mass {designMassKg(design).toFixed(1)} kg
        {design.shellMaterialId
          ? ` · shell ${shellMassKg(design).toFixed(1)} kg ${materialById(design.shellMaterialId).name}`
          : ''}
        {design.insulationMaterialId
          ? ` · wrap ${insulationMassKg(design).toFixed(1)} kg`
          : ''}
      </p>
      {problem ? <p className="warn">{problem}</p> : null}
      <div className="preview">
        <p>Twenty minutes on the Moon, if you left now:</p>
        {preview.map((line) => (
          <p key={line}>{line}</p>
        ))}
      </div>
    </Frame>
  )
}
