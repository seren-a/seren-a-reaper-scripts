# midi-twister-reaper

> Teil von seren.a 3D · Stand v8.15 (10.11.26), E16/Twister v8.11.1 · nur in Simulation getestet, nicht an echter Hardware

Midi Fighter Twister in Reaper: Bänke 1–3 und die Twister View (TouchOSC am Handy, 5 Looks). **Bank 4** (MultiEQ, Kompressoren, Hall, Sends) macht `Reaper_E16_Twister.lua` aus [`oxi-e16-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-reaper).

| Datei | wofür |
| --- | --- |
| `Reaper_Twister.lua` | Hub für Bänke 1–3 und die View, läuft dauerhaft |
| `Twister_Bank4_MultiEQ.mfs` | Midi Fighter Utility: auf den Twister schreiben (nur Bank 4 geändert) |
| `Twister-View-TouchOSC/` | die Oberfläche fürs Handy (hoch und quer) |
| `quellen/` | Quelltext, Bauskript, Tests (`reaper_mft_hub.lua` ist die Quelle von `Reaper_Twister.lua`) |

Bitwig: gibt es für den Twister noch nicht.

## Verwandte Branches

Jedes Werkzeug hat einen eigenen Branch. Hier liegen nur seine Dateien, die Gesamtübersicht steht im [`main`-README](https://github.com/seren-a/seren-a-reaper-scripts#branches-seren-a-3d).

| Branch | Inhalt |
| --- | --- |
| [`oxi-puzzle`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-puzzle) | OXI One MkII Puzzle (Reaper-Lua) |
| [`oxi-e16-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-reaper) | OXI E16 in Reaper |
| [`oxi-e16-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-nuendo) | OXI E16 in Nuendo/Cubase |
| [`midi-twister-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-nuendo) | Midi Fighter Twister in Nuendo/Cubase |
| [`oxi-mk2-moss-extended`](https://github.com/seren-a/seren-a_cute-audio-tools/tree/oxi-mk2-moss-extended) | OXI One MkII in DrivenByMoss (Reaper + Bitwig) |

Die TouchOSC-Oberflächen (iPad, Monitor, Handy) und `Reaper_3D.lua` liegen in [seren-a_cute-audio-tools › osc-remotes/seren-a-3d](https://github.com/seren-a/seren-a_cute-audio-tools/tree/main/tools/osc-remotes/seren-a-3d).
