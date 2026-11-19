-- fx_plugin_preset_browser.lua
-- ReaScript (Lua) + ReaImGui
-- 3 Fenster: Browser / Overview / Settings
-- Benoetigt REAPER 6.75+

local r = reaper
local EXT_SECTION = "fx_plugin_preset_browser"

----------------------------------------------------------------
-- Settings (persistent via ExtState)
----------------------------------------------------------------
local settings = {
  fx_filters = "dearVR",
  excluded   = {},
  rules      = {},
  sort_mode  = "default",  -- default | az | za | newest
  last_used  = {},         -- "fxname<TAB>presetname" -> os.time()
  quick_params = "",       -- Komma-getrennte Parameter-Substrings fuer Quick-Anzeige
  trackname_template = "{preset}",  -- Platzhalter fuer den Umbenennen-Button
  dedupe    = false,       -- Duplikate (gleicher Presetname) ausblenden
  dup_pref  = "plugin",    -- bevorzugter Preset-Typ bei Duplikaten: "plugin" | "reaper"
}

local settings_scope = r.GetExtState(EXT_SECTION, "scope")
if settings_scope ~= "project" then settings_scope = "global" end

-- REAPER-Funktionen liefern mehrere Rueckgabewerte (z. B. integer retval,
-- string value). Nimm immer den String-Rueckgabewert, egal welche Version.
local function PickStr(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" then return v end
  end
  return ""
end

local function ReadStore(scope, key)
  if scope == "project" then
    if r.GetSetProjectExtState then
      -- 5. Parameter setNewValue=false -> Lesen, liefert retval + value
      return PickStr(r.GetSetProjectExtState(0, EXT_SECTION, key, "", false))
    end
    if r.GetProjExtState then
      -- liefert integer retval + string value (aeltere Versionen: nur string)
      return PickStr(r.GetProjExtState(0, EXT_SECTION, key))
    end
    return ""
  end
  return PickStr(r.GetExtState(EXT_SECTION, key))
end

local function WriteStore(scope, key, val)
  if scope == "project" then
    if r.SetProjExtState then
      r.SetProjExtState(0, EXT_SECTION, key, val)
    elseif r.GetSetProjectExtState then
      -- 5. Parameter setNewValue=true -> wirklich schreiben
      r.GetSetProjectExtState(0, EXT_SECTION, key, val, true)
    end
  else
    r.SetExtState(EXT_SECTION, key, val, true)
  end
end

local function LoadSettings(scope)
  local s = ReadStore(scope, "settings")
  settings.fx_filters = "dearVR"
  settings.excluded = {}
  settings.rules = {}
  settings.sort_mode = "default"
  settings.last_used = {}
  settings.quick_params = ""
  settings.trackname_template = "{preset}"
  settings.dedupe = false
  settings.dup_pref = "plugin"
  if type(s) ~= "string" or s == "" then return end
  for line in s:gmatch("([^\n]*)\n?") do
    if line:find("^FILTER:") then
      settings.fx_filters = line:sub(#"FILTER:" + 1)
    elseif line:find("^EXCL:") then
      local fxn, presets = line:sub(#"EXCL:" + 1):match("^([^\t]*)\t(.*)$")
      if fxn then
        settings.excluded[fxn] = {}
        for p in (presets or ""):gmatch("[^|]+") do
          settings.excluded[fxn][p] = true
        end
      end
    elseif line:find("^RULE:") then
      local pat, allowed = line:sub(#"RULE:" + 1):match("^([^\t]*)\t(.*)$")
      if pat then
        table.insert(settings.rules, { pattern = pat, allowed = allowed or "" })
      end
    elseif line:find("^SORT:") then
      local m = line:sub(#"SORT:" + 1)
      if m == "az" or m == "za" or m == "newest" or m == "default" then settings.sort_mode = m end
    elseif line:find("^QP:") then
      settings.quick_params = line:sub(#"QP:" + 1)
    elseif line:find("^TPL:") then
      settings.trackname_template = line:sub(#"TPL:" + 1)
    elseif line:find("^DEDUP:") then
      settings.dedupe = line:sub(#"DEDUP:" + 1) == "1"
    elseif line:find("^PREF:") then
      local m = line:sub(#"PREF:" + 1)
      if m == "plugin" or m == "reaper" then settings.dup_pref = m end
    elseif line:find("^USED:") then
      local fxn, p, ts = line:sub(#"USED:" + 1):match("^([^\t]*)\t([^\t]*)\t(.*)$")
      if fxn and p then settings.last_used[fxn .. "\t" .. p] = tonumber(ts) or 0 end
    end
  end
end

local function SaveSettings(settings_scope)
  local t = { "FILTER:" .. settings.fx_filters, "SORT:" .. settings.sort_mode, "QP:" .. settings.quick_params, "TPL:" .. settings.trackname_template, "DEDUP:" .. (settings.dedupe and "1" or "0"), "PREF:" .. settings.dup_pref }
  for fxn, presets in pairs(settings.excluded) do
    local lst = {}
    for p in pairs(presets) do table.insert(lst, p) end
    if #lst > 0 then
      table.insert(t, "EXCL:" .. fxn .. "\t" .. table.concat(lst, "|"))
    end
  end
  for _, rule in ipairs(settings.rules) do
    table.insert(t, "RULE:" .. rule.pattern .. "\t" .. rule.allowed)
  end
  for key, ts in pairs(settings.last_used) do
    local fxn, p = key:match("^([^\t]*)\t(.*)$")
    if fxn and p then table.insert(t, "USED:" .. fxn .. "\t" .. p .. "\t" .. tostring(ts)) end
  end
  WriteStore(settings_scope, "settings", table.concat(t, "\n"))
end

LoadSettings(settings_scope)


----------------------------------------------------------------
-- State
----------------------------------------------------------------
local ctx
local show_browser   = true
local show_overview  = true
local show_settings  = false
local win_collapsed  = {}  -- merkt eingeklappte Fenster (Re-Expand -> Groesse restaurieren)
local follow_focused = true
local selected_track_idx = 0
local selected_fx_idx    = 0
local param_filter    = ""
local preset_cache    = {}
local excl_sel_fxname = ""
local excl_drag       = nil  -- Drag-Malen in Settings: Zielwert true/false
local show_params     = r.GetExtState(EXT_SECTION, "show_params") == "1"
local apply_to_all    = r.GetExtState(EXT_SECTION, "apply_to_all") == "1"
local show_paramlist  = false
local pl_filter       = ""
----------------------------------------------------------------
-- Themes
----------------------------------------------------------------
-- Farben als 0xRRGGBBAA (ReaImGui-Lua-Format: Alpha ist das LETZTE Byte,
-- Doku: "Color is in 0xRRGGBBAA"). Alpha FF = voll deckend (nicht durchsichtig).
local themes = {
  girly = {
    { "Col_WindowBg", 0x2B1233FF },        -- #2B1233 dunkles Pink-Magenta
    { "Col_PopupBg", 0x3A1840FF },         -- #3A1840
    { "Col_FrameBg", 0x5E2A6EFF },         -- #5E2A6E
    { "Col_FrameBgHovered", 0x86419CFF },  -- #86419C
    { "Col_TitleBgActive", 0xFF4FA3FF },   -- #FF4FA3
    { "Col_Button", 0xFF5CB0FF },          -- #FF5CB0
    { "Col_ButtonHovered", 0xFF8FC9FF },   -- #FF8FC9
    { "Col_ButtonActive", 0xFFC0E0FF },    -- #FFC0E0
    { "Col_SliderGrab", 0xFF9ED2FF },      -- #FF9ED2
    { "Col_SliderGrabActive", 0xFFD3ECFF },-- #FFD3EC
    { "Col_Header", 0xFF5CB0FF },          -- #FF5CB0
    { "Col_HeaderHovered", 0xFF8FC9FF },   -- #FF8FC9
    { "Col_CheckMark", 0xFFD3ECFF },       -- #FFD3EC
    { "Col_Text", 0xFFF0F7FF },            -- #FFF0F7
    { "Col_Separator", 0xE070B8FF },       -- #E070B8
  },
  dark = {
    { "Col_WindowBg", 0x221420FF },        -- #221420 Pflaumen-dunkel
    { "Col_PopupBg", 0x2A1A28FF },         -- #2A1A28
    { "Col_FrameBg", 0x3A2438FF },         -- #3A2438
    { "Col_FrameBgHovered", 0x4A2E48FF },  -- #4A2E48
    { "Col_TitleBgActive", 0xC96BA8FF },   -- #C96BA8
    { "Col_Button", 0xC96BA8FF },          -- #C96BA8
    { "Col_ButtonHovered", 0xE08CC0FF },   -- #E08CC0
    { "Col_ButtonActive", 0xF0B4D4FF },    -- #F0B4D4
    { "Col_SliderGrab", 0xF0B4D4FF },      -- #F0B4D4
    { "Col_Header", 0xC96BA8FF },          -- #C96BA8
    { "Col_HeaderHovered", 0xE08CC0FF },   -- #E08CC0
    { "Col_CheckMark", 0xF0B4D4FF },       -- #F0B4D4
  },
  light = {
    { "Col_WindowBg", 0xF4E6EEFF },        -- #F4E6EE
    { "Col_PopupBg", 0xF4E6EEFF },         -- #F4E6EE
    { "Col_FrameBg", 0xE0C0D0FF },         -- #E0C0D0
    { "Col_FrameBgHovered", 0xECD0DDFF },  -- #ECD0DD
    { "Col_Text", 0x3A1A2AFF },            -- #3A1A2A
    { "Col_Button", 0xE75480FF },          -- #E75480
    { "Col_ButtonHovered", 0xFF7BA9FF },   -- #FF7BA9
    { "Col_ButtonActive", 0xFF9FC4FF },    -- #FF9FC4
    { "Col_Header", 0xE75480FF },          -- #E75480
    { "Col_HeaderHovered", 0xFF7BA9FF },   -- #FF7BA9
    { "Col_CheckMark", 0xE75480FF },       -- #E75480
    { "Col_SliderGrab", 0xE75480FF },      -- #E75480
    { "Col_Separator", 0xC89AA8FF },       -- #C89AA8
  },
}
local theme_order = { "girly", "dark", "light" }
local current_theme = r.GetExtState(EXT_SECTION, "theme")
if current_theme == "" or not themes[current_theme] then current_theme = "girly" end

local resolved_theme = {}

local function ResolveTheme()
  resolved_theme = {}
  local cols = themes[current_theme] or themes.girly
  for _, c in ipairs(cols) do
    local idx = r["ImGui_" .. c[1]]
    if type(idx) == "function" then idx = idx() end
    if type(idx) == "number" then
      table.insert(resolved_theme, { idx, c[2] })
    end
  end
end

local pushed_colors = 0

local function ApplyTheme()
  pushed_colors = 0
  for _, c in ipairs(resolved_theme) do
    r.ImGui_PushStyleColor(ctx, c[1], c[2])
    pushed_colors = pushed_colors + 1
  end
end

local function PopTheme()
  for _ = 1, pushed_colors do
    r.ImGui_PopStyleColor(ctx)
  end
  pushed_colors = 0
end

ResolveTheme()



----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function GetFilters()
  local out = {}
  for f in settings.fx_filters:gmatch("[^,]+") do
    f = f:gsub("^%s+", ""):gsub("%s+$", "")
    if #f > 0 then table.insert(out, f:lower()) end
  end
  return out
end

local function FXMatches(fxname)
  if not fxname then return false end
  local lower = fxname:lower()
  for _, f in ipairs(GetFilters()) do
    if lower:find(f, 1, true) then return true end
  end
  return false
end

local function GetPresetNames(track, fx)
  -- TrackFX_GetPresetIndex liefert 2 Werte: (curidx, numberOfPresets)
  local cur_idx, count = r.TrackFX_GetPresetIndex(track, fx)
  if not count or count <= 0 then return nil end
  local key = r.GetTrackGUID(track) .. "|" .. fx .. "|" .. count
  if preset_cache[key] then return preset_cache[key] end

  -- Namen durch einmaliges Durchschalten ermitteln (ein Undo-Schritt).
  -- Der Ausgangszustand wird danach VERIFIZIERT wiederhergestellt:
  -- erst Parameter-Schnappschuss per SetParam, dann ggf. Preset-Index
  -- (SetParam wuerde cur_idx sonst auf -1 setzen), anschliessend Vergleich
  -- mit bis zu 3 Nachbesserungs-Runden - so bleibt auch bei API-Quirks
  -- (z. B. REAPER 7.x) kein FX auf einem falschen Preset/Parameter stehen.
  local nparams = r.TrackFX_GetNumParams(track, fx)
  local snapshot = {}
  for p = 0, nparams - 1 do
    local _, v = r.TrackFX_GetParam(track, fx, p)
    snapshot[p] = v
  end
  local names, types, files = {}, {}, {}
  local max_presets = 2048  -- Sicherheits-Cap gegen Endlos-Presets
  local n = math.min(count, max_presets)
  r.Undo_BeginBlock()
  for i = 0, n - 1 do
    if not r.TrackFX_SetPresetByIndex(track, fx, i) then break end
    local _, name = r.TrackFX_GetPreset(track, fx)
    names[i + 1] = name or ""
    -- Preset-Typ fuer Duplikat-Rangfolge: User-Preset (.rpl) hat Dateinamen,
    -- plugin-eigene Presets (AU/VST3/...) liefern ""
    local upf = ""
    if r.TrackFX_GetUserPresetFilename then
      upf = PickStr(r.TrackFX_GetUserPresetFilename(track, fx))
    end
    types[i + 1] = (upf ~= "") and "reaper" or "plugin"
    files[i + 1] = upf
  end
  for p = 0, nparams - 1 do r.TrackFX_SetParam(track, fx, p, snapshot[p]) end
  if cur_idx and cur_idx >= 0 and cur_idx < n then
    r.TrackFX_SetPresetByIndex(track, fx, cur_idx)
  end
  for _ = 1, 3 do
    local ok = true
    for p = 0, nparams - 1 do
      local _, v = r.TrackFX_GetParam(track, fx, p)
      if math.abs((v or 0) - (snapshot[p] or 0)) > 1e-6 then
        r.TrackFX_SetParam(track, fx, p, snapshot[p])
        ok = false
      end
    end
    local now_idx = r.TrackFX_GetPresetIndex(track, fx)
    if cur_idx and cur_idx >= 0 and now_idx ~= cur_idx then
      if cur_idx < n then r.TrackFX_SetPresetByIndex(track, fx, cur_idx) end
      ok = false
    end
    if ok then break end
  end
  r.Undo_EndBlock("FX Preset Browser: Presetnamen lesen", -1)
  if #names == 0 then return nil end
  preset_cache[key] = { names = names, types = types, files = files }
  return preset_cache[key]
end

-- gecachter Eintrag (names+types+files) ohne Enumeration (nil, wenn noch nicht geladen)
local function CachedPresetNames(track, fx)
  local _, count = r.TrackFX_GetPresetIndex(track, fx)
  if not count or count <= 0 then return nil end
  return preset_cache[r.GetTrackGUID(track) .. "|" .. fx .. "|" .. count]
end

----------------------------------------------------------------
-- Preset-Rangfolge & Datei-Operationen (Aufräumen)
----------------------------------------------------------------
-- Rang eines Presets bei Duplikaten: erst bevorzugter Typ (Settings),
-- dann zuletzt verwendet (Datum, last_used), dann höherer Index
local function PresetRank(e, fxname)
  local preferred = (settings.dup_pref == "reaper") and (e.type == "reaper")
    or (settings.dup_pref == "plugin" and e.type == "plugin")
  local trank = preferred and 2 or 1
  local ts = settings.last_used[fxname .. "\t" .. e.name] or 0
  return trank * 1e12 + ts + (e.idx or 0) * 1e-9
end

-- User-Preset-Ordner des FX (aus einem bekannten .rpl-Pfad, sonst FXPresets/<fxname>)
local function PresetDirOf(entry, fxname)
  for _, f in ipairs(entry.files or {}) do
    if f and f ~= "" then
      local dir = f:match("^(.*)[/\\][^/\\]*$")
      if dir and dir ~= "" then return dir end
    end
  end
  local res = r.GetResourcePath and r.GetResourcePath() or ""
  return res .. "/FXPresets/" .. fxname
end

local function SanitizeFileName(name)
  return (name:gsub('[/\\:%*?"<>|]', "_"))
end

local function WriteTextFile(path, content)
  if not io or not io.open then return false end
  local f, err = io.open(path, "wb")
  if not f then return false, err end
  f:write(content)
  f:close()
  return true
end

local function DeleteFile(path)
  if os and os.remove then return os.remove(path) end
  return false
end

-- Duplikate (gleiche Presetnamen) aufraeumen: pro Gruppe gewinnt PresetRank,
-- verlierende .rpl-Dateien werden geloescht (doit=true). Plugin-eigene Presets
-- (.aupreset/.vstpreset) kann ein Script nicht loeschen -> nur Anzeige-Dedupe.
local function CleanupDuplicates(entry, fxname, doit)
  local groups = {}
  for i, nm in ipairs(entry.names) do
    local k = nm:lower()
    groups[k] = groups[k] or {}
    table.insert(groups[k], { name = nm, idx = i - 1, type = entry.types[i] or "plugin", file = (entry.files and entry.files[i]) or "" })
  end
  local dups, del_rpl, plugin_losers, deleted = 0, 0, 0, 0
  for _, g in pairs(groups) do
    if #g > 1 then
      dups = dups + 1
      local winner = g[1]
      for _, e in ipairs(g) do
        if PresetRank(e, fxname) > PresetRank(winner, fxname) then winner = e end
      end
      for _, e in ipairs(g) do
        if e ~= winner then
          if e.file ~= "" then
            del_rpl = del_rpl + 1
            if doit and DeleteFile(e.file) then deleted = deleted + 1 end
          else
            plugin_losers = plugin_losers + 1
          end
        end
      end
    end
  end
  return { dups = dups, del_rpl = del_rpl, plugin_losers = plugin_losers, deleted = deleted }
end

-- alle Plugin-Presets des FX als .rpl in dessen User-Preset-Ordner speichern
-- (ueberschreibt gleichnamige .rpl). FX-Zustand wird gesichert/restauriert.
local function SaveAllPresetsAsRpl(track, fx, fxname, entry)
  local dir = PresetDirOf(entry, fxname)
  local cur_idx = r.TrackFX_GetPresetIndex(track, fx)
  local nparams = r.TrackFX_GetNumParams(track, fx)
  local snapshot = {}
  for p = 0, nparams - 1 do
    local _, v = r.TrackFX_GetParam(track, fx, p)
    snapshot[p] = v
  end
  local written = 0
  r.Undo_BeginBlock()
  for i, nm in ipairs(entry.names) do
    if (entry.types[i] or "plugin") == "plugin" and nm ~= "" then
      if r.TrackFX_SetPresetByIndex(track, fx, i - 1) then
        local chunk = r.TrackFX_GetFXChunk and r.TrackFX_GetFXChunk(track, fx) or nil
        if chunk and chunk ~= "" then
          if WriteTextFile(dir .. "/" .. SanitizeFileName(nm) .. ".rpl", chunk) then written = written + 1 end
        end
      end
    end
  end
  for p = 0, nparams - 1 do r.TrackFX_SetParam(track, fx, p, snapshot[p]) end
  if cur_idx and cur_idx >= 0 then r.TrackFX_SetPresetByIndex(track, fx, cur_idx) end
  r.Undo_EndBlock("FX Preset Browser: Presets als .rpl speichern", -1)
  return written, dir
end

local function FindRule(trackname)
  if not trackname then return nil end
  local lower = trackname:lower()
  for _, rule in ipairs(settings.rules) do
    if rule.pattern ~= "" and lower:find(rule.pattern:lower(), 1, true) then
      return rule
    end
  end
  return nil
end

local sort_labels = { default = "wie gehabt", az = "A-Z", za = "Z-A", newest = "neueste zuerst" }
local sort_order  = { "default", "az", "za", "newest" }

-- sortiert eine Presetliste (In-Place) gemaess settings.sort_mode
local function SortPresetList(list, fxname)
  local mode = settings.sort_mode
  if mode == "az" then
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
  elseif mode == "za" then
    table.sort(list, function(a, b) return a.name:lower() > b.name:lower() end)
  elseif mode == "newest" then
    local lu = settings.last_used
    table.sort(list, function(a, b)
      local ta = lu[fxname .. "\t" .. a.name] or 0
      local tb = lu[fxname .. "\t" .. b.name] or 0
      if ta ~= tb then return ta > tb end
      return a.name:lower() < b.name:lower()
    end)
  end
  -- "default" = Reihenfolge wie gehabt (Preset-Index)
end

-- bei gleichem Presetnamen nur das ranghöchste Preset behalten:
-- erst der bevorzugte Preset-Typ (Settings), dann das zuletzt verwendete
-- (Datum, last_used), dann der höhere Preset-Index
local function DedupePresets(list, fxname)
  local best = {}
  for _, p in ipairs(list) do
    local k = p.name:lower()
    if not best[k] or PresetRank(p, fxname) > PresetRank(best[k], fxname) then best[k] = p end
  end
  local out = {}
  for _, p in ipairs(list) do
    if best[p.name:lower()] == p then table.insert(out, p) end
  end
  return out
end

local function BuildPresetList(track, fx, fxname, entry)
  local names, types = entry.names, entry.types
  local cur_idx = r.TrackFX_GetPresetIndex(track, fx)
  local _, trackname = r.GetTrackName(track)
  local rule = FindRule(trackname)
  local excl = settings.excluded[fxname]
  local allowed_set = nil
  if rule and rule.allowed:gsub("%s", "") ~= "" then
    allowed_set = {}
    for p in rule.allowed:gmatch("[^,]+") do
      p = p:gsub("^%s+", ""):gsub("%s+$", "")
      allowed_set[p] = true
    end
  end

  local list = {}
  for i = 1, #names do
    local nm = names[i]
    local ok = true
    if allowed_set and not allowed_set[nm] then ok = false end
    if excl and excl[nm] then ok = false end
    if ok then
      table.insert(list, { name = nm, idx = i - 1, type = types[i] or "plugin" })
    end
  end
  -- Duplikate (gleicher Name aus Plugin- und REAPER-Presets) ausblenden
  if settings.dedupe then list = DedupePresets(list, fxname) end
  -- Sortierung gilt ueberall (Settings-Liste + Dropdowns in Browser/Overview)
  SortPresetList(list, fxname)
  -- Position des aktuellen Presets erst NACH dem Sortieren bestimmen
  local cur = 0
  for i, p in ipairs(list) do
    if p.idx == cur_idx then cur = i end
  end
  return list, cur
end

local function AllowedPresets(track, fx, fxname)
  local entry = GetPresetNames(track, fx)
  if not entry then return nil, nil end
  return BuildPresetList(track, fx, fxname, entry)
end

-- Fingerprint aller Parameter, um "Preset geladen, aber veraendert" zu erkennen
local preset_fp = {}  -- "guid|fx" -> { name = <presetname>, idx = <presetindex>, fp = <string> }

local function ParamFingerprint(track, fx)
  local n = r.TrackFX_GetNumParams(track, fx)
  local t = {}
  for p = 0, n - 1 do
    local _, v = r.TrackFX_GetParam(track, fx, p)
    t[#t + 1] = string.format("%.5f", v or 0)
  end
  return table.concat(t, ",")
end

-- liefert (presetname, modified).
-- WICHTIG: Sobald ein Parameter veraendert wird, meldet REAPER cur_idx < 0
-- und TrackFX_GetPreset liefert "" (nicht mehr den Presetnamen). Deshalb
-- wird der zuletzt geladene Presetname ueber den Preset-Index rekonstruiert:
-- bei cur_idx >= 0 mit neuem Index wurde ein Preset geladen (Fingerprint
-- wird neu verankert), bei cur_idx < 0 wird der Fingerprint mit dem letzten
-- bekannten verglichen -> modified.
local function PresetState(track, fx)
  local key = r.GetTrackGUID(track) .. "|" .. fx
  local cur_idx = r.TrackFX_GetPresetIndex(track, fx)
  local st = preset_fp[key]
  if cur_idx >= 0 then
    if not st or st.idx ~= cur_idx then
      local _, name = r.TrackFX_GetPreset(track, fx)
      preset_fp[key] = { name = name or "", idx = cur_idx, fp = ParamFingerprint(track, fx) }
      return name or "", false
    end
    return st.name, ParamFingerprint(track, fx) ~= st.fp
  end
  -- cur_idx < 0: veraenderter Zustand, Presetname vom letzten Laden nehmen.
  -- Auch hier MUSS verankert werden: Plugins, die dauerhaft cur_idx = -1
  -- melden, haetten sonst nie einen Fingerprint-Anker und der *-Marker
  -- wuerde nie erscheinen.
  if not st then
    local _, name = r.TrackFX_GetPreset(track, fx)
    preset_fp[key] = { name = name or "", idx = -1, fp = ParamFingerprint(track, fx) }
    return name or "", false
  end
  return st.name, ParamFingerprint(track, fx) ~= st.fp
end

local function MarkPresetLoaded(track, fx, name)
  local cur_idx = r.TrackFX_GetPresetIndex(track, fx)
  preset_fp[r.GetTrackGUID(track) .. "|" .. fx] = { name = name, idx = cur_idx, fp = ParamFingerprint(track, fx) }
end

-- formatierter Parameterwert, schoen formatiert: "90.0 deg" -> "90.0°"
local function FormatParam(track, fx, p, norm)
  local _, fmt = r.TrackFX_FormatParamValue(track, fx, p, norm)
  return (fmt:gsub("%s*deg", "°"))
end

-- formatierter Wert des ersten Parameters, dessen Name `needle` enthaelt
-- (Substring, case-insensitive)
local function FormatParamBySubstring(track, fx, needle)
  local n = r.TrackFX_GetNumParams(track, fx)
  local lower = needle:lower()
  for p = 0, n - 1 do
    local _, pname = r.TrackFX_GetParamName(track, fx, p)
    if pname:lower():find(lower, 1, true) then
      local _, norm = r.TrackFX_GetParam(track, fx, p)
      return FormatParam(track, fx, p, norm)
    end
  end
  return nil
end

-- Trackname-Template aufloesen: {preset} -> Presetname,
-- {p:Name} / {param:Name} -> formatierter Parameterwert (Substring-Match);
-- unbekannte Platzhalter und Freitext bleiben unveraendert stehen
local function ApplyTrackNameTemplate(track, fx, template)
  local _, pname = r.TrackFX_GetPreset(track, fx)
  return (template:gsub("{(.-)}", function(ph)
    if ph == "preset" then return (pname ~= nil and pname ~= "") and pname or "?" end
    local key = ph:match("^p%:(.+)$") or ph:match("^param%:(.+)$")
    if key then
      local v = FormatParamBySubstring(track, fx, key)
      if v then return v end
    end
    return "{" .. ph .. "}"
  end))
end

local function DrawPresetCombo(track, fx, label)
  local _, fxname = r.TrackFX_GetFXName(track, fx)
  local cur_preset, modified = PresetState(track, fx)
  local preview = (cur_preset ~= "" and cur_preset or "?") .. (modified and " *" or "")
  if r.ImGui_BeginCombo(ctx, label, preview) then
    -- Lazy: Presetnamen werden erst beim Oeffnen des Dropdowns enumeriert
    -- (GetPresetNames stellt den FX-Zustand verifiziert wieder her). Dadurch
    -- wird beim Laden des Scripts kein einziges FX durchgeschaltet.
    local entry = CachedPresetNames(track, fx)
    local list, cur
    if entry then
      list, cur = BuildPresetList(track, fx, fxname, entry)
    else
      list, cur = AllowedPresets(track, fx, fxname)
    end
    if not list or #list == 0 then
      r.ImGui_TextDisabled(ctx, "keine Presets")
    end
    if list then
      for i, p in ipairs(list) do
        if r.ImGui_Selectable(ctx, p.name, i == cur) then
          r.TrackFX_SetPresetByIndex(track, fx, p.idx)
          MarkPresetLoaded(track, fx, p.name)
          settings.last_used[fxname .. "\t" .. p.name] = os.time()
          SaveSettings(settings_scope)
          if apply_to_all then
            local n = 0
            for ti = 0, r.GetNumTracks() - 1 do
              local tr = r.GetTrack(0, ti)
              for ff = 0, r.TrackFX_GetCount(tr) - 1 do
                local _, nm = r.TrackFX_GetFXName(tr, ff)
                if nm == fxname then n = n + 1 end
              end
            end
            local ok = r.ShowMessageBox(
              "Sicher? " .. n .. " Instanzen von '" .. fxname .. "' auf Preset '" .. p.name .. "' setzen?",
              "Alle Instanzen uebernehmen", 4)  -- 4 = MB_YESNO
            if ok == 6 then  -- IDYES
              r.Undo_BeginBlock()
              for ti = 0, r.GetNumTracks() - 1 do
                local tr = r.GetTrack(0, ti)
                for ff = 0, r.TrackFX_GetCount(tr) - 1 do
                  local _, nm = r.TrackFX_GetFXName(tr, ff)
                  if nm == fxname and not (tr == track and ff == fx) then
                    r.TrackFX_SetPresetByIndex(tr, ff, p.idx)
                  end
                end
              end
              r.Undo_EndBlock("FX Preset Browser: Preset auf alle Instanzen setzen", -1)
            end
          end
        end
      end
    end
    r.ImGui_EndCombo(ctx)
  end
end

-- Farbkonstante aufloesen (in manchen Builds Funktion, sonst Zahl)
local function ColIdx(name)
  local idx = r["ImGui_" .. name]
  if type(idx) == "function" then idx = idx() end
  return idx
end

-- halbtransparentes Hintergrund-Rechteck ueber die aktuelle Zeile
-- (ganze Breite des Fensters), z. B. fuer die aktive Spur im Overview
local function HighlightRow()
  if not r.ImGui_GetWindowDrawList or not r.ImGui_DrawList_AddRectFilled then return end
  local dl = r.ImGui_GetWindowDrawList(ctx)
  local x, y = r.ImGui_GetCursorScreenPos(ctx)
  local w = r.ImGui_GetWindowWidth(ctx)
  local h = r.ImGui_GetTextLineHeight(ctx)
  r.ImGui_DrawList_AddRectFilled(dl, x, y, x + w, y + h, 0xFFD70040)  -- Gold, Alpha 0x40 (0xRRGGBBAA)
end

-- letztes gueltiges Focus-FX merken, damit die Anzeige nicht "wegspringt",
-- sobald das Script-Fenster selbst fokussiert ist (GetFocusedFX() == 0)
local last_focus_track, last_focus_fx = nil, nil
local last_sel_track = nil  -- zuletzt gesehene Spur-Auswahl (Aenderung -> Follow-Sprung)

-- erstes FX einer Spur, dessen Name dem FX-Filter entspricht
local function FirstMatchingFX(track)
  for f = 0, r.TrackFX_GetCount(track) - 1 do
    local _, nm = r.TrackFX_GetFXName(track, f)
    if FXMatches(nm) then return f end
  end
  return nil
end

local function GetCurrentFX()
  if follow_focused then
    -- liefert (retval, tracknumber, itemnumber, fxnumber); aeltere Versionen
    -- nur (retval, tracknumber, fxnumber) -> fxnumber ist dann nil
    local retval, tr, a, b = r.GetFocusedFX()
    local fn = (b ~= nil) and b or a
    if retval == 1 and tr >= 0 then
      -- fokussiertes FX-Fenster hat Vorrang
      local track = (tr == 0) and r.GetMasterTrack(0) or r.GetTrack(0, tr - 1)
      if track and fn >= 0 and fn < r.TrackFX_GetCount(track) then
        last_focus_track, last_focus_fx = track, fn
      end
      local sel0 = r.GetSelectedTrack(0, 0)
      if sel0 then last_sel_track = sel0 end
    else
      -- kein FX-Fenster fokussiert: auf Spur-Auswahl reagieren, damit der
      -- Browser nicht erst nach Oeffnen des FX-Fensters zur Spur wechselt
      local sel = r.GetSelectedTrack(0, 0)
      if not sel and r.GetLastTouchedTrack then sel = r.GetLastTouchedTrack() end
      if sel and sel ~= last_sel_track then
        local f = FirstMatchingFX(sel)
        if f then last_focus_track, last_focus_fx = sel, f end
      end
      last_sel_track = sel
    end
  end
  if last_focus_track and r.ValidatePtr(last_focus_track, "MediaTrack*")
     and last_focus_fx < r.TrackFX_GetCount(last_focus_track) then
    return last_focus_track, last_focus_fx
  end
  local track = r.GetTrack(0, selected_track_idx)
  if track and selected_fx_idx < r.TrackFX_GetCount(track) then
    return track, selected_fx_idx
  end
  return nil, nil
end

----------------------------------------------------------------
-- Browser-Fenster
----------------------------------------------------------------
local function ParamWidget(track, fx, param, ignore_filter)
  local _, name = r.TrackFX_GetParamName(track, fx, param)
  local pf = param_filter:lower()
  if not ignore_filter and pf ~= "" and not name:lower():find(pf, 1, true) then return end

  local _, norm = r.TrackFX_GetParam(track, fx, param)
  local rv_step, step, _, _, istoggle = r.TrackFX_GetParameterStepSizes(track, fx, param)
  local fmt = FormatParam(track, fx, param, norm)
  r.ImGui_PushID(ctx, param)

  r.ImGui_Text(ctx, name)
  r.ImGui_SameLine(ctx)
  local x = select(1, r.ImGui_GetCursorPos(ctx))
  r.ImGui_SetCursorPosX(ctx, math.max(x, 180))

  if istoggle == 1 then
    local changed, newval = r.ImGui_Checkbox(ctx, "", norm > 0.5 and 1 or 0)
    if changed then r.TrackFX_SetParam(track, fx, param, newval) end
  elseif rv_step and step > 0 and (1.0 / step) <= 64 then
    local steps = math.floor(1.0 / step + 0.5)
    if r.ImGui_BeginCombo(ctx, "", fmt) then
      for i = 0, steps do
        local nv = i * step
        local lbl = FormatParam(track, fx, param, nv)
        if r.ImGui_Selectable(ctx, lbl, math.abs(norm - nv) < step / 2) then
          r.TrackFX_SetParam(track, fx, param, nv)
        end
      end
      r.ImGui_EndCombo(ctx)
    end
  else
    local changed, newval = r.ImGui_SliderDouble(ctx, "##p", norm, 0.0, 1.0, fmt)
    if changed then r.TrackFX_SetParam(track, fx, param, newval) end
  end
  r.ImGui_PopID(ctx)
end

local function DrawBrowser(track, fx)
  local _, fxname = r.TrackFX_GetFXName(track, fx)
  r.ImGui_Text(ctx, fxname)
  r.ImGui_Separator(ctx)

  r.ImGui_Text(ctx, "Preset:")
  r.ImGui_SameLine(ctx)
  DrawPresetCombo(track, fx, "##preset")
  r.ImGui_Separator(ctx)

  -- Quick-Parameter (Settings) immer sichtbar, auch ohne Parameter-Toggle
  local qp = settings.quick_params:lower()
  if qp:gsub("%s", "") ~= "" then
    local nparams_q = r.TrackFX_GetNumParams(track, fx)
    local shown_q = false
    for p = 0, nparams_q - 1 do
      local _, pname = r.TrackFX_GetParamName(track, fx, p)
      for term in qp:gmatch("[^,]+") do
        term = term:gsub("^%s+", ""):gsub("%s+$", "")
        if term ~= "" and pname:lower():find(term, 1, true) then
          if not shown_q then
            r.ImGui_Text(ctx, "Quick-Parameter:")
            r.ImGui_Separator(ctx)
            shown_q = true
          end
          ParamWidget(track, fx, p, true)
          break
        end
      end
    end
    if shown_q then r.ImGui_Separator(ctx) end
  end

  -- Parameter erst auf expliziten Wunsch anzeigen (Presets laden sonst
  -- mitten im Rendern die Parameter um)
  if not show_params then
    r.ImGui_TextDisabled(ctx, "Parameter ausgeblendet - 'Parameter anzeigen' aktivieren.")
    return
  end

  local nparams = r.TrackFX_GetNumParams(track, fx)
  local changed, buf = r.ImGui_InputTextWithHint(ctx, "##filter", "Parameter filtern...", param_filter)
  if changed then param_filter = buf end

  if r.ImGui_BeginChild(ctx, "##params") then
    for p = 0, nparams - 1 do
      ParamWidget(track, fx, p)
    end
    r.ImGui_EndChild(ctx)
  end
end

----------------------------------------------------------------
-- Overview-Fenster
----------------------------------------------------------------
local function DrawOverview()
  local cur_track, cur_fx = GetCurrentFX()
  if win_collapsed.overview then
    r.ImGui_SetNextWindowSize(ctx, 520, 400, r.ImGui_Cond_Always())
  else
    r.ImGui_SetNextWindowSize(ctx, 520, 400, r.ImGui_Cond_FirstUseEver())
  end
  local vis, open = r.ImGui_Begin(ctx, "Preset Overview", true)
  win_collapsed.overview = not vis  -- Begin==false heisst eingeklappt/geklippt
  if vis then
    r.ImGui_TextDisabled(ctx, "FX-Filter: " .. settings.fx_filters)
    r.ImGui_Separator(ctx)
    if r.ImGui_BeginChild(ctx, "##rows") then
      local ntracks = r.GetNumTracks()
      for i = 0, ntracks - 1 do
        local track = r.GetTrack(0, i)
        local _, tname = r.GetTrackName(track)
        local nfx = r.TrackFX_GetCount(track)
        local has_row = false
        for f = 0, nfx - 1 do
          local _, fxname = r.TrackFX_GetFXName(track, f)
          if FXMatches(fxname) then
            local track_active = (track == cur_track)
            if not has_row then
              if track_active then HighlightRow() end
              r.ImGui_Text(ctx, tname)
              has_row = true
            end
            local is_active = (track_active and f == cur_fx)
            if track_active then HighlightRow() end
            if is_active then
              r.ImGui_PushStyleColor(ctx, ColIdx("Col_Text"), 0xFFD700FF)  -- Gold, 0xRRGGBBAA
            end
            r.ImGui_PushID(ctx, i .. "_" .. f)
            r.ImGui_Indent(ctx, 12)
            r.ImGui_Text(ctx, fxname)
            r.ImGui_SameLine(ctx)
            DrawPresetCombo(track, f, "##preset")
            r.ImGui_Unindent(ctx, 12)
            r.ImGui_PopID(ctx)
            if is_active then r.ImGui_PopStyleColor(ctx) end
          end
        end
        if has_row then r.ImGui_Separator(ctx) end
      end
      r.ImGui_EndChild(ctx)
    end
    r.ImGui_End(ctx)  -- ReaImGui: nur wenn Begin true lieferte (sonst "End() too many times")
  end
  show_overview = open
end

----------------------------------------------------------------
-- Settings-Fenster
----------------------------------------------------------------
local function CollectMatchingFXNames()
  local seen, out = {}, {}
  local ntracks = r.GetNumTracks()
  for i = 0, ntracks - 1 do
    local track = r.GetTrack(0, i)
    for f = 0, r.TrackFX_GetCount(track) - 1 do
      local _, fxname = r.TrackFX_GetFXName(track, f)
      if FXMatches(fxname) and not seen[fxname] then
        seen[fxname] = true
        table.insert(out, fxname)
      end
    end
  end
  return out
end

-- Abschnitts-Header (Gold)
local function SectionHeader(text)
  r.ImGui_Spacing(ctx)
  r.ImGui_Separator(ctx)
  r.ImGui_PushStyleColor(ctx, ColIdx("Col_Text"), 0xFFD700FF)  -- Gold, 0xRRGGBBAA
  r.ImGui_Text(ctx, text)
  r.ImGui_PopStyleColor(ctx)
end

local function DrawSettings()
  local vis, open = r.ImGui_Begin(ctx, "Settings", true)
  if vis then
    SectionHeader("FX-Filter")
    r.ImGui_Text(ctx, "Komma-getrennte Substrings (Default: dearVR):")
    local ch, v = r.ImGui_InputText(ctx, "##filters", settings.fx_filters)
    if ch then
      settings.fx_filters = v
      SaveSettings(settings_scope)
    end
    r.ImGui_TextDisabled(ctx, "Nur FX deren Namen einen dieser Begriffe enthaelt werden angezeigt.")

    SectionHeader("Preset-Liste: Sortierung & Duplikate")
    r.ImGui_Text(ctx, "Sortierung:")
    r.ImGui_SameLine(ctx)
    if r.ImGui_BeginCombo(ctx, "##sort", sort_labels[settings.sort_mode] or settings.sort_mode) then
      for _, mode in ipairs(sort_order) do
        if r.ImGui_Selectable(ctx, sort_labels[mode], settings.sort_mode == mode) then
          settings.sort_mode = mode
          SaveSettings(settings_scope)
        end
      end
      r.ImGui_EndCombo(ctx)
    end
    r.ImGui_TextDisabled(ctx, "Gilt fuer die Settings-Liste und alle Preset-Dropdowns (Browser/Overview).")
    r.ImGui_Spacing(ctx)
    local chd, vd = r.ImGui_Checkbox(ctx, "Duplikate ausblenden (gleicher Name -> nur ranghoechstes/neuestes)", settings.dedupe)
    if chd then
      settings.dedupe = (vd == true or vd == 1)
      SaveSettings(settings_scope)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_BeginCombo(ctx, "##duppref", settings.dup_pref == "reaper" and "REAPER (.rpl) bevorzugt" or "Plugin (AU/VST3) bevorzugt") then
      if r.ImGui_Selectable(ctx, "Plugin (AU/VST3) bevorzugt", settings.dup_pref == "plugin") then
        settings.dup_pref = "plugin"
        SaveSettings(settings_scope)
      end
      if r.ImGui_Selectable(ctx, "REAPER (.rpl) bevorzugt", settings.dup_pref == "reaper") then
        settings.dup_pref = "reaper"
        SaveSettings(settings_scope)
      end
      r.ImGui_EndCombo(ctx)
    end
    r.ImGui_TextDisabled(ctx, "Bei gleichem Namen gewinnt: bevorzugter Preset-Typ, dann zuletzt verwendet (Datum), dann hoeherer Index.")

    SectionHeader("Quick-Parameter (Browser)")
    r.ImGui_Text(ctx, "Komma-getrennte Substrings (z. B. 'azimut, distance'):")
    local chq, vq = r.ImGui_InputText(ctx, "##quickparams", settings.quick_params)
    if chq then
      settings.quick_params = vq
      SaveSettings(settings_scope)
    end
    r.ImGui_TextDisabled(ctx, "Diese Parameter sind im Browser immer sichtbar (auch ohne 'Parameter anzeigen').")

    SectionHeader("Trackname-Template")
    r.ImGui_Text(ctx, "Platzhalter fuer den Umbenennen-Button:")
    local cht, vt = r.ImGui_InputTextWithHint(ctx, "##tpl", "{preset}  |  {p:azimuth}", settings.trackname_template)
    if cht then
      settings.trackname_template = vt
      SaveSettings(settings_scope)
    end
    r.ImGui_TextDisabled(ctx, "{preset} = Presetname, {p:Name} = Parameterwert (z. B. {p:azimut}). Rest = Freitext. Leer = nur Presetname.")
    r.ImGui_Spacing(ctx)
    if r.ImGui_Button(ctx, "Ausgewählte Spuren umbenennen (Template anwenden)") then
      local tpl = settings.trackname_template
      if tpl:gsub("%s", "") == "" then tpl = "{preset}" end
      r.Undo_BeginBlock()
      local nsel = r.CountSelectedTracks(0)
      for si = 0, nsel - 1 do
        local tr = r.GetSelectedTrack(0, si)
        if tr then
          for f = 0, r.TrackFX_GetCount(tr) - 1 do
            local _, nm = r.TrackFX_GetFXName(tr, f)
            if FXMatches(nm) then
              r.GetSetMediaTrackInfo_String(tr, "P_NAME", ApplyTrackNameTemplate(tr, f, tpl), true)
              break  -- erstes passendes FX pro Spur genuegt
            end
          end
        end
      end
      r.Undo_EndBlock("FX Preset Browser: Spuren nach Template umbenennen", -1)
    end
    r.ImGui_TextDisabled(ctx, "Erstes FX pro ausgewaehlter Spur, das dem Filter entspricht (ein Undo-Schritt).")

    SectionHeader("Presets ausschliessen & aufraeumen")
    local names = CollectMatchingFXNames()
    if #names == 0 then
      r.ImGui_TextDisabled(ctx, "Keine passenden FX im Projekt gefunden.")
    else
      if excl_sel_fxname == "" or not FXMatches(excl_sel_fxname) then
        excl_sel_fxname = names[1]
      end
      if r.ImGui_BeginCombo(ctx, "##exclfx", excl_sel_fxname) then
        for _, nm in ipairs(names) do
          if r.ImGui_Selectable(ctx, nm, nm == excl_sel_fxname) then
            excl_sel_fxname = nm
          end
        end
        r.ImGui_EndCombo(ctx)
      end

      local track, fx
      for i = 0, r.GetNumTracks() - 1 do
        local tr = r.GetTrack(0, i)
        for f = 0, r.TrackFX_GetCount(tr) - 1 do
          local _, nm = r.TrackFX_GetFXName(tr, f)
          if nm == excl_sel_fxname then
            track, fx = tr, f
            break
          end
        end
        if track then break end
      end

      if track then
        -- volle Presetliste (nicht AllowedPresets), damit ausgeschlossene
        -- Presets sichtbar bleiben und per Klick/Drag wieder aktivierbar sind
        local entry = GetPresetNames(track, fx)
        local list
        if entry then
          list = {}
          for i, nm in ipairs(entry.names) do list[i] = { name = nm, idx = i - 1 } end
        end
        if list then
          settings.excluded[excl_sel_fxname] = settings.excluded[excl_sel_fxname] or {}
          local excl = settings.excluded[excl_sel_fxname]
          SortPresetList(list, excl_sel_fxname)
          -- Klick = umschalten; Maus draggen ueber mehrere Eintraege malt
          -- denselben Zustand auf alle beruehrten Presets
          if not r.ImGui_IsMouseDown(ctx, 0) then excl_drag = nil end
          if r.ImGui_BeginChild(ctx, "##excllist") then
            local changed = false
            for _, p in ipairs(list) do
              local is_excl = excl[p.name] == true
              r.ImGui_PushID(ctx, p.name)
              r.ImGui_Selectable(ctx, p.name, is_excl)
              if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDown(ctx, 0) then
                if excl_drag == nil then excl_drag = not is_excl end
                if is_excl ~= excl_drag then
                  if excl_drag then excl[p.name] = true else excl[p.name] = nil end
                  changed = true
                end
              end
              r.ImGui_PopID(ctx)
            end
            r.ImGui_EndChild(ctx)
            if changed then SaveSettings(settings_scope) end
          end
          r.ImGui_TextDisabled(ctx, "Klick = umschalten, Drag = malt auf alle beruehrten. Markiert = ausgeschlossen.")
          r.ImGui_Spacing(ctx)
          if r.ImGui_Button(ctx, "Duplikate aufraeumen (.rpl-Loser loeschen)") then
            local plan = CleanupDuplicates(entry, excl_sel_fxname, false)
            if plan.dups == 0 then
              r.ShowMessageBox("Keine Duplikate (gleiche Presetnamen) gefunden.", "Aufraeumen", 0)
            else
              local ok = r.ShowMessageBox(
                plan.dups .. " Duplikat-Gruppen: " .. plan.del_rpl .. " .rpl loeschen" ..
                (plan.plugin_losers > 0 and (", " .. plan.plugin_losers .. " Plugin-Presets bleiben (nur Anzeige-Dedupe)") or "") .. "?",
                "Duplikate aufraeumen", 4)  -- MB_YESNO
              if ok == 6 then
                local done = CleanupDuplicates(entry, excl_sel_fxname, true)
                preset_cache[r.GetTrackGUID(track) .. "|" .. fx .. "|" .. #entry.names] = nil
                r.ShowMessageBox(done.deleted .. " .rpl geloescht.", "Aufraeumen", 0)
              end
            end
          end
          r.ImGui_SameLine(ctx)
          if r.ImGui_Button(ctx, "Alle Plugin-Presets als .rpl speichern") then
            local n = SaveAllPresetsAsRpl(track, fx, excl_sel_fxname, entry)
            preset_cache[r.GetTrackGUID(track) .. "|" .. fx .. "|" .. #entry.names] = nil
            r.ShowMessageBox(n .. " .rpl geschrieben (gleichnamige ueberschrieben).", "Als .rpl speichern", 0)
          end
          r.ImGui_TextDisabled(ctx, "Plugin-Formate (.aupreset/.vstpreset) kann nur das Plugin selbst schreiben; .rpl schreibt/loescht das Script direkt.")
        else
          r.ImGui_TextDisabled(ctx, "Dieses FX hat keine Presets.")
        end
      end
    end

    SectionHeader("Track-Regeln")
    r.ImGui_TextDisabled(ctx, "Erste Regel, deren Pattern im Tracknamen vorkommt, gewinnt (leer = alle Presets).")
    for i, rule in ipairs(settings.rules) do
      r.ImGui_PushID(ctx, "rule" .. i)
      local ch1, p = r.ImGui_InputText(ctx, "##pat", rule.pattern)
      if ch1 then rule.pattern = p end
      r.ImGui_SameLine(ctx)
      local ch2, a = r.ImGui_InputTextWithHint(ctx, "##allow", "alle", rule.allowed)
      if ch2 then rule.allowed = a end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "X") then
        table.remove(settings.rules, i)
        SaveSettings(settings_scope)
      end
      r.ImGui_PopID(ctx)
    end
    if r.ImGui_Button(ctx, "+ Regel hinzufuegen") then
      table.insert(settings.rules, { pattern = "", allowed = "" })
    end
    r.ImGui_TextDisabled(ctx, 'Beispiel: Pattern "VO", erlaubt "Room A,Room B".')

    SectionHeader("Darstellung & Speichern")
    r.ImGui_Text(ctx, "Theme:")
    r.ImGui_SameLine(ctx)
    if r.ImGui_BeginCombo(ctx, "##theme", current_theme) then
      for _, name in ipairs(theme_order) do
        if r.ImGui_Selectable(ctx, name, name == current_theme) then
          current_theme = name
          r.SetExtState(EXT_SECTION, "theme", name, true)
          ResolveTheme()
        end
      end
      r.ImGui_EndCombo(ctx)
    end
    r.ImGui_Spacing(ctx)
    r.ImGui_Text(ctx, "Einstellungen speichern in:")
    r.ImGui_SameLine(ctx)
    if r.ImGui_BeginCombo(ctx, "##scope", settings_scope == "project" and "Projekt" or "Global") then
      if r.ImGui_Selectable(ctx, "Global", settings_scope == "global") then
        settings_scope = "global"
        r.SetExtState(EXT_SECTION, "scope", "global", true)
        LoadSettings("global")
      end
      if r.ImGui_Selectable(ctx, "Projekt", settings_scope == "project") then
        settings_scope = "project"
        r.SetExtState(EXT_SECTION, "scope", "project", true)
        LoadSettings("project")
      end
      r.ImGui_EndCombo(ctx)
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_TextDisabled(ctx, settings_scope == "project" and "(Projekt ohne eigene Daten nutzt die globalen)" or "")
    r.ImGui_End(ctx)  -- ReaImGui: nur wenn Begin true lieferte (sonst "End() too many times")
  end
  show_settings = open
end

----------------------------------------------------------------
-- Parameter-Liste (aktives FX)
----------------------------------------------------------------
local function DrawParamList(track, fx)
  local vis, open = r.ImGui_Begin(ctx, "Parameter-Liste", true)
  if vis then
    local _, fxname = r.TrackFX_GetFXName(track, fx)
    r.ImGui_Text(ctx, fxname)
    local chf, fbuf = r.ImGui_InputTextWithHint(ctx, "##plfilter", "Parameter filtern...", pl_filter)
    if chf then pl_filter = fbuf end
    r.ImGui_Separator(ctx)
    if r.ImGui_BeginChild(ctx, "##pllist") then
      local n = r.TrackFX_GetNumParams(track, fx)
      local pf = pl_filter:lower()
      local shown = 0
      for p = 0, n - 1 do
        local _, pname = r.TrackFX_GetParamName(track, fx, p)
        if pf == "" or pname:lower():find(pf, 1, true) then
          local _, norm = r.TrackFX_GetParam(track, fx, p)
          r.ImGui_Text(ctx, p .. "  " .. pname .. "  =  " .. FormatParam(track, fx, p, norm))
          shown = shown + 1
        end
      end
      if shown == 0 then r.ImGui_TextDisabled(ctx, "keine Parameter") end
      r.ImGui_EndChild(ctx)
    end
    r.ImGui_TextDisabled(ctx, "In {p:...} / Quick-Parameter (case-insensitive) Substring des Namens, z. B. {p:azimut}, {p:distance}.")
    r.ImGui_End(ctx)  -- ReaImGui: nur wenn Begin true lieferte
  end
  show_paramlist = open
end

----------------------------------------------------------------
-- Main
----------------------------------------------------------------
local function frame()
  local track, fx = GetCurrentFX()
  ApplyTheme()

  if show_browser then
    -- ReaImGui poppt eingeklappte Fenster von selbst; beim Wiederaufklappen
    -- waere die Hoehe sonst 1px -> einmalig Cond_Always, sonst FirstUseEver
    if win_collapsed.browser then
      r.ImGui_SetNextWindowSize(ctx, 420, 500, r.ImGui_Cond_Always())
    else
      r.ImGui_SetNextWindowSize(ctx, 420, 500, r.ImGui_Cond_FirstUseEver())
    end
    local vis, open = r.ImGui_Begin(ctx, "FX Preset & Parameter Browser", true)
    win_collapsed.browser = not vis  -- Begin==false heisst eingeklappt/geklippt
    if vis then
      -- ReaImGui-Checkbox liefert den Wert als boolean -> nicht mit 1 vergleichen
      local _, fol = r.ImGui_Checkbox(ctx, "Fokussiertem FX folgen", follow_focused)
      follow_focused = (fol == true or fol == 1)
      r.ImGui_SameLine(ctx)
      local _, sp = r.ImGui_Checkbox(ctx, "Parameter anzeigen", show_params)
      local sp_on = (sp == true or sp == 1)
      if sp_on ~= show_params then
        show_params = sp_on
        r.SetExtState(EXT_SECTION, "show_params", show_params and "1" or "0", true)
      end
      r.ImGui_SameLine(ctx)
      local _, aa = r.ImGui_Checkbox(ctx, "Auf alle Instanzen anwenden", apply_to_all)
      local aa_on = (aa == true or aa == 1)
      if aa_on ~= apply_to_all then
        apply_to_all = aa_on
        r.SetExtState(EXT_SECTION, "apply_to_all", apply_to_all and "1" or "0", true)
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Settings") then
        show_settings = not show_settings
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, show_overview and "Overview aus" or "Overview an") then
        show_overview = not show_overview
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Parameter-Liste") then
        show_paramlist = not show_paramlist
      end
      r.ImGui_Separator(ctx)
      if track and fx then
        DrawBrowser(track, fx)
      else
        r.ImGui_TextDisabled(ctx, "Kein FX im Fokus / ausgewaehlt.")
      end
      r.ImGui_End(ctx)  -- ReaImGui: nur wenn Begin true lieferte (sonst "End() too many times")
    end
    show_browser = open
  end

  if show_overview then DrawOverview() end
  if show_settings then DrawSettings() end
  if show_paramlist and track and fx then DrawParamList(track, fx) end

  PopTheme()

  if not show_browser and not show_overview and not show_settings and not show_paramlist then
    r.ImGui_DestroyContext(ctx)
    return
  end
  r.defer(frame)
end

r.defer(function()
  ctx = r.ImGui_CreateContext("FX Preset Browser")
  r.defer(frame)
end)
