# seren-a-reaper-scripts

> some additional tools, mostly for layouts, midi/osc-control surfaces and ambisonic mixing tools

Sammlung von REAPER-Scripts und -Tools. Jedes Tool liegt in einem eigenen
Ordner unter `tools/` mit eigener README – hier gibt es nur die Übersicht.
Projekt-Kontext für AI-Sessions: [docs/AI-KONTEXT.md](docs/AI-KONTEXT.md).

## Tools

| Tool | Was es tut |
| --- | --- |
| [fx_plugin_preset_browser](tools/fx_plugin_preset_browser/) | ReaScript (Lua) + ReaImGui: Preset- und Parameter-Kontrolle für beliebige FX-Plugins, ohne die FX-Fenster öffnen zu müssen – mit Overview über alle Tracks und Settings (FX-Filter, Preset-Regeln, Themes). |

## Branches (seren.a 3D)

Die Werkzeuge rund um OXI, E16 und Midi Fighter Twister liegen jeweils in einem eigenen Branch, der nur seine Dateien enthält (zum Herunterladen als ZIP oder Klonen von genau einem Werkzeug). Jede Branch-README verweist auf die anderen.

| Branch | Inhalt |
| --- | --- |
| [`oxi-puzzle`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-puzzle) | OXI One MkII als Item-Puzzle in Reaper |
| [`oxi-e16-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-reaper) | OXI E16 in Reaper (MultiEQ, Kompressoren, Hall, Sends) inkl. Twister Bank 4 |
| [`midi-twister-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-reaper) | Midi Fighter Twister in Reaper (Bänke 1–3, Twister View) |
| [`oxi-e16-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-nuendo) | OXI E16 in Nuendo/Cubase |
| [`midi-twister-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-nuendo) | Twister View in Nuendo/Cubase |

Bitwig-Fassungen für E16 und Twister gibt es noch nicht. Moss-Erweiterung der OXI (Reaper und Bitwig): [`oxi-mk2-moss-extended`](https://github.com/seren-a/seren-a_cute-audio-tools/tree/oxi-mk2-moss-extended) in seren-a_cute-audio-tools. TouchOSC-Oberflächen: [osc-remotes/seren-a-3d](https://github.com/seren-a/seren-a_cute-audio-tools/tree/main/tools/osc-remotes/seren-a-3d).

## Struktur

```
seren-a-reaper-scripts/
├── tools/      # eigenständige Tools (je ein Ordner mit Script + eigener README)
├── scripts/    # kleine Einzelskripte ohne eigenen Ordner
├── docs/       # Projekt-Kontext, Notizen
└── LICENSE
```

Neue Scripts kommen direkt in `scripts/`, größere Things bekommen einen
eigenen Ordner unter `tools/` mit einer kurzen README (Zweck, Installation,
Bedienung). Dieser Index hier wird entsprechend ergänzt.

## Lizenz

Siehe [LICENSE](LICENSE).
