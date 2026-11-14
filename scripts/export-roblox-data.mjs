import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const outDir = resolve(root, 'roblox/src/shared/Data')

function emitString(value) {
  return `"${value
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r')}"`
}

function emit(value, indent) {
  const pad = '  '.repeat(indent)
  if (value === null || value === undefined) return 'nil'
  if (typeof value === 'boolean') return value ? 'true' : 'false'
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : 'nil'
  if (typeof value === 'string') return emitString(value)
  if (Array.isArray(value)) {
    if (value.length === 0) return '{}'
    const lines = value.map((item) => `${pad}  ${emit(item, indent + 1)},`)
    return `{\n${lines.join('\n')}\n${pad}}`
  }
  const lines = Object.entries(value).map(([key, item]) => {
    const name = /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? key : `[${emitString(key)}]`
    return `${pad}  ${name} = ${emit(item, indent + 1)},`
  })
  return `{\n${lines.join('\n')}\n${pad}}`
}

function writeModule(fileName, sourceNote, jsonName) {
  const data = JSON.parse(readFileSync(resolve(root, jsonName), 'utf8'))
  const body = `-- ${sourceNote}\nreturn ${emit(data, 0)}\n`
  writeFileSync(resolve(outDir, fileName), body)
}

mkdirSync(outDir, { recursive: true })
writeModule('Planets.luau', 'Generated from src/data/planets.json. Edit the JSON, then run npm run export:roblox.', 'src/data/planets.json')
writeModule('Materials.luau', 'Generated from src/data/materials.json. Edit the JSON, then run npm run export:roblox.', 'src/data/materials.json')
writeModule('Difficulty.luau', 'Generated from src/data/difficulty.json. Edit the JSON, then run npm run export:roblox.', 'src/data/difficulty.json')
console.log('wrote roblox data modules')
