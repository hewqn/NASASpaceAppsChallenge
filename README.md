# CODAG.0: Can Our Design Actually Go?

**2026 NASA Space Apps Challenge** | Team UNAC | University of Calgary

A Roblox game where players design survival suits from real engineering materials and test them on planets across the solar system. Every planet uses real NASA data. Every material has real physical properties. The game teaches players that space exploration is an engineering problem with no single right answer. Your suit has to handle the actual temperatures, pressures, and atmospheres that NASA has measured.

## What It Does

You start in a space station orbiting Earth. Around you are storage racks holding 13 real materials: metals like aluminum and titanium, insulators like aerogel and Mylar, and an oxygen tank. You pick them up and layer them onto a suit in any order you choose, at four thickness options (thin, medium, thick, heavy). Then you choose a destination (the Moon, Mars, Mercury, Venus, Jupiter, Saturn, Uranus, or Neptune) and the game simulates whether your suit keeps you alive for 20 minutes.

The simulation checks:

- **Temperature**: Heat flows through every layer of your suit based on each material's real thermal conductivity. On Venus (737 K surface), you need serious insulation. On Neptune (72 K at 1 bar), you need to keep heat in.
- **Pressure**: The outermost structural layer must withstand the pressure difference. Venus has 92 bars of surface pressure. The Moon has effectively zero.
- **Oxygen**: If there's no breathable atmosphere (and there isn't, anywhere but Earth), you need enough bottled oxygen for the mission.
- **Crush/gravity**: Each planet has its real surface gravity. Your suit has mass. You have to be able to move.

Each planet has a "hot side" and a "cold side" landing option, reflecting real diurnal temperature ranges from NASA data. The game gives you a plain-language survival prediction before you launch ("Hot side: you would cook" or "Cold side: you'd freeze"), and then runs a second-by-second simulation during the mission.

## How It Works

The game has three layers:

**Data layer** (`src/shared/Data/`): Planet properties are transcribed directly from NASA's NSSDC Planetary Fact Sheets. Each value carries a `transcribedFrom` field quoting the exact line from the fact sheet it came from, and a `sourceUrl` linking to that planet's page. Material properties (density, yield strength, thermal conductivity, melting point) come from standard engineering references. The game validates at startup that every planet has a valid NSSDC source URL, gravity, and solar irradiance.

**Simulation layer** (`src/shared/Sim/`): A physics engine models heat transfer through layered spherical shells, pressure containment, oxygen consumption, and suit mass. It uses SI units throughout. Key equations:
- Thermal resistance per layer: thickness / (conductivity * surface area)
- Pressure containment: yield stress * wall thickness / radius
- Suit mass: density * shell volume for each layer
- Mylar's conductivity drops from 0.155 to 0.001 W/m-K in vacuum (real MLI behavior)

The simulation runs for 1200 seconds (20 minutes) with a 5-second time step.

**Game layer** (`src/server/`, `src/client/`): A Roblox experience built with Rojo. The server generates a procedural space station environment, handles player sessions, and runs authoritative simulation. The client renders the workshop UI, planet selection, and mission HUD. Communication uses RemoteEvents (State, Ready, Debrief, AddLayer, RemoveLayer, SetOxygen, Depart, Abort).

### Difficulty Modes

- **Easy**: 1.5x mass/cost budget, live survival preview, starter parts
- **Normal**: Standard budgets, meter warnings, full catalog, one solar event during mission
- **Hard**: 0.75x budget, higher safety margin, no preview, three attempts max, events every 45 seconds

## What Makes It Creative

Most space education games give you preset ships or binary pass/fail missions. CODAG.0 gives you a box of real materials and says "figure it out." There's no tutorial that tells you aerogel is the best insulator. You learn that by trying wool on Venus and watching it burn. You learn that carbon fiber is strong and light but doesn't insulate. You learn that Mylar is almost useless in an atmosphere but extraordinary in vacuum.

The game also doesn't simplify the planets. Venus really does have 92 bars of surface pressure and a surface temperature of 737 K. Jupiter really doesn't have a surface, so you're at the 1-bar level. Neptune's scale height is a range, not a single number, because that's what NASA's data says. We didn't round, average, or simplify these numbers.

## Tools and Technologies

- **Roblox Studio**: Game engine and platform
- **Rojo**: File-system to Roblox sync, enabling version-controlled Luau development
- **Luau**: Roblox's typed scripting language (all game code)
- **TypeScript + Vite**: Data pipeline for exporting planet/material JSON to Roblox-compatible Luau modules
- **Node.js**: Build tooling and data export scripts
- **Claude AI (Anthropic)**: Used for code generation, debugging, and procedural environment design (space station, material shapes, terrain generation). All AI-generated code was reviewed and integrated by the team.
- **Sketchfab**: Planet textures sourced from Sketchfab (Creative Commons licensed models).

## NASA Data Used

All planetary data is sourced from NASA's National Space Science Data Center (NSSDC) Planetary Fact Sheets. The specific values used per planet include: surface/1-bar gravity (m/s2), surface/reference pressure (Pa), solar irradiance (W/m2), black-body temperature (K), surface/1-bar temperatures (K), scale height (m), mean molecular weight (kg/mol), atmospheric density (kg/m3), atmospheric composition (% by volume), escape velocity (m/s), day length (s), semimajor axis (AU), mass (kg), and equatorial radius (m).

Conversions applied are only unit changes the fact sheets already state: km to m, hours/days to s, km/s to m/s, millibar/bar to Pa (1 bar = 100,000 Pa), g/mol to kg/mol.

| Body | Fact Sheet URL |
|---------|--------------------------------------------------|
| Earth | https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html |
| Moon | https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html |
| Mercury | https://nssdc.gsfc.nasa.gov/planetary/factsheet/mercuryfact.html |
| Venus | https://nssdc.gsfc.nasa.gov/planetary/factsheet/venusfact.html |
| Mars | https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html |
| Jupiter | https://nssdc.gsfc.nasa.gov/planetary/factsheet/jupiterfact.html |
| Saturn | https://nssdc.gsfc.nasa.gov/planetary/factsheet/saturnfact.html |
| Uranus | https://nssdc.gsfc.nasa.gov/planetary/factsheet/uranusfact.html |
| Neptune | https://nssdc.gsfc.nasa.gov/planetary/factsheet/neptunefact.html |

Reference pages:
- Fact Sheet Index: https://nssdc.gsfc.nasa.gov/planetary/planetfact.html
- Parameter Notes (1-bar gravity for giant planets): https://nssdc.gsfc.nasa.gov/planetary/factsheet/planetfact_notes.html
- Fact Notes: https://nssdc.gsfc.nasa.gov/planetary/factsheet/fact_notes.html

Jupiter, Saturn, Uranus, and Neptune use mean gravity at the 1-bar level. Their fact sheets list surface pressure as ">>1000 bars" and do not locate a solid surface, so the simulation places the player at 1 bar. Neptune's scale height and mean molecular weight are stored as the printed ranges, not single values.

No NASA images, logos, mission patches, or branding are used in this project.

## Material Properties

13 materials with real-world physical properties:

**Structural** (can hold pressure):
| Material | Density (kg/m3) | Yield (MPa) | Conductivity (W/m-K) | Melting (K) | Source |
|---|---|---|---|---|---|
| Aluminum (6061-T6) | 2,700 | 276 | 167 | 855 | Engineering handbooks |
| Steel (mild) | 7,850 | 250 | 50 | 1,700 | Engineering handbooks |
| Titanium (Ti-6Al-4V) | 4,507 | 880 | 21.9 | 1,941 | Engineering handbooks |
| Carbon Fiber (CFRP) | 1,600 | 600 | 7 | 3,800 | Composite data sheets |
| Copper (pure) | 8,960 | 210 | 401 | 1,358 | Engineering handbooks |
| Borosilicate Glass | 2,230 | 70 | 1.14 | 1,920 | Pyrex specifications |

**Insulation** (slows heat, cannot hold pressure):
| Material | Density (kg/m3) | Conductivity (W/m-K) | Melting (K) | Source |
|---|---|---|---|---|
| Aerogel (silica) | 150 | 0.015 | 1,400 | Aerogel blanket specs |
| Wool Batting | 300 | 0.04 | 450 | Textile references |
| Polyurethane Foam | 32 | 0.026 | 420 | Rigid PU foam specs |
| Mylar Film (PET) | 1,390 | 0.155 (vacuum: 0.001) | 527 | MLI performance data |
| Fiberglass | 2,500 | 0.035 | 1,400 | Glass fiber blanket specs |
| Kevlar (Kevlar 49) | 1,440 | 0.04 | 770 | Aramid fiber data sheets |

**Life Support**:
| Material | Notes |
|---|---|
| Oxygen Tank | 2 kg per tank, roughly two days of breathing at NASA life-support rates |

## SI Usage Disclosure

Claude AI (Anthropic) was used for:
- Code generation and debugging of Luau game scripts
- Procedural generation of the space station environment and material display shapes
- Data pipeline assistance (TypeScript export scripts)
- README and documentation writing

All AI-generated code was reviewed, tested, and integrated by team members. No AI-generated images or audio are included in the project.

## Project Structure

```
NASASpaceAppsChallenge/
  roblox/
    default.project.json          # Rojo project config
    src/
      server/
        init.server.luau          # Server: sessions, missions, world generation
        World.luau                # Procedural space station + planet terrain
      client/
        init.client.luau          # Client: UI, workshop, planet selection
      shared/
        Data/
          Planets.luau            # NASA fact sheet data (9 bodies)
          Materials.luau          # 13 materials with real physics properties
          Catalog.luau            # Lookup + validation functions
          Difficulty.luau         # Easy/Normal/Hard mode configs
          Sources.luau            # NASA URLs + destination order
        Sim/
          Design.luau             # Layer-based suit design system
          Survival.luau           # Thermal/pressure/oxygen simulation
          Human.luau              # Human body constants
  src/                            # TypeScript data pipeline
  scripts/                       # Build/export scripts
  package.json                   # Node.js dependencies
```

## Running the Project

### Roblox (the game)

Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) and the Rojo Studio plugin. Then:

```bash
npm install
npm run export:roblox
rojo serve roblox/default.project.json
```

In Roblox Studio, connect the Rojo plugin. Press Play. Walk to the storage racks, pick up materials, build your suit at the workbench, choose a destination, and try to survive.

### Browser experiment

The browser-based data viewer in the repo root still runs with:

```bash
npm install
npm test
npm run dev
```

## License

See [LICENSE](LICENSE).
