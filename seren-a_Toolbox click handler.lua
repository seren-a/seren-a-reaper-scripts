-- @description Toolbox-Klick-Handler (intern - wird von der Toolbox in die Maus-Modifikatoren eingetragen)
-- @author seren.a
-- @about
--   Interne Action: Sobald ein Tool gearmed ist, verweist die Toolbox die unmodifizierten
--   Linksklick-Slots (MM_CTX_ITEM_CLK / MM_CTX_TRACK_CLK / MM_CTX_ARRANGE_MMOUSE_CLK) auf
--   dieses Skript. Es liest das aktive Tool aus dem ExtState und führt die Aktion aus
--   (z. B. Mute des Items/Spur unter der Maus toggeln). Nicht manuell ausführen.

local _, file = reaper.get_action_context()
local dir = file:match("^(.*[/\\])") or ""
local core = dofile(dir .. "seren-a_Toolbox core.lua")

return core.handle_click()
