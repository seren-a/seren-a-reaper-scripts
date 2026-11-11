# FX Plugin Preset Browser

ReaScript (Lua) für REAPER mit [ReaImGui](https://github.com/cfillion/reaimgui) – Preset- und Parameter-Kontrolle für beliebige FX-Plugins, ohne die FX-Fenster öffnen zu müssen. Standardmäßig auf dearVR-Plugins voreingestellt (per Filter frei konfigurierbar).

## Voraussetzungen

- REAPER 6.75+ (ReaImGui ist ab dieser Version integriert)

## Installation

1. Datei `fx_plugin_preset_browser.lua` in den REAPER-Script-Ordner legen (Options → Show REAPER resource path → `Scripts/`)
2. In REAPER: Actions → Show action list → **Load ReaScript** → Datei auswählen
3. Optional: Tastenkürzel oder Toolbar-Button zuweisen (Action list → Add shortcut / Customize toolbar)

## Fenster

### FX Preset & Parameter Browser
- Folgt automatisch dem fokussierten FX (abschaltbar; das zuletzt gültige FX bleibt sichtbar, wenn das Script-Fenster fokussiert ist)
- Preset-Dropdown (gefiltert nach Ausschlüssen/Regeln)
- Parameter (Slider/Checkboxen/Stufen-Dropdowns + Suchfilter) erst per Toggle **„Parameter anzeigen“** oben einblendbar (Default: aus, persistiert)

### Preset Overview
- Alle Tracks mit FX, die dem Filter entsprechen, untereinander
- Pro Instanz: aktuelles Preset + Dropdown zur direkten Auswahl
- Mehrere FX pro Track werden unterstützt

### Settings
- **FX-Filter:** Komma-getrennte Substrings (Default: `dearVR`), z. B. `dearVR, Reverb`
- **Theme:** `girly`, `dark`, `light`
- **Speichern in:** Global (`reaper-extstate.ini`) oder Projekt (Projekt-ExtState; ohne eigene Projektdaten gelten die globalen)
- **Presets ausschließen:** pro Plugin (z. B. bei „dearVR Pro 2“ einzelne Presets ausblenden) – Klick toggelt, **Drag über die Liste** malt den Zustand auf alle berührten Presets; die volle Liste bleibt sichtbar, Ausgeschlossenes ist also re-aktivierbar
- **Sortierung der Presetliste:** wie gehabt (Preset-Reihenfolge), A-Z, Z-A, neueste zuerst (zuletzt verwendete Presets; wird beim Auswählen in einem Dropdown getrackt) – gilt für die Settings-Liste **und** alle Preset-Dropdowns in Browser/Overview
- **Track-Regeln:** Erste Regel, deren Pattern im Tracknamen vorkommt, gewinnt. Erlaubte Presets als Komma-Liste, leer = alle.

## Bekannte Grenzen

- Presetnamen werden beim ersten Zugriff durch einmaliges Durchschalten ermittelt und gecacht (bei sehr großen Preset-Bibliotheken dauert der erste Aufbau etwas)
- Nur Track-FX, keine Take-FX
- Einstellungen sind global oder pro Projekt, nicht beides gleichzeitig pro Regel

## Einstellungen zurücksetzen

Global: Abschnitt `[fx_plugin_preset_browser]` aus `reaper-extstate.ini` löschen (REAPER vorher schließen).
Projekt: Im Projekt auf „Global“ speichern und die Projekt-ExtState-Daten entfernen.
