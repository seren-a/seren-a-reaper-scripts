-- @description Spuren mit Plugin abwählen
-- @author seren.a
-- @about Wählt aus der aktuellen Auswahl alle Spuren ab, deren FX-Kette ein Plugin mit diesem Namen enthält.

-- ========== Eingabe ==========
local ok, query = reaper.GetUserInputs("Spuren mit Plugin abwählen", 1,
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
local n = 0
for i = 0, reaper.CountTracks(0) - 1 do
  local tr = reaper.GetTrack(0, i)
  if reaper.IsTrackSelected(tr) and track_has_fx(tr, query) then
    reaper.SetTrackSelected(tr, false); n = n + 1
  end
end
reaper.Undo_EndBlock("Spuren mit Plugin '" .. query .. "' abwählen", -1)
reaper.ShowConsoleMsg(n .. " Spur(en) mit '" .. query .. "' abgewählt\n")
