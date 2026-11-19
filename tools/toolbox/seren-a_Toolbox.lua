-- @description Toolbox: Cubase-ähnliche Tools per Taste arming (z. B. 7 = Mute: X-Cursor, Klick toggelt Mute ohne Zusatztaste)
-- @author seren.a
-- @about
--   Arming eines "Tools" wie in Cubase, ohne dass eine Zusatztaste (Strg/Alt/...) nötig ist:
--   Taste drücken (z. B. 7) -> Mauszeiger wechselt auf das Tool-Symbol (X) -> jeder einfache
--   Linksklick führt die Tool-Aktion aus (Mute toggeln). Erneutes Drücken derselben Taste
--   oder Taste 1 schaltet zurück auf normales Verhalten.
--
--   Keys und Tools konfigurierbar in "seren-a_Toolbox core.lua" (M.KEY_TOOL / M.TOOLS).
--   Wird das Skript ohne erkennbare Zifferntaste ausgeführt (z. B. Toolbar-Button),
--   öffnet es ein Tool-Menü an der Maus.
--
--   Voraussetzungen: REAPER v7.0+ (SetMouseModifier/GetMouseModifier).
--   js_ReaScriptAPI (ReaPack) optional, aber empfohlen: eigener Mauszeiger + Tastenerkennung.
--   Ohne js_ReaScriptAPI funktioniert das Tool trotzdem, nur Menü statt Zifferntasten.

local _, file, sect, cmd = reaper.get_action_context()
local dir = file:match("^(.*[/\\])") or ""
local core = dofile(dir .. "seren-a_Toolbox core.lua")

local key = core.pressed_digit()
if key and core.KEY_TOOL[key] then
  core.arm(core.KEY_TOOL[key], sect, cmd)
else
  core.show_menu(sect, cmd)
end
