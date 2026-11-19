-- seren-a_Toolbox core.lua
-- Kern der Toolbox. Wird von "seren-a_Toolbox.lua" (Taste/Menü) und
-- "seren-a_Toolbox click handler.lua" (Maus-Modifikator) per dofile() geladen.
-- Nicht direkt als Action ausführen.
--
-- Idee (Cubase-ähnlich): REAPER hat keine "Tools", sondern Maus-Modifikatoren.
-- Solange ein Tool gearmed ist, werden die *unmodifizierten* Linksklick-Slots
-- (Modifier-Flag 0) auf den Klick-Handler umgebogen bzw. Drags auf "No action"
-- geschaltet. Beim Entschalten stellen wir die ursprünglichen Werte wieder her.
-- Ab REAPER v7.0 geht das nativ über reaper.SetMouseModifier()/GetMouseModifier().

local r = reaper
local M = {}

M.dir = debug.getinfo(1, "S").source:match("^@?(.*[/\\])") or ""

-- ========== Konfiguration ==========
-- Taste -> Tool. Ziffern oben (0-9) oder Numpad. Ohne js_ReaScriptAPI kann das
-- Hauptskript keine Taste erkennen und öffnet stattdessen das Tool-Menü.
M.KEY_TOOL = {
  ["1"] = "select",
  ["7"] = "mute",
  -- ["8"] = "delete", -- Beispiel für ein weiteres Tool (siehe M.TOOLS)
}

-- Reihenfolge der Tools im Menü
M.TOOL_ORDER = { "select", "mute" }

-- Tool-Definitionen:
--   label       Anzeige im Menü
--   cursor_file eigene .cur-Datei (relativ zum Toolbox-Ordner), braucht js_ReaScriptAPI
--   cursor_fb   Fallback-Cursor-ID (Windows-IDC, z. B. 32515 = IDC_CROSS)
--   on_click    "mute" | "delete" - wird im Klick-Handler ausgewertet
--   slots       Maus-Modifikator-Slots, die gearmed werden:
--                 ctx     Kontext (MM_CTX_* wie in reaper-mouse.ini)
--                 mod     Modifier-Flag (0 = keine Zusatztaste!)
--                 handler = true  -> Klick-Handler-Skript
--                 id / name       -> eingebaute Aktion (id 0 = "No action")
M.TOOLS = {
  select = {
    label = "Auswählen (Standard)",
    slots = {}, -- keine Slots = alles zurücksetzen
  },
  mute = {
    label = "Stummschalten (Mute)",
    cursor_file = "cursors/mute_x.cur",
    cursor_fb = 32515, -- IDC_CROSS
    on_click = "mute",
    slots = {
      { ctx = "MM_CTX_ITEM_CLK",           mod = 0, handler = true }, -- Klick auf Item
      { ctx = "MM_CTX_TRACK_CLK",          mod = 0, handler = true }, -- Klick auf Spur
      { ctx = "MM_CTX_ARRANGE_MMOUSE_CLK", mod = 0, handler = true }, -- Klick leerer Arrange-Bereich
      { ctx = "MM_CTX_ITEM",               mod = 0, id = 0 },         -- Drag auf Item: No action
      { ctx = "MM_CTX_ARRANGE_MMOUSE",     mod = 0, id = 0 },         -- Drag leerer Arrange: No action
    },
  },
  -- Eigenes Tool als Vorlage:
  -- delete = {
  --   label = "Löschen",
  --   on_click = "delete",
  --   slots = {
  --     { ctx = "MM_CTX_ITEM_CLK", mod = 0, handler = true },
  --     { ctx = "MM_CTX_ITEM",     mod = 0, id = 0 },
  --   },
  -- },
}

-- ========== State (alles an einem Ort) ==========
-- ExtState-Sektion "seren-a_toolbox". Backups persistent speichern, damit auch
-- nach einem REAPER-Neustart (Mouse-Modifiers stehen dann noch auf dem Tool)
-- mit Taste "1" wieder zurückgeschaltet werden kann.
M.SECT = "seren-a_toolbox"

local function store(key, val) r.SetExtState(M.SECT, key, val, true) end
local function recall(key) return r.GetExtState(M.SECT, key) end
local function drop(key) r.DeleteExtState(M.SECT, key, true) end

local function active_id()
  local id = recall("active")
  if id ~= "" and M.TOOLS[id] then return id end
  return nil
end

-- ========== Maus-Modifikatoren: Backup & Restore ==========
local function slot_key(ctx, mod) return ctx .. "|" .. mod end

local function backup_slot(ctx, mod)
  local key = slot_key(ctx, mod)
  for k in recall("backup_list"):gmatch("[^;]+") do
    if k == key then return end -- Originalwert nur einmal sichern
  end
  local val = r.GetMouseModifier(ctx, mod)
  if val == "" then val = "-1" end
  store("bk|" .. key, val)
  local list = recall("backup_list")
  store("backup_list", (list == "" and "" or list .. ";") .. key)
end

local function restore_all()
  for key in recall("backup_list"):gmatch("[^;]+") do
    local ctx, mod = key:match("^(.*)|(%-?%d+)$")
    if ctx then r.SetMouseModifier(ctx, tonumber(mod), recall("bk|" .. key) or "-1") end
    drop("bk|" .. key)
  end
  drop("backup_list")
end

-- ========== Maus-Modifikatoren anwenden (mit Readback-Check) ==========
local function norm(s)
  s = tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return (s:gsub("%s+[mcMC]$", ""))
end

-- Klick-Handler als Action registrieren und seine Command-ID zurückgeben
function M.handler_action()
  local named = recall("handler_cmd")
  if named ~= "" and r.NamedCommandLookup("_" .. named) ~= 0 then return "_" .. named end
  local path = M.dir .. "seren-a_Toolbox click handler.lua"
  if not r.file_exists(path) then return nil end
  local cmd = r.AddRemoveReaScript(true, 0, path, true)
  if not cmd or cmd == 0 then return nil end
  named = r.ReverseNamedCommandLookup(cmd)
  if not named or named == "" then return nil end
  store("handler_cmd", named)
  return "_" .. named
end

local function apply_slot(slot)
  local mod = slot.mod or 0
  backup_slot(slot.ctx, mod)
  local action
  if slot.handler then
    action = M.handler_action()
  elseif slot.name then
    action = slot.name
  else
    action = tostring(slot.id or 0) .. " m"
  end
  if not action then return "Klick-Handler fehlt (" .. M.dir .. ")" end
  -- Sentinel zuerst setzen, damit REAPER die Zuweisung auf jeden Fall übernimmt,
  -- dann per Readback prüfen, ob REAPER sie akzeptiert hat.
  r.SetMouseModifier(slot.ctx, mod, "0 m")
  r.SetMouseModifier(slot.ctx, mod, action)
  local now, want = norm(r.GetMouseModifier(slot.ctx, mod)), norm(action)
  local ok
  if want:match("^%-?%d+$") then
    ok = (now == want)
  elseif want:sub(1, 1) == "_" then
    ok = (now == want or tonumber(now) == r.NamedCommandLookup(want))
  else
    ok = (now ~= "" and now ~= "0")
  end
  if not ok then
    return slot.ctx .. ": '" .. action .. "' abgelehnt (ist jetzt: '" ..
      tostring(r.GetMouseModifier(slot.ctx, mod)) .. "')"
  end
  return nil
end

-- ========== Mauszeiger (braucht js_ReaScriptAPI, sonst nur Funktionsweise) ==========
local IDC_ARROW = 32512

local function set_tool_cursor(tool)
  if not (r.JS_Mouse_SetCursor and r.JS_WindowMessage_Intercept) then return end
  local main = r.GetMainHwnd()
  r.JS_WindowMessage_Intercept(main, "WM_SETCURSOR", false) -- REAPERs Cursor-Wechsel blocken
  local cur
  if tool and tool.cursor_file and r.JS_Mouse_LoadCursorFromFile then
    cur = r.JS_Mouse_LoadCursorFromFile(M.dir .. tool.cursor_file)
  end
  if not cur and r.JS_Mouse_LoadCursor then
    cur = r.JS_Mouse_LoadCursor((tool and tool.cursor_fb) or IDC_ARROW)
  end
  if cur then r.JS_Mouse_SetCursor(cur) end
end

local function reset_cursor()
  if not (r.JS_Mouse_SetCursor and r.JS_WindowMessage_Release) then return end
  r.JS_WindowMessage_Release(r.GetMainHwnd(), "WM_SETCURSOR")
  if r.JS_Mouse_LoadCursor then
    local cur = r.JS_Mouse_LoadCursor(IDC_ARROW)
    if cur then r.JS_Mouse_SetCursor(cur) end
  end
end

-- ========== Tool armen / entschalten ==========
local function refresh_toggle(sect, cmd, on)
  if cmd and cmd ~= 0 and r.SetToggleCommandState then
    r.SetToggleCommandState(sect or 0, cmd, on and 1 or 0)
    r.RefreshToolbar2(sect or 0, cmd)
  end
end

function M.arm(tool_id, sect, cmd)
  local tool = M.TOOLS[tool_id]
  if not tool then return end
  if active_id() == tool_id then return M.disarm(sect, cmd) end -- dieselbe Taste nochmal = aus
  restore_all() -- vorheriges Tool zurücksetzen
  local problems = {}
  for _, slot in ipairs(tool.slots) do
    local err = apply_slot(slot)
    if err then problems[#problems + 1] = err end
  end
  store("active", tool_id)
  if tool_id == "select" then reset_cursor() else set_tool_cursor(tool) end
  refresh_toggle(sect, cmd, true)
  if #problems > 0 then r.ShowConsoleMsg("Toolbox:\n" .. table.concat(problems, "\n") .. "\n") end
end

function M.disarm(sect, cmd)
  restore_all()
  store("active", "")
  reset_cursor()
  refresh_toggle(sect, cmd, false)
end

-- ========== Tastenerkennung (braucht js_ReaScriptAPI) ==========
-- Liefert die gerade gedrückte Ziffer ("0"-"9") oder nil.
function M.pressed_digit()
  if not r.JS_VKeys_GetState then return nil end
  local state = r.JS_VKeys_GetState(r.time_precise() - 2)
  if not state or #state < 0x6A then return nil end
  for vk = 0x30, 0x39 do -- Ziffernreihe 0-9
    if state:byte(vk) ~= 0 then return string.char(vk) end
  end
  for vk = 0x60, 0x69 do -- Numpad 0-9
    if state:byte(vk) ~= 0 then return tostring(vk - 0x60) end
  end
  return nil
end

-- ========== Tool-Menü (Fallback ohne Tastenerkennung / bei Toolbar-Klick) ==========
function M.show_menu(sect, cmd)
  local items = {}
  for _, id in ipairs(M.TOOL_ORDER) do
    items[#items + 1] = M.TOOLS[id].label
  end
  local mx, my = r.GetMousePosition()
  gfx.init("Toolbox", 0, 0, 0, mx, my)
  gfx.x, gfx.y = gfx.screentoclient(mx, my)
  local choice = gfx.showmenu(table.concat(items, "|"))
  gfx.quit()
  if choice >= 1 and choice <= #M.TOOL_ORDER then
    M.arm(M.TOOL_ORDER[choice], sect, cmd)
  end
end

-- ========== Klick-Handler (läuft als Maus-Modifikator-Action) ==========
-- Rückgabe 1 = Klick ist verbraucht (keine normale Auswahl/Marquee),
-- Rückgabe 0 = nichts gearmed, REAPER macht das Übliche.
function M.handle_click()
  local id = active_id()
  if not id or id == "select" then return 0 end
  local tool = M.TOOLS[id]
  local mx, my = r.GetMousePosition()
  local item
  if r.GetItemFromPoint then item = r.GetItemFromPoint(mx, my, true) end
  if not item and r.BR_ItemAtMouseCursor then item = r.BR_ItemAtMouseCursor() end -- SWS-Fallback
  local track = r.GetTrackFromPoint and r.GetTrackFromPoint(mx, my)

  local what, ptr
  if item and (tool.on_click == "mute" or tool.on_click == "delete") then
    what, ptr = "item", item
  elseif track and tool.on_click == "mute" then
    what, ptr = "track", track
  end
  if not what then return 1 end -- Klick verbrauchen, aber nichts ändern

  r.Undo_BeginBlock()
  if what == "item" and tool.on_click == "mute" then
    local m = r.GetMediaItemInfo_Value(ptr, "B_MUTE")
    r.SetMediaItemInfo_Value(ptr, "B_MUTE", m == 1 and 0 or 1)
  elseif what == "track" then
    local m = r.GetMediaTrackInfo_Value(ptr, "B_MUTE")
    r.SetMediaTrackInfo_Value(ptr, "B_MUTE", m == 1 and 0 or 1)
  elseif what == "item" and tool.on_click == "delete" then
    r.DeleteTrackMediaItem(r.GetMediaItem_Track(ptr), ptr)
  end
  r.Undo_EndBlock("Toolbox: " .. tool.label, -1)
  r.UpdateArrange()
  return 1
end

return M
