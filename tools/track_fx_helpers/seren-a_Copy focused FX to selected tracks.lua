-- @description Fokussiertes FX auf alle ausgewählten Spuren kopieren
-- @author seren.a
-- @about Kopiert das FX, dessen Fenster gerade den Fokus hat, samt Einstellungen ans Ende der FX-Kette jeder ausgewählten Spur.

-- ========== Quelle bestimmen ==========
local rv, trNum, _, fxNum = reaper.GetFocusedFX2()
if rv == 0 or fxNum < 0 then
  reaper.ShowMessageBox("Erst ein FX-Fenster anklicken (Fokus).", "Hinweis", 0)
  return
end
local src = trNum == 0 and reaper.GetMasterTrack(0) or reaper.GetTrack(0, trNum - 1)

-- ========== Kopieren ==========
reaper.Undo_BeginBlock()
local n = 0
for i = 0, reaper.CountSelectedTracks(0) - 1 do
  local tr = reaper.GetSelectedTrack(0, i)
  if tr ~= src then
    reaper.TrackFX_CopyToTrack(src, fxNum, tr, reaper.TrackFX_GetCount(tr), false)
    n = n + 1
  end
end
reaper.Undo_EndBlock("FX auf " .. n .. " Spuren kopiert", -1)
