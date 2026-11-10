# seren-a-reaper-scripts

> some additional tools, mostly for layouts, midi/osc-control surfaces and ambisonic mixing tools

Sammlung von REAPER-Scripts und -Tools. Jedes Tool liegt in einem eigenen
Ordner unter `tools/` mit eigener README – hier gibt es nur die Übersicht.
Projekt-Kontext für AI-Sessions: [docs/AI-KONTEXT.md](docs/AI-KONTEXT.md).

## Tools

| Tool | Was es tut |
| --- | --- |
| [fx_plugin_preset_browser](tools/fx_plugin_preset_browser/) | ReaScript (Lua) + ReaImGui: Preset- und Parameter-Kontrolle für beliebige FX-Plugins, ohne die FX-Fenster öffnen zu müssen – mit Overview über alle Tracks und Settings (FX-Filter, Preset-Regeln, Themes). |

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
