-- ============================================================================
-- INTERAKTIVER JAHRESKALENDER (Optimiertes 2x6 Raster für 320x240 / 53x30)
-- MIT NATIVEM RTC-HEUTE-HIGHLIGHT
-- ============================================================================

-- --- CONFIGURATION (Angepasst an Ihre 64-Farben-Palette) ---
local COL_TITEL       = 63  -- Weiß
local COL_MONAT       = 31  -- Cyan / Hellblau
local COL_WOCHENTAG   = 60  -- Gelb / Orange
local COL_TAGE        = 63  -- Weiß
local COL_HEUTE       = 48  -- Rot (Highlight-Hintergrund)
local COL_HINTERGRUND = 0   -- Schwarz

-- Monatsnamen und Tage
local MONATE = { "Januar", "Februar", "Maerz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember" }
local TAGE_PRO_MONAT = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- --- MATHEMATISCHE HILFSFUNKTIONEN ---

-- Prueft, ob ein Jahr ein Schaltjahr ist
local function istSchaltjahr(jahr)
    return (jahr % 4 == 0 and jahr % 100 ~= 0) or (jahr % 400 == 0)
end

-- Zellers Kongruenz: Berechnet den Wochentag für den 1. eines Monats
-- Rueckgabe: 1 = Montag, 2 = Dienstag, ..., 7 = Sonntag
local function wochentagErster(monat, jahr)
    local m = monat
    local y = jahr
    if m < 3 then
        m = m + 12
        y = y - 1
    end
    local k = y % 100
    local j = math.floor(y / 100)
    
    local h = (1 + math.floor((13 * (m + 1)) / 5) + k + math.floor(k / 4) + math.floor(j / 4) - 2 * j) % 7
    local ISO_Wochentag = ((h + 5) % 7) + 1
    return ISO_Wochentag
end

-- --- ZEICHEN-LOGIK ---

-- Zeichnet das kompakte 2x6 Kalender-Raster fuer das gewaehlte Jahr
local function zeichneKalender(zielJahr)
    vga.cls()
    
    -- Heute-Datum aus Ihrer RTC-C++-Funktion holen
    local heuteTag, heuteMonat, heuteJahr = sys.getdate()
    -- print(heuteTag .. heuteMonat .. heuteJahr)
    
    -- === 1. ÜBERSCHRIFTEN IM STANDARD-FONT RECHTS UND UNTEN SCHÜTZEN ===
    -- Da der Haupt-Font 6x8 nutzt, platzieren wir die Titel so, dass sie sich nicht beißen
    local titelText = "=== JAHRESKALENDER " .. zielJahr .. " ==="
    vga.text(12, 0, titelText, COL_TITEL, COL_HINTERGRUND)
    vga.text(7, 29, "Beliebige Taste = Neue Eingabe | ESC = Ende", 42, 0)

    -- Schaltjahr-Anpassung für den Februar
    if istSchaltjahr(zielJahr) then
        TAGE_PRO_MONAT[2] = 29
    else
        TAGE_PRO_MONAT[2] = 28
    end

    local WOCHENTAGE_KOPF = { "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So" }

    -- === 2. DAS GESTRECKTE 3x4 RASTER (Nativ im 80x40 Mini-Gitter von Font 15) ===
    for m = 1, 12 do
        local spalte = (m - 1) % 3             -- 0, 1, 2
        local zeile  = math.floor((m - 1) / 3) -- 0, 1, 2, 3
        
        -- HORIZONTALE VERTEILUNG (Volle 80 Spalten ausnutzen):
        local startX = 4 + (spalte * 26)   
        
        -- VERTIKALE VERTEILUNG (Genügend Raum gegen Überschreiben):
        local startY = 2 + (zeile * 9)         
        
        -- Monatsname zentrieren (Über den 21 Spalten Breite des Monatsblocks)
        local monatsName = MONATE[m]
        local pad = math.floor((21 - string.len(monatsName)) / 2)
        vga.text(startX + pad, startY, monatsName, COL_MONAT, COL_HINTERGRUND, 15)
        
        -- WOCHENTAGE (Perfekt fluchtend, da linear im selben Raster)
        local aktuellerDruckX = startX
        for w = 1, 7 do
            vga.text(aktuellerDruckX, startY + 1, WOCHENTAGE_KOPF[w], COL_WOCHENTAG, COL_HINTERGRUND, 15)
            aktuellerDruckX = aktuellerDruckX + 3
        end
        
        -- Schöne Trennlinie unter die Tage ziehen
        vga.text(startX, startY + 2, "--------------------", 42, COL_HINTERGRUND, 15)
        
        -- Wo fängt der erste Tag an?
        local startWochentag = wochentagErster(m, zielJahr)
        
        -- Startpunkt für den 1. des Monats
        aktuellerDruckX = startX + ((startWochentag - 1) * 3)
        local aktuellerDruckY = startY + 3
        
        -- Alle Tage des Monats nacheinander einsetzen
        for tag = 1, TAGE_PRO_MONAT[m] do
            local tagText = string.format("%2d", tag)
            
            local farbe = COL_TAGE
            local hintergrund = COL_HINTERGRUND
            if tag == heuteTag and m == heuteMonat and zielJahr == heuteJahr then
                farbe = COL_TITEL
                hintergrund = COL_HEUTE
            end
            
            -- Pure, native Koordinaten-Übergabe ohne jegliche Umrechnungs-Formel!
            vga.text(aktuellerDruckX, aktuellerDruckY, tagText, farbe, hintergrund, 15)
            
            -- Im Raster 3 Spalten weitergehen
            aktuellerDruckX = aktuellerDruckX + 3
            
            -- Wenn Sonntag vorbei ist (7 Tage gedruckt) -> Zeilenumbruch im Block
            if (aktuellerDruckX - startX) >= 21 then
                aktuellerDruckX = startX 
                aktuellerDruckY = aktuellerDruckY + 1 
            end
        end
    end
end
-- ============================================================================
-- INTERAKTIVE HAUPTSCHLEIFE
-- ============================================================================
local running = true

while running do
    -- 1. Eingabe-Aufforderung im Terminal (Perfekt angepasst auf 53er Breite)
    vga.cls()
    vga.text(5, 10, "========================================", COL_WOCHENTAG, 0)
    vga.text(5, 11, "        OS KALENDER-STEUERUNG           ", COL_TITEL, 0)
    vga.text(5, 12, "========================================", COL_WOCHENTAG, 0)
    vga.waitsync()
    vga.text(5, 15, "Jahr eingeben (z.B. 2026) oder ESC:", COL_TAGE, 0)

    -- Wir holen uns das aktuelle Jahr als Standardwert aus der RTC
    local _, _, rtcJahr = sys.getdate()
    
    local eingabeString = ""
    --vga.text(45, 15, "_", COL_TITEL, 0) -- Cursor-Dummy
    
    while true do
        local t = waitkey(false) -- Nutzt Ihre blockierende Tastatur-Wartefunktion
        
        if t == 13 or t == "enter" then -- ENTER -> Eingabe fertig
            break
        elseif t == 27 then -- ESC -> Abbrechen
            running = false
            break
        elseif t == 127 and string.len(eingabeString) > 0 then -- BACKSPACE
            eingabeString = string.sub(eingabeString, 1, -2)
            vga.text(48 + string.len(eingabeString), 15, "  ") -- Zeichen putzen
        elseif t >= 48 and t <= 57 then -- Nur Zahlen zulassen
            if string.len(eingabeString) < 4 then
                eingabeString = eingabeString .. string.char(t)
                vga.text(40, 15, eingabeString .. "_", COL_TITEL, 0)
            end
        end
        delay(10)
    end
    
    -- Wenn die Schleife nicht per ESC abgebrochen wurde, Kalender anzeigen
    if running then
        local gewaehltesJahr = tonumber(eingabeString) or rtcJahr
        
        -- Kalender-Raster aufbauen
        zeichneKalender(gewaehltesJahr)
        
        -- Warten. ESC beendet, jede andere Taste führt zurück zur Eingabe
        local endTaste = waitkey(false)
        if endTaste == 27 then
            running = false
        end
    end
end

-- Nach dem Beenden Schirm putzen fürs Terminal
vga.cls()
print("Kalender beendet. Zurueck zur Shell.")