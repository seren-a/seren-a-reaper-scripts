-- @description Spuren mit Plugin auswählen
-- @author seren.a
-- @about Fragt nach einem Suchbegriff und wählt alle Spuren, deren FX-Kette ein Plugin mit diesem Namen enthält.

-- ========== Eingabe ==========
local ok, query = reaper.GetUserInputs("Spuren mit Plugin auswählen", 1,
  "Plugin-Name enthält:,extrawidth=150", "dearVR")
if not ok or query == "" then return end
query = query:lower()

-- ========== Hilfsfunktion ==========
local function track_has_fx(tr, q)
  for fx = 0, reaper.TrackFX_GetCount(tr) - 1 do
    local _, name = reaper.TrackFX_GetFXName(tr, fx, "")
    if name:lower():find(q, 1, true) then return true end
  end
  return false
end

-- ========== Ausführen ==========
reaper.Undo_BeginBlock()
reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
local n = 0
for i = 0, reaper.CountTracks(0) - 1 do
  local tr = reaper.GetTrack(0, i)
  if track_has_fx(tr, query) then reaper.SetTrackSelected(tr, true); n = n + 1 end
end
reaper.Undo_EndBlock("Spuren mit Plugin '" .. query .. "' auswählen", -1)
reaper.ShowConsoleMsg(n .. " Spur(en) mit '" .. query .. "' ausgewählt\n")
