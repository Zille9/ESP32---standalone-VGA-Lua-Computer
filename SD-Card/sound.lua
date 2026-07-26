-- ============================================================================
-- FABGL SOUNDBOARD & MINI-KLAVIER (sound_test.lua)
-- ============================================================================

local COL_TITEL = 63   -- Weiß
local COL_TEXT  = 42   -- Grau
local COL_AKTIV = 60   -- Gelb
local COL_NOTE  = 48   -- Rot

vga.cls()
vga.cursor(false) -- Blinkenden Hardware-Cursor ausschalten

-- Start-Konfiguration
local kanal = 1
local dauer = 150
local lautstaerke = 90

-- MIDI-Startnoten für eine saubere C-Dur Tonleiter (Noten 60 bis 72)
local tonleiter = { 24, 26, 28, 29, 31, 33, 35, 36 }
local tastenNamen = { "1", "2", "3", "4", "5", "6", "7", "8" }

local letzteNote = 0
local equalizerBalken = { 0, 0, 0, 0, 0, 0, 0, 0 }

-- --- INTERFACE ZEICHNEN ---
local function zeichneUI()
    vga.cls()
    vga.text(10, 1, "=== ESP32 SOUND-SYNTHESIZER ===", COL_TITEL, 0)
    vga.text(2, 3, "Steuerung:", COL_TEXT, 0)
    vga.text(2, 4, "  Pfeil RECHTS/LINKS : Kanal wechseln  (Aktuell: " .. kanal .. ")", COL_AKTIV, 0)
    vga.text(2, 5, "  Pfeil OBEN/UNTEN   : Dauer anpassen  (Aktuell: " .. dauer .. "ms)", COL_AKTIV, 0)
    vga.text(2, 6, "  Tasten 1 bis 8     : C-Dur Tonleiter abspielen", COL_TEXT, 0)
    vga.text(2, 7, "  ESC                : Zurueck zur Shell", COL_TEXT, 0)
    
    -- Klaviertasten-Optik auf dem Schirm anzeigen
    vga.text(2, 10, "Klaviatur:", COL_TEXT, 0)
    local tX = 2
    for i = 1, 8 do
        local col = COL_TEXT
        if letzteNote == tonleiter[i] then col = COL_NOTE end
        vga.text(tX, 12, "[ " .. tastenNamen[i] .. " ]", col, 0)
        tX = tX + 6
    end
end

-- --- MAIN LOOP ---
zeichneUI()
local running = true

while running do
    local taste = inkey() -- Unblockierendes Lesen dank neuem C++ Core!
    local aktualisieren = false

    if taste ~= 0 then
        -- 1. Beenden mit ESC
        if taste == 27 then
            running = false

        -- 2. Kanal wechseln (Pfeil Links / Rechts)
        elseif taste == 216 then -- KEY_LEFT
            if kanal > 0 then kanal = kanal - 1; aktualisieren = true end
        elseif taste == 215 then -- KEY_RIGHT
            if kanal < 5 then kanal = kanal + 1; aktualisieren = true end

        -- 3. Spieldauer anpassen (Pfeil Oben / Unten)
        elseif taste == 218 then -- KEY_UP
            if dauer < 1000 then dauer = dauer + 50; aktualisieren = true end
        elseif taste == 217 then -- KEY_DOWN
            if dauer > 50 then dauer = dauer - 50; aktualisieren = true end

        -- 4. Noten abspielen (Tasten '1' bis '8')
        else
            for i = 1, 8 do
                if taste == 48 + i or taste == tostring(i) then
                    letzteNote = tonleiter[i]
                    
                    -- HIER ZÜNDET IHR NEUER SOUND-BEFEHL!
                    sound(kanal, letzteNote, dauer, lautstaerke)
                    
                    equalizerBalken[i] = 15 -- Equalizer-Ausschlag triggern
                    aktualisieren = true
                end
            end
        end
    end

    -- UI bei Einstellungsänderung neu rendern
    if aktualisieren then
        zeichneUI()
    end

    -- --- LIVE VISUALISIERUNG (EQUALIZER) ---
    -- Da inkey() nicht blockiert, können wir hier flüssig Animationsbalken zeichnen!
    for i = 1, 8 do
        if equalizerBalken[i] > 0 then
            -- Alten Balken weglöschen
            vga.text(2 + (i-1)*6 + 2, 14, "_", 0, 0)
            equalizerBalken[i] = equalizerBalken[i] - 1
            
            -- Neuen, kleiner werdenden Balken zeichnen
            if equalizerBalken[i] > 0 then
                vga.text(2 + (i-1)*6 + 2, 14, "^", COL_NOTE, 0)
            end
        end
    end

    delay(20) -- Kurze Entlastung für die CPU, sorgt für ca. 50 FPS Animation
end

-- Vor dem Verlassen aufräumen
vga.cls()
vga.cursor(true) -- Cursor für die Shell wieder einschalten
print("Soundtest beendet. Zurueck zur Konsole.")
