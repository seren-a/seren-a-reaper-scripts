# AI-Kontext: REAPER-Script-Projekt

Diese Datei liefert neuen AI-Sessions (Agent im VS Code o. Ä.) den nötigen Projekt-Kontext. Der Code selbst liegt im Repo – hier steht nur, was nicht aus dem Code ersichtlich ist.

## Projekt

- Repo: `seren-a/seren-a-reaper-scripts` (privat)
- Struktur: Sammlungs-Repo – pro Tool ein Ordner unter `tools/` mit Script-Datei + eigener README, kleine Einzelskripte in `scripts/`
- Aktuelles Tool: `tools/fx_plugin_preset_browser/fx_plugin_preset_browser.lua`

## Arbeitsweise (bitte beibehalten)

- Pro Aufgabe (Issue) ein Branch: `issue-N-kurzbeschreibung`
- Kleine Commits mit ehrlichen Nachrichten
- PR auf `main`, vor dem Merge „Files changed“ reviewen
- Im PR-Text `Closes #N` für das zugehörige Issue
- Nutzer lernt strukturiertes Arbeiten/Programmieren: kleine Schritte, saubere Struktur (kleine Funktionen, Sektionen mit Kommentar-Bannern, State an einem Ort), Erklärungen dazu sind willkommen

## Script: FX Plugin Preset Browser

ReaScript (Lua) + ReaImGui für REAPER 6.75+. Drei Fenster:

- **Browser:** folgt fokussiertem FX (abschaltbar), Parameter als Slider/Checkboxen/Stufen-Combos, Preset-Dropdown, Parameter-Suchfilter
- **Overview:** alle Tracks mit FX, die dem FX-Filter entsprechen, mit Preset-Dropdowns pro Instanz
- **Settings:** FX-Filter (Komma-Substrings, Default `dearVR`), Preset-Ausschlüsse pro Plugin, Track-Regeln (erste Match gewinnt, erlaubte Presets als Komma-Liste, leer = alle), Themes (girly/dark/light), Speicherung Global (ExtState) oder Projekt (Projekt-ExtState mit Fallback)

Einstellungen werden serialisiert als Zeilen (`FILTER:` / `EXCL:` / `RULE:`) in der ExtState-Sektion `fx_plugin_preset_browser` bzw. im Projekt-ExtState.

## Technische Fallstricke (bereits gelöst – nicht rückgängig machen)

- `ImGui_SetNextWindowSize` heißt die Funktion (nicht `SetNextSize`)
- Farbkonstanten version-unabhängig auflösen: `r["ImGui_Col_X"]`, falls Funktion dann einmalig aufrufen (`ResolveTheme()`)
- Push/Pop von StyleColors muss pro Frame exakt ausbalanciert sein (`pushed_colors`-Zähler)
- Presetnamen werden durch Durchschalten ermittelt (`GetPresetNames`, gecacht)
- Projekt-ExtState mit Fallback: `SetProjExtState`/`GetProjExtState` (älter) oder `GetSetProjectExtState` (neuer)

## Offene Issues (Roadmap, aufsteigende Schwierigkeit)

1. #2 Presetnamen lazy laden statt beim Start durchzuschalten
2. #3 Track-Regeln: Presets ausschließen statt nur erlauben
3. #4 Overview: Alle Instanzen eines FX auf ein Preset setzen (mit Undo)
4. #5 Take-FX unterstützen
