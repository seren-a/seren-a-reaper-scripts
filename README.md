# toolbox

> Cubase-ähnliche Toolbox für REAPER · eigener Branch – hier liegen nur die Dateien dieses Tools.
> Gesamtübersicht aller Tools: [`main`-README](https://github.com/seren-a/seren-a-reaper-scripts#tools)

**Taste drücken → Tool ist gearmed → jeder einfache Linksklick (ohne Zusatztaste wie Strg/Alt)
führt die Tool-Aktion aus.** Beispiel: `7` drücken → Mauszeiger wird zum **X** → Klick auf ein
Item (oder eine Spur) toggelt dessen **Mute-Status**. Nochmal `7` (oder `1`) drücken → zurück
auf normales Verhalten.

| Datei | Zweck |
| --- | --- |
| `seren-a_Toolbox.lua` | Hauptskript – hier die Zifferntasten (`1`, `7`, …) als Shortcut zuweisen |
| `seren-a_Toolbox core.lua` | Kern + Konfiguration (`M.KEY_TOOL`, `M.TOOLS`) |
| `seren-a_Toolbox click handler.lua` | interne Action, wird beim Arming in die Maus-Modifikatoren eingetragen |
| `cursors/mute_x.cur` | X-Mauszeiger für das Mute-Tool |

## Voraussetzungen

- **REAPER v7.0+** (nativ `reaper.SetMouseModifier()` / `reaper.GetMouseModifier()`)
- optional **js_ReaScriptAPI** (ReaPack, ReaTeam-Extensions-Repo): eigener Mauszeiger +
  Erkennung der Zifferntaste. Ohne Extension funktioniert das Tool ebenfalls – statt
  Zifferntaste öffnet das Skript dann ein Tool-Menü an der Maus.

## Installation

1. Alle Dateien dieses Branches in den REAPER-Script-Ordner kopieren
   (Options → Show REAPER resource path → `Scripts/`): die drei `.lua`-Dateien und den
   Ordner `cursors/`.
2. Actions → Show action list → **New action… → Load ReaScript…** → `seren-a_Toolbox.lua` laden.
3. Diesem Script in der Main-Sektion Shortcuts zuweisen, z. B. Ziffern `1` und `7`.

## Bedienung

- **`7`** drücken → Mute-Tool gearmed (X-Cursor, Toolbar-Button leuchtet). Jeder einfache
  Linksklick toggelt Mute des Items bzw. der Spur unter der Maus; Drags verschieben keine
  Items. Jeder Klick ist **ein Undo-Schritt**.
- **Nochmal `7` oder `1`** drücken → Tool aus; deine eigenen Maus-Modifikatoren werden
  exakt wiederhergestellt.
- **Toolbar-Button** statt Taste: Klick ohne erkannte Ziffer → Tool-Menü an der Maus.
- **Eigene Tools/Tasten:** in `seren-a_Toolbox core.lua` `M.KEY_TOOL` und `M.TOOLS`
  anpassen (ein `delete`-Tool liegt als auskommentierte Vorlage bei).

## Wie es funktioniert

- REAPER kennt keine Tools, sondern Maus-Modifikatoren. Beim Arming werden die
  **unmodifizierten** Linksklick-Slots (`MM_CTX_ITEM_CLK`, `MM_CTX_TRACK_CLK`,
  `MM_CTX_ARRANGE_MMOUSE_CLK`, Modifier-Flag `0`) per `SetMouseModifier` auf den
  Klick-Handler gesetzt; Item-/Arrange-Drag wird auf „No action“ gesetzt. Vorher wird pro
  Slot der Originalzustand gesichert (`GetMouseModifier`, persistent in ExtState-Sektion
  `seren-a_toolbox`) und beim Entschalten wiederhergestellt – inkl. Readback-Check.
- **Mauszeiger:** per js_ReaScriptAPI `JS_WindowMessage_Intercept(main, "WM_SETCURSOR", false)`
  (REAPERs eigener Cursor-Wechsel wird blockiert) + `JS_Mouse_SetCursor` mit eigener `.cur`
  (`JS_Mouse_LoadCursorFromFile`, Fallback IDC_CROSS = 32515). Beim Entschalten
  `JS_WindowMessage_Release` + Pfeil (IDC_ARROW = 32512).
- Steht REAPER nach einem Neustart noch auf einem Tool: einfach `1` drücken – die Backups
  liegen persistent im ExtState und werden dann wiederhergestellt.

Hinweis: Das Klick-Handler-Skript landet beim ersten Arming automatisch in der Action-Liste
(Main-Sektion). Das ist beabsichtigt – die Maus-Modifikatoren verweisen darauf.

## Verwandte Branches

Jedes Werkzeug hat einen eigenen Branch. Hier liegen nur seine Dateien; die Gesamtübersicht
steht im [`main`-README](https://github.com/seren-a/seren-a-reaper-scripts#branches-seren-a-3d).

| Branch | Inhalt |
| --- | --- |
| [`main`](https://github.com/seren-a/seren-a-reaper-scripts/tree/main) | Sammlung: `tools/` (fx_plugin_preset_browser, track_fx_helpers, theme_adjuster, toolbox), `scripts/` |
| [`oxi-puzzle`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-puzzle) | OXI One MkII als Item-Puzzle in Reaper |
| [`oxi-e16-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-reaper) | OXI E16 in Reaper |
| [`midi-twister-reaper`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-reaper) | Midi Fighter Twister in Reaper |
| [`oxi-e16-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/oxi-e16-nuendo) | OXI E16 in Nuendo/Cubase |
| [`midi-twister-nuendo`](https://github.com/seren-a/seren-a-reaper-scripts/tree/midi-twister-nuendo) | Twister View in Nuendo/Cubase |
