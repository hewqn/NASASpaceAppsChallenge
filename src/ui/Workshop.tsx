import { useState, type DragEvent } from 'react'
import { materialById, MATERIALS, type Inventory } from '../data/materials'
import { planetById, difficultyById } from '../data/catalog'
import { designMassKg, stockProblem, type Design } from '../sim/design'
import { kidResult } from '../sim/survival'
import { Frame } from './Frame'

const SIZES = [
  { id: 'fits', label: 'Fits me', shellRadiusM: 0.48, shellThicknessM: 0.0016, insulationThicknessM: 0.012 },
  { id: 'bigger', label: 'A bit bigger', shellRadiusM: 0.55, shellThicknessM: 0.002, insulationThicknessM: 0.012 },
  { id: 'bulky', label: 'Big and heavy', shellRadiusM: 0.7, shellThicknessM: 0.004, insulationThicknessM: 0.02 },
] as const

type Slot = 'shell' | 'wrap' | 'air'

function weightWords(kg: number): string {
  if (kg < 1) return 'Nothing on you yet.'
  if (kg < 20) return 'Light enough to walk in.'
  if (kg < 45) return 'Heavy, like a full suitcase.'
  return 'Very heavy. A bigger suit uses more of what you found.'
}

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
  const problem = stockProblem(design, inventory)
  const moon = planetById('moon')
  const check = difficultyById('normal').minSafetyFactor
  const [picked, setPicked] = useState<string | null>(null)
  const [hint, setHint] = useState('Tap a material, then tap a slot. Or drag it.')
  const [sizeId, setSizeId] = useState<(typeof SIZES)[number]['id']>('fits')

  function applySize(next: (typeof SIZES)[number]['id']) {
    const size = SIZES.find((item) => item.id === next) ?? SIZES[0]
    setSizeId(size.id)
    onChange({
      ...design,
      shellRadiusM: size.shellRadiusM,
      shellThicknessM: size.shellThicknessM,
      insulationThicknessM: size.insulationThicknessM,
    })
  }

  function place(id: string, slot: Slot) {
    const material = materialById(id)
    if (slot === 'air') {
      if (id !== 'oxygen') {
        setHint('Only the red bottles go on Air.')
        return
      }
      onChange({ ...design, oxygenKg: inventory.oxygen ?? 0 })
      setHint('Bottles packed. That is all the air you found.')
      setPicked(null)
      return
    }
    if (slot === 'shell') {
      if (id === 'oxygen') {
        setHint('Bottles go on Air.')
        return
      }
      if (!material.structural) {
        setHint(`${material.name} cannot hold air. Put it on the wrap.`)
        return
      }
      onChange({ ...design, shellMaterialId: id })
      setHint(`${material.name} is the hard shell. It keeps your air in.`)
      setPicked(null)
      return
    }
    if (id === 'oxygen' || material.structural) {
      setHint(id === 'oxygen' ? 'Bottles go on Air.' : `${material.name} is hard. It belongs on the shell.`)
      return
    }
    onChange({ ...design, insulationMaterialId: id })
    setHint(`${material.name} is the wrap. It slows the heat.`)
    setPicked(null)
  }

  function onDrop(event: DragEvent, slot: Slot) {
    event.preventDefault()
    const id = event.dataTransfer.getData('text/plain')
    if (id) place(id, slot)
  }

  const shell = design.shellMaterialId ? materialById(design.shellMaterialId) : null
  const wrap = design.insulationMaterialId ? materialById(design.insulationMaterialId) : null

  return (
    <Frame
      kicker="Earth workshop"
      title="Drag what you found onto the suit."
      lede="Shell holds your air in. Wrap slows the heat. Air is the bottles you take. You never type a size."
      onBack={onBack}
      footer={
        <button className="primary" type="button" onClick={onPlanets} disabled={problem != null}>
          Try this suit on a planet
        </button>
      }
    >
      <div className="bench">
        <div className="pile" aria-label="Materials you found">
          {found.length === 0 ? <p>Go back outside and pick something up.</p> : null}
          {found.map((material) => (
            <button
              key={material.id}
              type="button"
              className={picked === material.id ? 'card picked' : 'card'}
              draggable
              onDragStart={(event) => {
                event.dataTransfer.setData('text/plain', material.id)
                event.dataTransfer.effectAllowed = 'copy'
                setPicked(material.id)
              }}
              onClick={() => {
                setPicked(material.id)
                setHint(`${material.name} selected. Tap Shell, Wrap, or Air.`)
              }}
            >
              <span className="swatch" style={{ background: material.color }} />
              <span>
                <strong>{material.name}</strong>
                <span className="fine">{material.blurb}</span>
              </span>
            </button>
          ))}
        </div>
        <div className="suit-col">
          <div
            className="figure"
            style={{
              outlineColor: wrap?.color ?? 'transparent',
              background: shell?.color ?? '#3a3128',
            }}
          >
            <span className="figure-head" />
            {design.oxygenKg > 0 ? <span className="figure-bottle" /> : null}
          </div>
          <div className="slots">
            <SlotButton
              label="Shell"
              filled={shell?.name ?? 'Empty'}
              active={picked != null}
              onClick={() => picked && place(picked, 'shell')}
              onDrop={(event) => onDrop(event, 'shell')}
              onClear={shell ? () => onChange({ ...design, shellMaterialId: null }) : undefined}
            />
            <SlotButton
              label="Wrap"
              filled={wrap?.name ?? 'Empty'}
              active={picked != null}
              onClick={() => picked && place(picked, 'wrap')}
              onDrop={(event) => onDrop(event, 'wrap')}
              onClear={wrap ? () => onChange({ ...design, insulationMaterialId: null }) : undefined}
            />
            <SlotButton
              label="Air"
              filled={design.oxygenKg > 0 ? 'Bottles packed' : 'Empty'}
              active={picked != null}
              onClick={() => picked && place(picked, 'air')}
              onDrop={(event) => onDrop(event, 'air')}
              onClear={design.oxygenKg > 0 ? () => onChange({ ...design, oxygenKg: 0 }) : undefined}
            />
          </div>
        </div>
      </div>
      <p className="prompt">{hint}</p>
      <div className="sizes" role="group" aria-label="How big is the suit">
        {SIZES.map((size) => (
          <button
            key={size.id}
            type="button"
            className={sizeId === size.id ? 'primary' : 'ghost'}
            onClick={() => applySize(size.id)}
          >
            {size.label}
          </button>
        ))}
      </div>
      <p>{weightWords(designMassKg(design))}</p>
      {problem ? <p className="warn">{problem}</p> : null}
      <div className="preview">
        <p>Same suit, Moon:</p>
        <p>{kidResult(design, moon, check, 'hot')}</p>
        <p>{kidResult(design, moon, check, 'cold')}</p>
      </div>
    </Frame>
  )
}

function SlotButton({
  label,
  filled,
  active,
  onClick,
  onDrop,
  onClear,
}: {
  label: string
  filled: string
  active: boolean
  onClick: () => void
  onDrop: (event: DragEvent) => void
  onClear?: () => void
}) {
  return (
    <div
      className={active ? 'slot ready' : 'slot'}
      onDragOver={(event) => event.preventDefault()}
      onDrop={onDrop}
    >
      <button type="button" onClick={onClick}>
        <strong>{label}</strong>
        <span className="fine">{filled}</span>
      </button>
      {onClear ? (
        <button type="button" className="ghost slot-clear" onClick={onClear}>
          Take off
        </button>
      ) : null}
    </div>
  )
}
