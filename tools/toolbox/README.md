# toolbox

Cubase-ähnliche Toolbox für REAPER: **Taste drücken → Tool ist gearmed → jeder einfache
Linksklick (ohne Zusatztaste wie Strg/Alt) führt die Tool-Aktion aus.**

Beispiel: `7` drücken → Mauszeiger wird zum **X** → Klick auf ein Item (oder eine Spur)
toggelt dessen **Mute-Status**. Nochmal `7` (oder `1`) drücken → zurück auf normales Verhalten.

| Datei | Zweck |
| --- | --- |
| `seren-a_Toolbox.lua` | Hauptskript – hier die Zifferntasten (`1`, `7`, …) als Shortcut zuweisen |
| `seren-a_Toolbox core.lua` | Kern + Konfiguration (`M.KEY_TOOL`, `M.TOOLS`) |
| `seren-a_Toolbox click handler.lua` | interne Action, wird beim Arming in die Maus-Modifikatoren eingetragen |
| `cursors/mute_x.cur` | X-Mauszeiger für das Mute-Tool |

## Voraussetzungen

- **REAPER v7.0+** (nativ `reaper.SetMouseModifier()` / `reaper.GetMouseModifier()`)
- optional **js_ReaScriptAPI** (ReaPack, kommt aus dem ReaTeam-Extensions-Repo):
  eigener Mauszeiger + Erkennung der Zifferntaste. Ohne Extension funktioniert das Tool
  ebenfalls – statt Zifferntaste öffnet das Skript dann ein Tool-Menü an der Maus.

## Installation

1. Den kompletten Ordner `toolbox/` in den REAPER-Script-Ordner kopieren
   (Options → Show REAPER resource path → `Scripts/`), z. B. `Scripts/toolbox/`.
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
  `seren-a_toolbox`) und beim Entschalten wiederhergestellt – inkl. Readback-Check, ob
  REAPER die Zuweisung akzeptiert hat.
- **Mauszeiger:** per js_ReaScriptAPI `JS_WindowMessage_Intercept(main, "WM_SETCURSOR", false)`
  (REAPERs eigener Cursor-Wechsel wird blockiert) + `JS_Mouse_SetCursor` mit eigener `.cur`
  (`JS_Mouse_LoadCursorFromFile`, Fallback IDC_CROSS = 32515). Beim Entschalten
  `JS_WindowMessage_Release` + Pfeil (IDC_ARROW = 32512).
- Steht REAPER nach einem Neustart noch auf einem Tool: einfach `1` drücken – die Backups
  liegen persistent im ExtState und werden dann wiederhergestellt.

Hinweis: Das Klick-Handler-Skript landet beim ersten Arming automatisch in der Action-Liste
(Main-Sektion). Das ist beabsichtigt – die Maus-Modifikatoren verweisen darauf.

## Siehe auch

- Community-Alternativen: [KallumS/Reaper-Right-Click-Toolbar](https://github.com/KallumS/Reaper-Right-Click-Toolbar)
  (Tool-Menü per Rechtsklick, 14 Tools), [Aced107/ReaFL](https://github.com/Aced107/ReaFL)
  (FL-Style-Tools). Reine Maus-Modifikatoren ohne Skript: Preferences → Editing Behavior →
  Mouse Modifiers (dort gehen aber nur Klick-*mit* Zusatztaste als „Tool“-Ersatz sauber).
