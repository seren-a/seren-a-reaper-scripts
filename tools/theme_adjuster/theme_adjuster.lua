--[[
  seren-a Theme Adjuster

  .ReaperTheme-Dateien komfortabel anpassen – direkt in REAPER, ohne
  Hex-/Dezimal-Rätselraten:

  - lädt alle Themes aus dem ColorThemes-Ordner (Dropdown)
  - zeigt für jeden Theme-Wert eine deutsche Beschreibung statt
    kryptischer Keys/Zahlen (TCP, MCP, Items, Fenster, MIDI, ...)
  - Draw-Modus-Werte (z.B. itembg_drawmode, *_dm) werden zerlegt in
    Modus + Alpha-Anteil + Flags statt Rohzahlen
  - Farbwerte mit Alpha-Kanal (negative Werte) werden als RGBA-Picker
    angezeigt, nicht als Dezimalzahl
  - Presets im GUI speichern / laden / löschen (REAPER ExtState)
  - vor dem ersten Speichern wird eine .theme_adjuster.bak-Backup-Datei
    angelegt, alle anderen Zeilen der Datei bleiben unangetastet

  Voraussetzung: REAPER 6.75+ mit ReaScript (Lua) + ReaImGui.
]]

local r = reaper

-- =========================================================================
-- 1. ImGui-Bindings (lazy, version-unabhängig aufgelöst)
-- =========================================================================

if not r.ImGui_CreateContext then
  r.ShowMessageBox(
    "ReaImGui fehlt. Bitte via ReaPack installieren\n('ReaScript: ReaImGui bindings')",
    "Theme Adjuster", 0)
  return
end

local I = setmetatable({}, {
  __index = function(t, name)
    local fn = r["ImGui_" .. name]
    if not fn then error("ReaImGui fehlt: ImGui_" .. name, 2) end
    rawset(t, name, fn)
    return fn
  end,
})

local COL = {}
local function resolve_colors()
  local names = {
    "WindowBg", "FrameBg", "FrameBgHovered", "FrameBgActive", "Button",
    "ButtonHovered", "ButtonActive", "Tab", "TabHovered", "TabActive",
    "Header", "HeaderHovered", "HeaderActive", "TitleBg", "PopupBg",
    "Text", "TextDisabled", "CheckMark", "SliderGrab", "Border",
  }
  for _, n in ipairs(names) do
    local v = r["ImGui_Col_" .. n]
    if v then COL[n] = v end
  end
end
resolve_colors()

local function push_color(name, v)
  if COL[name] then I.PushStyleColor(ctx, COL[name], v) return 1 end
  return 0
end

-- ImGui-Farben sind 0xRRGGBBAA (Alpha = letztes Byte!)
-- Stil: Dark Pastel Pink (angelehnt an die VS-Code-Themes
-- "Huacat Pink" und "Dark Pastel Pink")
local THEME_UI = {
  WindowBg        = 0x2A2128F0,
  PopupBg         = 0x322830F2,
  FrameBg         = 0x3A2D36FF,
  FrameBgHovered  = 0x4A3A44FF,
  FrameBgActive   = 0x55414EFF,
  TitleBg         = 0x4A3040FF,
  Button          = 0x6B4458FF,
  ButtonHovered   = 0x7D5468FF,
  ButtonActive    = 0x8E6180FF,
  Header          = 0x6B445880,
  HeaderHovered   = 0x7D546880,
  HeaderActive    = 0x8E618090,
  Tab             = 0x3A2D36FF,
  TabHovered      = 0x4A3A44FF,
  TabActive       = 0x55414EFF,
  Text            = 0xF2DCE8FF,
  TextDisabled    = 0x9A8492FF,
  CheckMark       = 0xFF9EC6FF,
  SliderGrab      = 0xD98CAAFF,
  Border          = 0x8A5A72FF,
}

-- =========================================================================
-- 2. Konstanten: Beschreibungen & Kategorien
-- =========================================================================

-- Deutsche Beschreibung je Theme-Key (unbekannte Keys landen unter
-- "Sonstige" und bleiben trotzdem editierbar).
local DESC = {
  -- Items & Arrange ------------------------------------------------------
  col_arrangebg          = "Arrange-Ansicht: Hintergrund",
  col_tracklistbg        = "Spurliste (TCP): Hintergrund hinter den Spur-Panels",
  col_mixerbg            = "Mixer: Hintergrund",
  col_tl_bg              = "Arrange: Spurbereich-Hintergrund",
  col_tl_fg              = "Arrange: Vordergrund-Elemente (Text/Standard)",
  col_tl_fg2             = "Arrange: Vordergrund-Elemente (2. Farbe)",
  col_tl_bgsel           = "Arrange: Hintergrund der ausgewählten Spur",
  col_tl_bgsel2          = "Arrange: Hintergrund der ausgewählten Spur (2. Farbe)",
  col_tr1_bg             = "Spur-Hintergrund, ungerade Spuren",
  col_tr2_bg             = "Spur-Hintergrund, gerade Spuren",
  col_tr1_divline        = "Trennlinie zwischen ungeraden Spuren",
  col_tr2_divline        = "Trennlinie zwischen geraden Spuren",
  col_tr1_itembgsel      = "Item-Hintergrund auf ausgewählter Spur (ungerade)",
  col_tr2_itembgsel      = "Item-Hintergrund auf ausgewählter Spur (gerade)",
  col_tr1_peaks          = "Wellenform-Peaks (ungerade Spuren)",
  col_tr2_peaks          = "Wellenform-Peaks (gerade Spuren)",
  col_tr1_ps2            = "Wellenform-Peaks, 2. Farbe (ungerade)",
  col_tr2_ps2            = "Wellenform-Peaks, 2. Farbe (gerade)",
  col_peaksedge          = "Peak-Umrandung",
  col_peaksedge2         = "Peak-Umrandung, 2. Farbe",
  col_peaksedgesel       = "Peak-Umrandung ausgewählter Items",
  col_peaksedgesel2      = "Peak-Umrandung ausgewählter Items, 2. Farbe",
  col_peaksfade1         = "Peaks im Fade-Bereich (1. Farbe)",
  col_peaksfade2         = "Peaks im Fade-Bereich (2. Farbe)",
  col_mi_bg              = "Item: Hintergrund",
  col_mi_bg2             = "Item: Hintergrund (2. Take-Farbe)",
  col_mi_label           = "Item: Beschriftung",
  col_mi_label_sel       = "Item: Beschriftung (ausgewählt)",
  col_mi_label_float     = "Item: Beschriftung (floating)",
  col_mi_label_float_sel = "Item: Beschriftung (floating, ausgewählt)",
  col_mi_fades           = "Item: Crossfade-Flächen",
  col_mi_fade2          = "Item: Auto-Crossfade-Fläche (2. Farbe)",
  item_grouphl           = "Item: Gruppen-Highlight (Items in Spur-Gruppe)",
  selitem_tag            = "Item: Markierung ausgewählter Items",
  activetake_tag         = "Item: Markierung des aktiven Takes",
  auto_item_unsel        = "Automation-Items (nicht ausgewählt)",
  itembg_drawmode        = "Item-Hintergrund: Draw-Modus",
  col_stretchmarker      = "Stretch-Marker: Linie",
  col_stretchmarker_b    = "Stretch-Marker: Hintergrund-Balken",
  col_stretchmarker_h0   = "Stretch-Marker: Farbton-Stufe 0",
  col_stretchmarker_h1   = "Stretch-Marker: Farbton-Stufe 1",
  col_stretchmarker_h2   = "Stretch-Marker: Farbton-Stufe 2",
  col_stretchmarker_text = "Stretch-Marker: Text",
  col_stretchmarker_tm   = "Stretch-Marker: Takt-Anzeige",
  col_stretchmarkerm     = "Stretch-Marker: Draw-Modus",
  col_fadearm            = "Fade-Griffe im Item (Grundfarbe)",
  col_fadearm2           = "Fade-Griffe im Item (2. Farbe)",
  col_fadearm3           = "Fade-Griffe im Item (3. Farbe)",
  fadezone_color         = "Fade-Zone beim Ziehen: Farbe",
  fadearea_color         = "Fade-Fläche beim Ziehen: Farbe",
  -- Raster, Cursor, Auswahl ----------------------------------------------
  col_gridlines          = "Raster: Beat-Linien",
  col_gridlines2         = "Raster: Takt-Linien",
  col_gridlines3         = "Raster: weitere Linien (z.B. 16tel)",
  arrange_vgrid          = "Raster: vertikale Linien (unter den Spuren)",
  col_cursor             = "Edit-Cursor",
  col_cursor2            = "Edit-Cursor (2. Farbe/Schatten)",
  playcursor_color       = "Play-Cursor",
  guideline_color        = "Guide-Line (Snap-Hilfe beim Ziehen)",
  timesel_drawmode       = "Zeit-Auswahl: Draw-Modus",
  marquee_fill           = "Marquee-Auswahl: Füllung",
  marquee_outline        = "Marquee-Auswahl: Umrandung",
  marqueezoom_fill       = "Marquee-Zoom: Füllung",
  marqueezoom_outline    = "Marquee-Zoom: Umrandung",
  col_seltrack           = "Ausgewählte Spur: Trenn-/Highlight-Linie",
  col_seltrack2          = "Ausgewählte Spur: Highlight-Fläche",
  col_offlinetext        = "Text offline gerenderter Spuren",
  col_routinghl1         = "Routing-Matrix: Highlight 1",
  col_routinghl2         = "Routing-Matrix: Highlight 2",
  -- TCP --------------------------------------------------------------------
  col_tcp_text           = "TCP: Text (Spurname, Labels)",
  col_tcp_textsel        = "TCP: Text der ausgewählten Spur",
  tcp_list_scrollbar     = "TCP: Scrollbar (z.B. FX-Liste)",
  tcp_list_scrollbar_mode = "TCP: Scrollbar-Draw-Modus",
  tcp_list_scrollbar_mouseover = "TCP: Scrollbar bei Mouse-Over",
  tcp_list_scrollbar_mouseover_mode = "TCP: Scrollbar-Draw-Modus (Mouse-Over)",
  tcplocked_color        = "TCP: Schloss-Symbol (gesperrte Scrollposition)",
  -- MCP --------------------------------------------------------------------
  mcp_fx_normal          = "MCP: FX-Kette, Hintergrund (normal)",
  mcp_fx_bypassed        = "MCP: FX-Kette, Hintergrund (bypassed)",
  mcp_fx_offlined        = "MCP: FX-Kette, Hintergrund (offline)",
  mcp_fxparm_normal      = "MCP: FX-Parameter, Hintergrund (normal)",
  mcp_fxparm_bypassed    = "MCP: FX-Parameter, Hintergrund (bypassed)",
  mcp_fxparm_offlined    = "MCP: FX-Parameter, Hintergrund (offline)",
  mcp_sends_normal      = "MCP: Sends, normal",
  mcp_sends_muted       = "MCP: Sends, gemutet",
  mcp_sends_levels      = "MCP: Sends, Pegel-Anzeige",
  mcp_send_midihw       = "MCP: Sends, MIDI/Hardware-Ausgang",
  mcp_list_scrollbar     = "MCP: Scrollbar",
  mcp_list_scrollbar_mode = "MCP: Scrollbar-Draw-Modus",
  mcp_list_scrollbar_mouseover = "MCP: Scrollbar bei Mouse-Over",
  mcp_list_scrollbar_mouseover_mode = "MCP: Scrollbar-Draw-Modus (Mouse-Over)",
  -- Fenster & UI -----------------------------------------------------------
  col_main_bg            = "Fenster: Haupt-Hintergrund",
  col_main_bg2           = "Fenster: 2. Hintergrund (dunklere Bereiche)",
  col_main_text          = "Fenster: Haupt-Text",
  col_main_text2         = "Fenster: 2. Textfarbe",
  col_main_textshadow    = "Fenster: Text-Schatten",
  col_main_3dhl          = "Fenster: 3D-Kante hell (Buttons/Panels)",
  col_main_3dsh          = "Fenster: 3D-Kante Schatten",
  col_main_resize        = "Fenster: Resize-Leiste",
  col_main_resize2       = "Fenster: Resize-Leiste (2. Farbe)",
  col_main_editbk        = "Eingabefelder: Hintergrund",
  col_buttonbg           = "Buttons: Hintergrund",
  col_toolbar_text       = "Toolbar: Text",
  col_toolbar_text_on    = "Toolbar: Text (aktiv/bewaffnet)",
  col_toolbar_frame      = "Toolbar: Rahmen",
  toolbararmed_color     = "Toolbar: bewaffneter Button",
  col_trans_fg           = "Transport: Text",
  col_trans_bg           = "Transport: Hintergrund",
  col_transport_editbk   = "Transport: Eingabefeld-Hintergrund",
  io_text                = "Routing-Spalte (IO): Text",
  io_3dhl                = "Routing-Spalte (IO): 3D-Kante hell",
  io_3dsh                = "Routing-Spalte (IO): 3D-Kante Schatten",
  docker_bg              = "Docker: Hintergrund",
  docker_text            = "Docker: Text",
  docker_text_sel        = "Docker: Text (ausgewählter Tab)",
  docker_selface        = "Docker: ausgewählter Tab",
  docker_unselface      = "Docker: nicht ausgewählter Tab",
  docker_shadow          = "Docker: Schatten/Trennlinie",
  windowtab_bg           = "Fenster-Tabs (gedockte Fenster): Hintergrund",
  genlist_bg             = "Listen (generisch): Hintergrund",
  genlist_fg             = "Listen (generisch): Text",
  genlist_grid           = "Listen (generisch): Gitternetz",
  genlist_selbg          = "Listen (generisch): Auswahl-Hintergrund",
  genlist_selfg          = "Listen (generisch): Auswahl-Text",
  genlist_seliabg        = "Listen (generisch): inaktive Auswahl, Hintergrund",
  genlist_seliafg        = "Listen (generisch): inaktive Auswahl, Text",
  score_bg               = "Notation (Score): Hintergrund",
  score_fg               = "Notation (Score): Noten/Text",
  score_loop             = "Notation (Score): Loop-Bereich",
  score_sel              = "Notation (Score): Auswahl",
  score_timesel          = "Notation (Score): Zeit-Auswahl",
  -- VU ---------------------------------------------------------------------
  col_vudoint            = "VU: Punkte-Anzeige (0 = aus, 1 = an)",
  col_vubot              = "VU: Hintergrund unten",
  col_vutop              = "VU: Hintergrund oben",
  col_vumid              = "VU: Mittelteil",
  col_vuind1             = "VU: Anzeigefarbe 1",
  col_vuind2             = "VU: Anzeigefarbe 2",
  col_vuind3             = "VU: Anzeigefarbe 3",
  col_vuind4             = "VU: Anzeigefarbe 4",
  col_vuclip             = "VU: Clip-Anzeige",
  col_vuintcol           = "VU: Innenfläche",
  col_vumidi             = "VU: MIDI-Aktivität",
  -- MIDI -------------------------------------------------------------------
  midi_rulerbg           = "MIDI: Ruler-Hintergrund",
  midi_rulerfg           = "MIDI: Ruler-Text",
  midi_grid1             = "MIDI: Raster 1 (z.B. 16tel)",
  midi_grid2             = "MIDI: Raster 2 (z.B. 8tel)",
  midi_grid3             = "MIDI: Raster 3 (z.B. Takt)",
  midi_gridh             = "MIDI: Notenlinien (H-Linien)",
  midi_gridhc            = "MIDI: Notenlinien (C-Linie, heller)",
  midi_trackbg1          = "MIDI: Spur-Hintergrund 1",
  midi_trackbg2          = "MIDI: Spur-Hintergrund 2",
  midi_trackbg_outer1    = "MIDI: Rand oben/unten 1",
  midi_trackbg_outer2    = "MIDI: Rand oben/unten 2",
  midi_inline_trackbg1   = "Inline-MIDI-Editor: Hintergrund 1",
  midi_inline_trackbg2   = "Inline-MIDI-Editor: Hintergrund 2",
  midi_leftbg            = "MIDI: Piano-Keyboard links (Hintergrund)",
  midi_pkey1             = "MIDI: Piano-Tasten (weiße Tasten)",
  midi_pkey2             = "MIDI: Piano-Tasten (schwarze Tasten)",
  midi_pkey3             = "MIDI: Piano-Tasten (gedrückt)",
  midi_notebg            = "MIDI: Note-Hintergrund",
  midi_notefg            = "MIDI: Note-Rahmen/Text",
  midi_notemute          = "MIDI: gemutete Note",
  midi_notemute_sel      = "MIDI: gemutete Note (ausgewählt)",
  midi_noteon_flash      = "MIDI: NoteOn-Blitz",
  midi_itemctl           = "MIDI: Item-Steuerleiste unten",
  midi_editcurs          = "MIDI: Edit-Cursor",
  midi_ofsn              = "MIDI: Notennamen (Hintergrund)",
  midi_ofsnsel           = "MIDI: Notennamen (ausgewählt)",
  midi_selbg             = "MIDI: Auswahl-Hintergrund",
  midi_selpitch1         = "MIDI: Pitch-Auswahl 1",
  midi_selpitch2         = "MIDI: Pitch-Auswahl 2",
  midi_endpt             = "MIDI: Noten-Endpunkte",
  midifont_col_dark      = "MIDI: Schrift auf hellem Grund",
  midifont_col_light     = "MIDI: Schrift auf dunklem Grund",
  midioct                = "MIDI: Oktav-Trennlinien",
  midioct_inline         = "MIDI: Oktav-Linien (Inline-Editor)",
  midi_ccbut             = "MIDI: CC-Buttons/Regler",
  -- Hüllkurven -------------------------------------------------------------
  col_envlane1_divline   = "Hüllkurven-Lane: Trennlinie 1",
  col_envlane2_divline   = "Hüllkurven-Lane: Trennlinie 2",
  env_track_mute         = "Hüllkurve: Track-Mute",
  env_sends_mute         = "Hüllkurve: Send-Mute",
  env_item_vol           = "Hüllkurve: Item-Volumen",
  env_item_pan           = "Hüllkurve: Item-Pan",
  env_item_mute          = "Hüllkurve: Item-Mute",
  env_item_pitch         = "Hüllkurve: Item-Pitch",
  -- Marker & Ruler ----------------------------------------------------------
  marker                 = "Marker: Farbe",
  region                 = "Region: Farbe",
  marker_lane_bg         = "Ruler: Marker-Lane Hintergrund",
  marker_lane_text       = "Ruler: Marker-Lane Text",
  region_lane_bg         = "Ruler: Regionen-Lane Hintergrund",
  region_lane_text       = "Ruler: Regionen-Lane Text",
  ts_lane_bg             = "Ruler: Taktart-Lane Hintergrund",
  ts_lane_text           = "Ruler: Taktart-Lane Text",
  col_tsigmark           = "Ruler: Taktart-Markierung",
  -- Sonstiges ---------------------------------------------------------------
  cc_chase_drawmode      = "CC-Chase-Anzeige: Draw-Modus",
  guideline_drawmode     = "Guide-Line: Draw-Modus",
  marquee_drawmode       = "Marquee-Auswahl: Draw-Modus",
  marqueezoom_drawmode   = "Marquee-Zoom: Draw-Modus",
  playcursor_drawmode    = "Play-Cursor: Draw-Modus",
  toolbararmed_drawmode  = "Toolbar (bewaffnet): Draw-Modus",
  tcplocked_drawmode     = "TCP-Schloss: Draw-Modus",
  fadezone_drawmode      = "Fade-Zone: Draw-Modus",
  fadearea_drawmode      = "Fade-Fläche: Draw-Modus",
  col_mi_fade2_drawmode  = "Auto-Crossfade-Fläche: Draw-Modus",
  midi_selbg_drawmode    = "MIDI-Auswahl: Draw-Modus",
  ui_img                 = "Theme-Bildpaket (.ReaperThemeZip) – nur Anzeige",
}

-- Hüllkurven 1-16 + Gruppenfarben ergänzen
for i = 1, 16 do
  DESC["col_env" .. i] = "Hüllkurven-Automation: Farbe " .. i
end
for i = 0, 31 do
  DESC["group_" .. i] = "Spur-Gruppe " .. (i + 1) .. ": Farbe"
end

-- Kategorie-Zuordnung (Reihenfolge = Tab-Reihenfolge)
local CATEGORY_ORDER = {
  { id = "items", label = "Items & Arrange" },
  { id = "tcp",   label = "TCP (Spurliste)" },
  { id = "mcp",   label = "MCP (Mixer)" },
  { id = "ui",    label = "Fenster & UI" },
  { id = "midi",  label = "MIDI-Editor" },
  { id = "env",   label = "Hüllkurven" },
  { id = "ruler", label = "Marker & Ruler" },
  { id = "vu",    label = "VU-Meter" },
  { id = "groups", label = "Gruppenfarben" },
  { id = "misc",  label = "Sonstige" },
}

local function classify(key)
  if key:match("^col_env%d+$") or key:match("^env_") or key:match("^col_envlane") then return "env" end
  if key:match("^group_%d+$") then return "groups" end
  if key:match("^midi") or key:match("^midioct") then return "midi" end
  if key:match("^mcp_") then return "mcp" end
  if key:match("tcp") then return "tcp" end
  if key:match("^col_vu") then return "vu" end
  if key:match("^marker") or key:match("^region") or key:match("_lane_")
     or key == "col_tsigmark" or key:match("^ts_lane") then return "ruler" end
  if key:match("^col_mi_") or key:match("item") or key:match("peaks")
     or key:match("^col_tr[12]_") or key:match("stretch") or key:match("fade")
     or key:match("^selitem") or key:match("^col_tl_") or key:match("grid")
     or key:match("cursor") or key:match("marquee") or key:match("timesel")
     or key:match("guideline") or key:match("^col_arrange")
     or key:match("^col_tracklist") or key:match("^col_mixerbg")
     or key:match("^col_seltrack") or key:match("^col_offlinetext")
     or key:match("^col_routing") then return "items" end
  if DESC[key] then return "ui" end
  return "misc"
end

local function is_drawmode_key(key)
  return key:find("drawmode", 1, true) ~= nil
    or key:match("_mode$") ~= nil
    or key:match("dm%d*$") ~= nil
    or key == "col_stretchmarkerm"
end

local DRAWMODE_NAMES = {
  "Deckend (0)",
  "Modus 1",
  "Alpha-Blend (2)",
  "Alpha-Blend (3)",
}

-- =========================================================================
-- 3. State
-- =========================================================================

local EXT_SECTION = "theme_adjuster"

local S = {
  theme_files  = {},        -- { {name=..., path=...} }
  theme_sel    = 0,         -- 0-based Combo-Index
  path         = "",
  eol          = "\r\n",
  lines        = {},        -- { {text=..., section=...} } Rohzeilen
  entries      = {},        -- { {key, line_idx, orig, cur, section, cat, is_drawmode, is_int} }
  map          = {},        -- key -> entry
  search       = "",
  presets      = {},        -- { name=... }
  preset_sel   = 0,
  preset_buf   = "",
  status       = "",
  window_open  = true,
}

local ctx

-- =========================================================================
-- 4. Hilfsfunktionen: Farben & Draw-Modus
-- =========================================================================

-- Theme-Farben sind 0xAABBGGRR als signed 32-bit (COLORREF, BGR!)
local function theme_to_rgba(v)
  if v < 0 then v = v + 4294967296 end
  local R =  v        & 0xFF
  local G = (v >> 8)  & 0xFF
  local B = (v >> 16) & 0xFF
  local A = (v >> 24) & 0xFF
  return R / 255, G / 255, B / 255, (A == 0 and 1 or A / 255), A
end

local function rgba_to_theme(R, G, B, A)
  local v = (R & 0xFF) | ((G & 0xFF) << 8) | ((B & 0xFF) << 16) | ((A & 0xFF) << 24)
  if v >= 2147483648 then v = v - 4294967296 end
  return v
end

-- Draw-Modus: Modus im hohen Wort, Alpha in Bits 8-15, Flags in Bits 0-7
local function decode_drawmode(v)
  if v < 0 then v = v + 4294967296 end
  local mode  = (v >> 16) & 0xFFFF
  local alpha = (v >> 8)  & 0xFF
  local flags =  v        & 0xFF
  return mode, alpha, flags
end

local function encode_drawmode(mode, alpha, flags)
  local v = ((mode & 0xFFFF) << 16) | ((alpha & 0xFF) << 8) | (flags & 0xFF)
  if v >= 2147483648 then v = v - 4294967296 end
  return v
end

-- =========================================================================
-- 5. Theme laden / speichern
-- =========================================================================

local function list_theme_files()
  S.theme_files = {}
  local sep = r.GetOS():match("^Win") and "\\" or "/"
  local dir = r.GetResourcePath() .. sep .. "ColorThemes"
  local i = 0
  repeat
    local file = r.EnumerateFiles(dir, i)
    if file ~= "" and file:match("%.ReaperTheme$") then
      S.theme_files[#S.theme_files + 1] = { name = file, path = dir .. "/" .. file }
    end
    i = i + 1
  until file == ""
  table.sort(S.theme_files, function(a, b) return a.name:lower() < b.name:lower() end)
end

local function load_theme(path)
  local f = io.open(path, "rb")
  if not f then
    S.status = "Konnte Datei nicht öffnen: " .. tostring(path)
    return false
  end
  local content = f:read("*a")
  f:close()
  S.eol = content:find("\r\n", 1, true) and "\r\n" or "\n"
  S.path = path
  S.lines, S.entries, S.map = {}, {}, {}
  local section = ""
  for text in content:gmatch("([^\r\n]*)") do
    S.lines[#S.lines + 1] = { text = text, section = section }
    local idx = #S.lines
    local sec = text:match("^%[(.+)%]$")
    if sec then
      section = sec
      S.lines[idx].section = sec
    else
      local key, val = text:match("^([^=%s]+)%s*=%s*(.-)%s*$")
      if key then
        local is_int = val:match("^-?%d+$") ~= nil
        local e = {
          key = key,
          line_idx = idx,
          orig = val,
          cur = val,
          section = section,
          is_int = is_int,
          is_drawmode = section == "color theme" and is_int and is_drawmode_key(key),
        }
        e.cat = (section == "color theme") and classify(key) or "misc"
        S.entries[#S.entries + 1] = e
        S.map[key] = e
      end
    end
  end
  S.status = "Geladen: " .. path
  return true
end

local function count_changed()
  local n = 0
  for _, e in ipairs(S.entries) do
    if e.cur ~= e.orig then n = n + 1 end
  end
  return n
end

local function build_content()
  local out = {}
  for i, ln in ipairs(S.lines) do
    local text = ln.text
    for _, e in ipairs(S.entries) do
      if e.line_idx == i then
        text = e.key .. "=" .. e.cur
        break
      end
    end
    out[#out + 1] = text
  end
  return table.concat(out, S.eol)
end

local function write_theme(path)
  -- einmaliges Backup der unangetasteten Originaldatei
  local bak = path .. ".theme_adjuster.bak"
  local fbak = io.open(bak, "rb")
  if not fbak then
    local src = io.open(path, "rb")
    if src then
      local data = src:read("*a")
      src:close()
      local dst = io.open(bak, "wb")
      if dst then dst:write(data) dst:close() end
    end
  else
    fbak:close()
  end
  local f = io.open(path, "wb")
  if not f then return false, "Datei nicht schreibbar" end
  f:write(build_content())
  f:close()
  return true
end

local function save_current()
  if S.path == "" then return end
  local ok, err = write_theme(S.path)
  if ok then
    for _, e in ipairs(S.entries) do e.orig = e.cur end
    S.status = "Gespeichert: " .. S.path
  else
    S.status = "Fehler beim Speichern: " .. tostring(err)
  end
end

local function save_as_copy()
  if S.path == "" then return end
  local default = S.theme_files[S.theme_sel + 1] and S.theme_files[S.theme_sel + 1].name or ""
  local name = default:gsub("%.ReaperTheme$", "") .. " angepasst"
  local ok, answer = r.GetUserInputs("Theme-Kopie speichern", 1,
    "Dateiname (ohne .ReaperTheme),extrawidth=240", name)
  if not ok or answer == "" then return end
  answer = answer:gsub("[\\/:*?\"<>|]", "_")
  local dir = S.path:match("^(.*)[/\\][^/\\]+$") or r.GetResourcePath() .. "/ColorThemes"
  local path = dir .. "/" .. answer .. ".ReaperTheme"
  local f = io.open(path, "wb")
  if not f then S.status = "Konnte Datei nicht anlegen." return end
  f:write(build_content())
  f:close()
  list_theme_files()
  for i, tf in ipairs(S.theme_files) do
    if tf.path == path then S.theme_sel = i - 1 break end
  end
  load_theme(path)
  S.status = "Kopie gespeichert: " .. path
end

-- =========================================================================
-- 6. Presets (ExtState)
-- =========================================================================

local function preset_data_key(name) return "preset::" .. name end

local function load_preset_list()
  S.presets = {}
  local names = r.GetExtState(EXT_SECTION, "preset_names")
  for name in (names .. ","):gmatch("([^,]*),") do
    if name ~= "" then S.presets[#S.presets + 1] = name end
  end
  table.sort(S.presets)
end

local function store_preset_list()
  r.SetExtState(EXT_SECTION, "preset_names", table.concat(S.presets, ","), true)
end

local function preset_save(name)
  if name == "" then S.status = "Bitte zuerst einen Preset-Namen eingeben." return end
  if name:find(",", 1, true) then name = name:gsub(",", "_") end
  local kv = {}
  for _, e in ipairs(S.entries) do
    if e.section == "color theme" then
      kv[#kv + 1] = e.key .. "=" .. e.cur
    end
  end
  r.SetExtState(EXT_SECTION, preset_data_key(name), table.concat(kv, "\n"), true)
  local exists = false
  for _, n in ipairs(S.presets) do if n == name then exists = true break end end
  if not exists then
    S.presets[#S.presets + 1] = name
    store_preset_list()
  end
  S.preset_buf = ""
  S.status = "Preset gespeichert: " .. name
end

local function preset_apply(name)
  local data = r.GetExtState(EXT_SECTION, preset_data_key(name))
  if data == "" then S.status = "Preset ist leer." return end
  local n = 0
  for kv in data:gmatch("[^\n]+") do
    local key, val = kv:match("^([^=]+)=(.-)$")
    local e = key and S.map[key]
    if e and e.section == "color theme" then
      e.cur = val
      n = n + 1
    end
  end
  S.status = string.format("Preset '%s' angewendet (%d Werte) – noch speichern!", name, n)
end

local function preset_delete(name)
  r.SetExtState(EXT_SECTION, preset_data_key(name), "", false)
  for i, n in ipairs(S.presets) do
    if n == name then table.remove(S.presets, i) break end
  end
  store_preset_list()
  S.preset_sel = 0
  S.status = "Preset gelöscht: " .. name
end

-- =========================================================================
-- 7. GUI: Zeilen-Widgets
-- =========================================================================

local function set_status_changed()
  S.status = string.format("%d Wert(e) geändert – Theme speichern nicht vergessen.", count_changed())
end

local function entry_widget(e)
  local label = "##" .. e.key
  local changed = false
  if e.is_drawmode then
    local mode, alpha, flags = decode_drawmode(tonumber(e.cur) or 0)
    local mode_names = {}
    for i = 0, math.max(mode, 3) do
      mode_names[#mode_names + 1] = DRAWMODE_NAMES[i + 1] or ("Modus " .. i)
    end
    local _, new_mode = I.Combo(ctx, label .. "_mode", mode, mode_names, #mode_names)
    I.SameLine(ctx)
    I.SetNextItemWidth(ctx, 90)
    local _, new_alpha = I.SliderInt(ctx, label .. "_alpha", alpha, 0, 255,
      string.format("Alpha %d", alpha))
    I.SameLine(ctx)
    I.SetNextItemWidth(ctx, 50)
    local _, new_flags = I.InputInt(ctx, label .. "_flags", flags, 0, 0)
    local v = encode_drawmode(new_mode, new_alpha, new_flags)
    if v ~= tonumber(e.cur) then
      e.cur = tostring(v)
      changed = true
    end
    if I.IsItemHovered(ctx) then
      I.SetTooltip(ctx, "Modus + Deckkraft (Alpha) + Flags, zusammengesetzt:\n"
        .. e.key .. " = " .. e.cur)
    end
  elseif e.key == "col_vudoint" then
    local on = (tonumber(e.cur) or 0) ~= 0
    local _, new = I.Checkbox(ctx, label, on)
    local v = new and 1 or 0
    if v ~= tonumber(e.cur) then
      e.cur = tostring(v)
      changed = true
    end
  elseif e.is_int then
    local R, G, B, A, A_raw = theme_to_rgba(tonumber(e.cur) or 0)
    local _, nr, ng, nb, na = I.ColorEdit4(ctx, label, R, G, B, A)
    local v = rgba_to_theme(math.floor(nr * 255 + 0.5), math.floor(ng * 255 + 0.5),
                            math.floor(nb * 255 + 0.5), math.floor(na * 255 + 0.5))
    if v ~= tonumber(e.cur) then
      e.cur = tostring(v)
      changed = true
    end
    if I.IsItemHovered(ctx) then
      I.SetTooltip(ctx, e.key .. " = " .. e.cur
        .. (A_raw > 0 and "\nAlpha-Kanal aktiv (halbdurchsichtig)" or "\nDeckend (kein Alpha)"))
    end
  else
    I.TextDisabled(ctx, e.cur ~= "" and e.cur or "(leer)")
    if I.IsItemHovered(ctx) then I.SetTooltip(ctx, e.key .. " = " .. e.cur) end
  end
  if changed then set_status_changed() end
  -- Rechtsklick: auf Ausgangswert zurücksetzen
  if I.IsItemClicked(ctx, 1) and e.cur ~= e.orig then
    e.cur = e.orig
    set_status_changed()
  end
end

local function entry_row(e)
  I.TableNextRow(ctx)
  I.TableSetColumnIndex(ctx, 0)
  local desc = DESC[e.key] or e.key
  I.TextUnformatted(ctx, desc)
  if I.IsItemHovered(ctx) then
    I.SetTooltip(ctx, e.key .. "\nRechtsklick auf den Wert setzt ihn zurück.")
  end
  I.TableSetColumnIndex(ctx, 1)
  entry_widget(e)
end

local function render_entries(list)
  if #list == 0 then
    I.TextDisabled(ctx, "– keine Werte in dieser Kategorie –")
    return
  end
  I.BeginTable(ctx, "entries", 2)
  I.TableSetupColumn(ctx, "Beschreibung", 0, 420)
  I.TableSetupColumn(ctx, "Wert")
  for _, e in ipairs(list) do
    entry_row(e)
  end
  I.EndTable(ctx)
end

local function matches_search(e)
  if S.search == "" then return true end
  local q = S.search:lower()
  return e.key:lower():find(q, 1, true) ~= nil
    or (DESC[e.key] or ""):lower():find(q, 1, true) ~= nil
end

-- =========================================================================
-- 8. GUI: Hauptframe
-- =========================================================================

local function push_theme_style()
  local n = 0
  n = n + push_color("WindowBg", THEME_UI.WindowBg)
  n = n + push_color("PopupBg", THEME_UI.PopupBg)
  n = n + push_color("FrameBg", THEME_UI.FrameBg)
  n = n + push_color("FrameBgHovered", THEME_UI.FrameBgHovered)
  n = n + push_color("FrameBgActive", THEME_UI.FrameBgActive)
  n = n + push_color("TitleBg", THEME_UI.TitleBg)
  n = n + push_color("Button", THEME_UI.Button)
  n = n + push_color("ButtonHovered", THEME_UI.ButtonHovered)
  n = n + push_color("ButtonActive", THEME_UI.ButtonActive)
  n = n + push_color("Header", THEME_UI.Header)
  n = n + push_color("HeaderHovered", THEME_UI.HeaderHovered)
  n = n + push_color("HeaderActive", THEME_UI.HeaderActive)
  n = n + push_color("Tab", THEME_UI.Tab)
  n = n + push_color("TabHovered", THEME_UI.TabHovered)
  n = n + push_color("TabActive", THEME_UI.TabActive)
  n = n + push_color("Text", THEME_UI.Text)
  n = n + push_color("TextDisabled", THEME_UI.TextDisabled)
  n = n + push_color("CheckMark", THEME_UI.CheckMark)
  n = n + push_color("SliderGrab", THEME_UI.SliderGrab)
  n = n + push_color("Border", THEME_UI.Border)
  return n
end

local function top_bar()
  -- Theme-Auswahl
  local names = {}
  for _, tf in ipairs(S.theme_files) do names[#names + 1] = tf.name end
  I.SetNextItemWidth(ctx, 260)
  local changed, sel = I.Combo(ctx, "##theme", S.theme_sel, names, #names)
  if changed then
    S.theme_sel = sel
    if S.theme_files[sel + 1] then load_theme(S.theme_files[sel + 1].path) end
    r.SetExtState(EXT_SECTION, "last_theme", S.theme_files[sel + 1].name, true)
  end
  I.SameLine(ctx)
  if I.Button(ctx, "Neu laden") and S.theme_files[S.theme_sel + 1] then
    load_theme(S.theme_files[S.theme_sel + 1].path)
  end
  I.SameLine(ctx)
  if I.Button(ctx, "Speichern") then save_current() end
  I.SameLine(ctx)
  if I.Button(ctx, "Speichern unter …") then save_as_copy() end
  I.SameLine(ctx)
  local n = count_changed()
  if n > 0 then
    I.TextColored(ctx, 0xFF9EC6FF, n .. " Wert(e) geändert")
  else
    I.TextDisabled(ctx, "keine ungespeicherten Änderungen")
  end
end

local function preset_bar()
  if #S.presets == 0 then
    I.TextDisabled(ctx, "keine Presets")
  else
    I.SetNextItemWidth(ctx, 220)
    local changed, sel = I.Combo(ctx, "##preset", S.preset_sel, S.presets, #S.presets)
    if changed then S.preset_sel = sel end
    I.SameLine(ctx)
    if I.Button(ctx, "Anwenden") then
      local name = S.presets[S.preset_sel + 1]
      if name then preset_apply(name) end
    end
    I.SameLine(ctx)
    if I.Button(ctx, "Löschen") then
      local name = S.presets[S.preset_sel + 1]
      if name then preset_delete(name) end
    end
    I.SameLine(ctx)
  end
  I.SetNextItemWidth(ctx, 180)
  local changed, buf = I.InputText(ctx, "##presetname", S.preset_buf)
  if changed then S.preset_buf = buf end
  I.SameLine(ctx)
  if I.Button(ctx, "Preset speichern") then preset_save(S.preset_buf) end
  if I.IsItemHovered(ctx) then
    I.SetTooltip(ctx, "Sichert alle Farbwerte des geladenen Themes als Preset.")
  end
end

local function search_bar()
  I.SetNextItemWidth(ctx, 260)
  local changed, buf = I.InputText(ctx, "##search", S.search)
  if changed then S.search = buf end
  I.SameLine(ctx)
  I.TextDisabled(ctx, "Suche in Key + Beschreibung (überschreibt die Tabs)")
end

local function frame()
  local pushed = push_theme_style()
  I.SetNextWindowSize(ctx, 780, 640, 1) -- Kondition 1 = immer
  local visible, open = I.Begin(ctx, "Theme Adjuster", true, 0)
  if visible then
    top_bar()
    I.Separator(ctx)
    preset_bar()
    I.Separator(ctx)
    search_bar()
    I.Separator(ctx)

    if S.search ~= "" then
      local hits = {}
      for _, e in ipairs(S.entries) do
        if matches_search(e) then hits[#hits + 1] = e end
      end
      I.BeginChild(ctx, "searchresults", 0, 0)
      render_entries(hits)
      I.EndChild(ctx)
    else
      if I.BeginTabBar(ctx, "cats") then
        for _, cat in ipairs(CATEGORY_ORDER) do
          local list = {}
          for _, e in ipairs(S.entries) do
            if e.cat == cat.id then list[#list + 1] = e end
          end
          if I.BeginTabItem(ctx, cat.label .. " (" .. #list .. ")") then
            I.BeginChild(ctx, "cat_" .. cat.id, 0, 0)
            render_entries(list)
            I.EndChild(ctx)
            I.EndTabItem()
          end
        end
        I.EndTabBar(ctx)
      end
    end

    I.Separator(ctx)
    I.TextDisabled(ctx, S.status ~= "" and S.status or " ")
    if S.path ~= "" then
      I.SameLine(ctx)
      I.TextDisabled(ctx, "Backup: " .. S.path .. ".theme_adjuster.bak (automatisch)")
    end
  end
  I.End(ctx)
  I.PopStyleColor(ctx, pushed)
  if not open then S.window_open = false end
end

-- =========================================================================
-- 9. Start / Loop
-- =========================================================================

list_theme_files()
load_preset_list()

local last = r.GetExtState(EXT_SECTION, "last_theme")
for i, tf in ipairs(S.theme_files) do
  if tf.name == last then S.theme_sel = i - 1 break end
end
if S.theme_files[S.theme_sel + 1] then
  load_theme(S.theme_files[S.theme_sel + 1].path)
elseif S.theme_files[1] then
  S.theme_sel = 0
  load_theme(S.theme_files[1].path)
else
  r.ShowMessageBox("Keine .ReaperTheme-Dateien im ColorThemes-Ordner gefunden.\n"
    .. "(.ReaperThemeZip wird nicht unterstützt – bitte vorher entpacken.)",
    "Theme Adjuster", 0)
  return
end

ctx = r.ImGui_CreateContext("Theme Adjuster")

local function loop()
  if S.window_open then
    frame()
    r.defer(loop)
  else
    r.ImGui_DestroyContext(ctx)
  end
end
r.defer(loop)
