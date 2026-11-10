# oxi-e16-reaper

> Teil von seren.a 3D · Stand v8.15 (10.11.26), E16/Twister v8.11.1 · nur in Simulation getestet, nicht an echter Hardware

OXI E16 in Reaper (ReaScript Lua): MultiEQ, Kompressoren, Hall und Sends/Ziele auf allen Seiten. Das Skript bedient auch Bank 4 des Midi Fighter Twisters, deshalb gehört [`midi-twister-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-reaper) dazu.

| Datei | wofür |
| --- | --- |
| `Reaper_E16_Twister.lua` | E16 und Twister Bank 4 (v8.11.1), läuft dauerhaft |
| `Reaper_E16_Einstellungen.lua` | Einstellungsfenster (Pegelgrenzen, Farben, Push, Reaper-Konsole) |
| `Reaper_E16_Ziele_zuweisen.lua` | Send-Ziele festlegen |
| `E16-Szene/` | `seren-a_E16.oxie16` für die OXI App, Anleitung der Szene |
| `LIESMICH_E16_Twister.md` | Anleitung |
| `quellen/` | Quelltext, Bauskript und Tests |

Bitwig: gibt es für die E16 noch nicht.

## Verwandte Branches

Jedes Werkzeug hat einen eigenen Branch. Hier liegen nur seine Dateien, die Gesamtübersicht steht im [`main`-README](https://github.com/seren-a/seren-a-reaper-scripts#branches-seren-a-3d).

| Branch | Inhalt |
| --- | --- |
| [`oxi-puzzle`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-puzzle) | OXI One MkII Puzzle (Reaper-Lua) |
| [`midi-twister-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-reaper) | Midi Fighter Twister in Reaper |
| [`oxi-e16-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-nuendo) | OXI E16 in Nuendo/Cubase |
| [`midi-twister-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-nuendo) | Midi Fighter Twister in Nuendo/Cubase |
| [`oxi-mk2-moss-extended`](https://github.com/seren-a/seren-a_cute-audio-tools/tree/oxi-mk2-moss-extended) | OXI One MkII in DrivenByMoss (Reaper + Bitwig) |

Die TouchOSC-Oberflächen (iPad, Monitor, Handy) und `Reaper_3D.lua` liegen in [seren-a_cute-audio-tools › osc-remotes/seren-a-3d](https://github.com/seren-a/seren-a_cute-audio-tools/tree/main/tools/osc-remotes/seren-a-3d).
