# track_fx_helpers

Drei kleine ReaScripts (Lua), um Spuren nach ihren Plugins zu filtern und ein FX auf viele Spuren zu verteilen. Gedacht z. B. für die Umstellung von dearVR PRO auf dearVR PRO 2.

| Script | Was es tut |
| --- | --- |
| `seren-a_Select tracks with FX.lua` | Fragt nach einem Suchbegriff und wählt **alle Spuren aus**, die ein Plugin mit diesem Namen enthalten. Vorherige Auswahl wird aufgehoben. |
| `seren-a_Unselect tracks with FX.lua` | Wählt aus der **aktuellen Auswahl** alle Spuren **ab**, die ein Plugin mit diesem Namen enthalten. |
| `seren-a_Copy focused FX to selected tracks.lua` | Kopiert das FX, dessen Fenster gerade den Fokus hat, **samt Einstellungen** ans Ende der Kette jeder ausgewählten Spur. |

## Installation

1. Die `.lua`-Dateien in den REAPER-Script-Ordner legen (Options → Show REAPER resource path → `Scripts/`).
2. Actions → Show action list → **New action… → Load ReaScript…** → Datei(en) wählen.
3. Optional: Shortcut, Toolbar- oder Stream-Deck-Button zuweisen.

## Bedienung

**Suchen:** Groß-/Kleinschreibung egal, ein Teil des Namens reicht (`dearVR` findet v1 und PRO 2). Gesucht wird nach dem Namen, wie er im FX-Fenster steht – umbenannte Plugins unter ihrem neuen Namen. Input-FX und Master-Spur werden nicht durchsucht.

**Filtern (Beispiel):**
1. *Select* mit `dearVR` → alle dearVR-Spuren ausgewählt
2. *Unselect* mit `PRO 2` → die, die schon PRO 2 haben, fallen raus
3. Übrig bleiben die Spuren, die noch umgestellt werden müssen

**FX verteilen:** Das gewünschte FX auf einer Spur öffnen und einstellen, sein Fenster anklicken (Fokus), Zielspuren auswählen, *Copy focused FX* starten.

## Passend dazu (ohne Script)

- **Spurvorlage überschreiben:** Rechtsklick auf die Spur → *Save tracks as track template…* → gleichen Namen wählen → Überschreiben bestätigen.
- **Vorlage / FX-Kette auf vorhandene Spuren anwenden:** mit der SWS-Extension: Action *SWS/S&M: Open Resources window* → oben *Track templates* (bzw. *FX chains*) → Spuren auswählen → Rechtsklick auf Vorlage → *Apply to selected tracks* (bzw. *Paste FX chain to selected tracks*).

Alle drei Scripts sind ein Undo-Schritt.
