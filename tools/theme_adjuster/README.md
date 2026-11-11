# Theme Adjuster

`.ReaperTheme`-Dateien direkt in REAPER anpassen – ohne Hex-/Dezimal-Rätselraten.
Lua + ReaImGui, REAPER 6.75+.

## Zweck

REAPER-Theme-Dateien sind reine Textdateien mit kryptischen Keys und Zahlen
(`col_mi_bg2=-2142419646`, `itembg_drawmode=196608` …). Der Theme Adjuster
übersetzt das in eine GUI (im Dark-Pastel-Pink-Stil, angelehnt an die
VS-Code-Themes „Huacat Pink“ und „Dark Pastel Pink“):

- **Theme-Dropdown** – listet alle `.ReaperTheme`-Dateien aus dem
  ColorThemes-Ordner (`.ReaperThemeZip` wird nicht unterstützt, vorher entpacken)
- **Deutsche Beschreibungen** statt Keys: „Item: Hintergrund“, „TCP: Text der
  ausgewählten Spur“, „MCP: FX-Kette, Hintergrund (bypassed)" …
- **Klar getrennte Tabs** nach Verwendungsort: Items & Arrange, TCP, MCP,
  Fenster & UI, MIDI-Editor, Hüllkurven, Marker & Ruler, VU-Meter,
  Gruppenfarben, Sonstige
- **RGBA-Farbpicker** – negative Werte (Alpha-Kanal) werden korrekt zerlegt,
  Alpha wird im Tooltip angezeigt
- **Draw-Modus zerlegt** – Werte wie `itembg_drawmode` werden aufgeteilt in
  Modus (Deckend/Alpha-Blend), Deckkraft (Alpha 0–255) und Flags, statt eine
  mysteriöse Zahl anzuzeigen
- **Presets direkt im GUI** – speichern/anwenden/löschen (REAPER ExtState,
  dauerhaft pro REAPER-Installation)
- **Suche** über Key und Beschreibung
- **Sicher**: vor dem ersten Speichern wird automatisch eine
  `.theme_adjuster.bak`-Backup-Datei angelegt; alle nicht angefassten Zeilen
  (inkl. Kommentare, Fonts, `ui_img`) bleiben byte-genau erhalten

## Installation

1. ReaImGui installieren (ReaPack: „ReaScript: ReaImGui bindings“)
2. `theme_adjuster.lua` über *Actions → Load ReaScript* laden
3. Optional: Toolbar-Button zuweisen

## Bedienung

1. Theme im Dropdown wählen (das zuletzt gewählte wird gemerkt)
2. Werte in den Tabs anpassen – die Statuszeile zeigt ungespeicherte Änderungen
3. **Speichern** schreibt die Datei, **Speichern unter …** legt eine Kopie als
   neues Theme an
4. Damit REAPER die Änderungen anzeigt: *Options → Themes* – Theme kurz auf ein
   anderes Theme schalten und zurück (REAPER liest die Datei erst beim Auswählen)
5. Rechtsklick auf einen Wert setzt ihn auf den Ausgangswert zurück

Presets speichern den kompletten `[color theme]`-Block des geladenen Themes
und lassen sich auf jedes andere Theme anwenden (nur Keys, die dort existieren).

## Hinweise

- Draw-Modus-Dekodierung (Modus/Alpha/Flags) ist eine Best-Effort-Zerlegung der
  von REAPER verwendeten Bitmasken; der Rohwert steht im Tooltip
- Fonts und `ui_img` im `[REAPER]`-Block sind binäre Blobs und werden nur
  angezeigt (nicht editierbar)
- Unbekannte Keys neuerer Themes landen unter „Sonstige“ und bleiben editierbar
