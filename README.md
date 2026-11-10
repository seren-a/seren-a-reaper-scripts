# oxi-puzzle

> Teil von seren.a 3D · Stand v8.15 (10.11.26), E16/Twister v8.11.1 · nur in Simulation getestet, nicht an echter Hardware

OXI One MkII als Item-Puzzle in Reaper (ReaScript Lua + ReaImGui): Items, Regionen und Marker als Pads, Sends, Display, Menü, Spurtasten mit Mute/Solo/Rec.

| Datei | wofür |
| --- | --- |
| `Reaper_OXI_Puzzle.lua` | das Skript (v8.12.3), in die Aktionsliste laden, läuft dauerhaft, wenn DrivenByMoss die OXI gerade nicht hat |
| `Reaper_OXI_Einstellungen.lua` | Einstellungsfenster |
| `LIESMICH_OXI.md` | Anleitung |
| `quellen/` | Quelltext (`core.lua` + `font.lua`, `build.py` baut das Skript), Tests, geparkte Launchpad-Insert-Seite in `wip_launchpad_insert/` |

Puzzle und DrivenByMoss gleichzeitig geht nicht, siehe `LIESMICH_OXI.md`.

## Verwandte Branches

Jedes Werkzeug hat einen eigenen Branch. Hier liegen nur seine Dateien, die Gesamtübersicht steht im [`main`-README](https://github.com/seren-a/seren-a-reaper-scripts#branches-seren-a-3d).

| Branch | Inhalt |
| --- | --- |
| [`oxi-e16-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-reaper) | OXI E16 in Reaper |
| [`midi-twister-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-reaper) | Midi Fighter Twister in Reaper |
| [`oxi-e16-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-nuendo) | OXI E16 in Nuendo/Cubase |
| [`midi-twister-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-nuendo) | Midi Fighter Twister in Nuendo/Cubase |
| [`oxi-mk2-moss-extended`](https://github.com/seren-a/seren-a_cute-audio-tools/tree/oxi-mk2-moss-extended) | OXI One MkII in DrivenByMoss (Reaper + Bitwig) |

Die TouchOSC-Oberflächen (iPad, Monitor, Handy) und `Reaper_3D.lua` liegen in [seren-a_cute-audio-tools › osc-remotes/seren-a-3d](https://github.com/seren-a/seren-a_cute-audio-tools/tree/main/tools/osc-remotes/seren-a-3d).
