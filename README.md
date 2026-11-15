# CODAG.0

A Roblox mission game. You start on Earth, pick up materials, and drag them onto a suit. Then you try to last twenty minutes on another planet. Gravity in the place is the fact-sheet gravity scaled to the Roblox avatar. Temperature, pressure, oxygen, and crush are checked in SI units.

Portions of this project were written with Cursor AI.

## Play in Roblox Studio

Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) and the Rojo Studio plugin. Then, from this folder:

```bash
npm run export:roblox
rojo serve roblox/default.project.json
```

In Studio, connect the plugin. Press Play. Walk to a colored pile, pick it up, and drag it onto Shell, Wrap, or Air. The same suit shows a plain result for every planet. The Moon is the first one you can walk on.

The browser experiment in the repo root still runs with `npm install`, `npm test`, and `npm run dev`. The Roblox place is the game.


## NASA data this build uses

Planet numbers are copied from the NSSDC fact sheets and cached in [`src/data/planets.json`](src/data/planets.json). The briefing links each stat to that body’s page. Conversions are only of units the sheet already states: kilometers to meters, hours or days to seconds, km/s to m/s, millibar or bar to pascal (1 bar = 100000 Pa, 1 mb = 100 Pa), and mean molecular weight from g/mol to kg/mol.

- Index: https://nssdc.gsfc.nasa.gov/planetary/planetfact.html
- Notes (1 bar gravity for the giant planets): https://nssdc.gsfc.nasa.gov/planetary/factsheet/planetfact_notes.html
- Parameter notes: https://nssdc.gsfc.nasa.gov/planetary/factsheet/fact_notes.html
- Earth: https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
- Moon: https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html
- Mercury: https://nssdc.gsfc.nasa.gov/planetary/factsheet/mercuryfact.html
- Venus: https://nssdc.gsfc.nasa.gov/planetary/factsheet/venusfact.html
- Mars: https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html
- Jupiter: https://nssdc.gsfc.nasa.gov/planetary/factsheet/jupiterfact.html
- Saturn: https://nssdc.gsfc.nasa.gov/planetary/factsheet/saturnfact.html
- Uranus: https://nssdc.gsfc.nasa.gov/planetary/factsheet/uranusfact.html
- Neptune: https://nssdc.gsfc.nasa.gov/planetary/factsheet/neptunefact.html

Jupiter, Saturn, Uranus, and Neptune use mean gravity at the 1 bar level. Their fact sheets list surface pressure as `>>1000 bars` and do not locate a solid surface, so a probe starts at 1 bar. Neptune’s scale height and mean molecular weight are stored as the printed ranges, not a single guessed value.

No NASA images, logos, or mission patches are in this build. Horizons, CubeSat 101, and the mission-design PDF are not used.
