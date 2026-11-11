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
    end
  end
end

local function SaveSettings(settings_scope)
  local t = { "FILTER:" .. settings.fx_filters }
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
local follow_focused = true
local selected_track_idx = 0
local selected_fx_idx    = 0
local param_filter    = ""
local preset_cache    = {}
local excl_sel_fxname = ""
----------------------------------------------------------------
-- Themes
----------------------------------------------------------------
local themes = {
  girly = {
    { "Col_WindowBg", 0x1A0A12F2 },
    { "Col_FrameBg", 0x40182EFF },
    { "Col_FrameBgHovered", 0x5C2246FF },
    { "Col_TitleBgActive", 0xE75480FF },
    { "Col_Button", 0xE75480FF },
    { "Col_ButtonHovered", 0xFF7BA9FF },
    { "Col_ButtonActive", 0xFF9FC4FF },
    { "Col_SliderGrab", 0xFFB6C1FF },
    { "Col_SliderGrabActive", 0xFFD1DCFF },
    { "Col_Header", 0xE75480FF },
    { "Col_HeaderHovered", 0xFF7BA9FF },
    { "Col_CheckMark", 0xFFB6C1FF },
    { "Col_Text", 0xFFE4F1FF },
    { "Col_Separator", 0xB5597EFF },
  },
  dark = {
    { "Col_WindowBg", 0x141414E6 },
    { "Col_FrameBg", 0x2A2A2AFF },
    { "Col_FrameBgHovered", 0x3A3A3AFF },
    { "Col_TitleBgActive", 0xB676B8FF },
    { "Col_Button", 0xB676B8FF },
    { "Col_ButtonHovered", 0xD98FD9FF },
    { "Col_ButtonActive", 0xE6B8E6FF },
    { "Col_SliderGrab", 0xE6B8E6FF },
    { "Col_Header", 0xB676B8FF },
    { "Col_HeaderHovered", 0xD98FD9FF },
    { "Col_CheckMark", 0xE6B8E6FF },
  },
  light = {
    { "Col_WindowBg", 0xF4E6EEF7 },
    { "Col_FrameBg", 0xE0C0D0FF },
    { "Col_FrameBgHovered", 0xECD0DDFF },
    { "Col_Text", 0x3A1A2AFF },
    { "Col_Button", 0xE75480FF },
    { "Col_ButtonHovered", 0xFF7BA9FF },
    { "Col_ButtonActive", 0xFF9FC4FF },
    { "Col_Header", 0xE75480FF },
    { "Col_HeaderHovered", 0xFF7BA9FF },
    { "Col_CheckMark", 0xE75480FF },
    { "Col_SliderGrab", 0xE75480FF },
    { "Col_Separator", 0xC89AA8FF },
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
  local retval, cur_idx, count = r.TrackFX_GetPresetIndex(track, fx)
  if not retval or not count or count <= 0 then return nil, 0 end
  local key = r.GetTrackGUID(track) .. "|" .. fx .. "|" .. count
  if preset_cache[key] then return preset_cache[key].names, count end

  local names = {}
  for i = 0, count - 1 do
    r.TrackFX_SetPresetIndex(track, fx, i)
    local _, name = r.TrackFX_GetPreset(track, fx)
    names[i + 1] = name
  end
  r.TrackFX_SetPresetIndex(track, fx, cur_idx)
  preset_cache[key] = { names = names }
  return names, count
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

local function AllowedPresets(track, fx, fxname)
  local names, count = GetPresetNames(track, fx)
  if not names then return nil, nil end

  local retval, cur_idx = r.TrackFX_GetPresetIndex(track, fx)
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

  local list, cur = {}, 0
  for i = 1, count do
    local nm = names[i]
    local ok = true
    if allowed_set and not allowed_set[nm] then ok = false end
    if excl and excl[nm] then ok = false end
    if ok then
      table.insert(list, { name = nm, idx = i - 1 })
      if i - 1 == cur_idx then cur = #list end
    end
  end
  return list, cur
end

local function DrawPresetCombo(track, fx, label)
  local _, fxname = r.TrackFX_GetFXName(track, fx)
  local list, cur = AllowedPresets(track, fx, fxname)
  if not list or #list == 0 then
    r.ImGui_TextDisabled(ctx, "keine Presets")
    return
  end
  local _, cur_preset = r.TrackFX_GetPreset(track, fx)
  if r.ImGui_BeginCombo(ctx, label, cur_preset) then
    for i, p in ipairs(list) do
      if r.ImGui_Selectable(ctx, p.name, i == cur) then
        r.TrackFX_SetPresetIndex(track, fx, p.idx)
      end
    end
    r.ImGui_EndCombo(ctx)
  end
end

----------------------------------------------------------------
-- Browser-Fenster
----------------------------------------------------------------
local function ParamWidget(track, fx, param)
  local _, name = r.TrackFX_GetParamName(track, fx, param)
  local pf = param_filter:lower()
  if pf ~= "" and not name:lower():find(pf, 1, true) then return end

  local _, norm = r.TrackFX_GetParam(track, fx, param)
  local rv_step, step, _, _, istoggle = r.TrackFX_GetParameterStepSizes(track, fx, param)
  local _, fmt = r.TrackFX_FormatParamValue(track, fx, param, norm)
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
        local _, lbl = r.TrackFX_FormatParamValue(track, fx, param, nv)
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
  r.ImGui_SetNextWindowSize(ctx, 520, 400, r.ImGui_Cond_FirstUseEver())
  local vis, open = r.ImGui_Begin(ctx, "Preset Overview", true)
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
            if not has_row then
              r.ImGui_Text(ctx, tname)
              has_row = true
            end
            r.ImGui_PushID(ctx, i .. "_" .. f)
            r.ImGui_Indent(ctx, 12)
            r.ImGui_Text(ctx, fxname)
            r.ImGui_SameLine(ctx)
            DrawPresetCombo(track, f, "##preset")
            r.ImGui_Unindent(ctx, 12)
            r.ImGui_PopID(ctx)
          end
        end
        if has_row then r.ImGui_Separator(ctx) end
      end
      r.ImGui_EndChild(ctx)
    end
    r.ImGui_End(ctx)
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

local function DrawSettings()
  local vis, open = r.ImGui_Begin(ctx, "Settings", true)
  if vis then
    r.ImGui_Text(ctx, "FX-Filter (Komma-getrennt, Substring):")
    local ch, v = r.ImGui_InputText(ctx, "##filters", settings.fx_filters)
    if ch then
      settings.fx_filters = v
      SaveSettings(settings_scope)
    end
    r.ImGui_TextDisabled(ctx, "Nur FX deren Namen einen dieser Begriffe enthaelt werden angezeigt.")

    r.ImGui_Separator(ctx)

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

    r.ImGui_Separator(ctx)

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

    r.ImGui_Separator(ctx)

    r.ImGui_Text(ctx, "Presets ausschliessen (pro Plugin):")
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
        local list = AllowedPresets(track, fx, excl_sel_fxname)
        if list then
          settings.excluded[excl_sel_fxname] = settings.excluded[excl_sel_fxname] or {}
          local excl = settings.excluded[excl_sel_fxname]
          if r.ImGui_BeginChild(ctx, "##excllist") then
            for _, p in ipairs(list) do
              local is_excl = excl[p.name] and 1 or 0
              local c, nv = r.ImGui_Checkbox(ctx, p.name, is_excl)
              if c then
                if nv == 1 then
                  excl[p.name] = true
                else
                  excl[p.name] = nil
                end
                SaveSettings(settings_scope)
              end
            end
            r.ImGui_EndChild(ctx)
          end
          r.ImGui_TextDisabled(ctx, "Haekchen = Preset ist ausgeschlossen.")
        else
          r.ImGui_TextDisabled(ctx, "Dieses FX hat keine Presets.")
        end
      end
    end

    r.ImGui_Separator(ctx)

    r.ImGui_Text(ctx, "Track-Regeln (Track enthaelt -> nur erlaubte Presets):")
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

    r.ImGui_End(ctx)
  end
  show_settings = open
end

----------------------------------------------------------------
-- Main
----------------------------------------------------------------
local function GetCurrentFX()
  if follow_focused then
    local retval, tr, fn = r.GetFocusedFX()
    if retval == 1 and tr ~= 0 then
      local track = r.GetTrack(0, tr - 1)
      if track then return track, fn end
    end
  end
  local track = r.GetTrack(0, selected_track_idx)
  if track and selected_fx_idx < r.TrackFX_GetCount(track) then
    return track, selected_fx_idx
  end
  return nil, nil
end

local function frame()
  local track, fx = GetCurrentFX()
  ApplyTheme()

  if show_browser then
    r.ImGui_SetNextWindowSize(ctx, 420, 500, r.ImGui_Cond_FirstUseEver())
    local vis, open = r.ImGui_Begin(ctx, "FX Preset & Parameter Browser", true)
    if vis then
      local _, fol = r.ImGui_Checkbox(ctx, "Fokussiertem FX folgen", follow_focused and 1 or 0)
      follow_focused = fol == 1
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Settings") then
        show_settings = not show_settings
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, show_overview and "Overview aus" or "Overview an") then
        show_overview = not show_overview
      end
      r.ImGui_Separator(ctx)
      if track and fx then
        DrawBrowser(track, fx)
      else
        r.ImGui_TextDisabled(ctx, "Kein FX im Fokus / ausgewaehlt.")
      end
      r.ImGui_End(ctx)
    end
    show_browser = open
  end

  if show_overview then DrawOverview() end
  if show_settings then DrawSettings() end

  PopTheme()

  if not show_browser and not show_overview and not show_settings then
    r.ImGui_DestroyContext(ctx)
    return
  end
  r.defer(frame)
end

r.defer(function()
  ctx = r.ImGui_CreateContext("FX Preset Browser")
  r.defer(frame)
end)
