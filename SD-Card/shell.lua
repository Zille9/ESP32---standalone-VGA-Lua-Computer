-- ============================================================================
-- INTEGRIERTES ANALOGES PIXEL-UHR-WIDGET (Direkt in der Hauptdatei)
-- ============================================================================

-- --- WIDGET KONFIGURATION (Pixel-Koordinaten) ---
local UHR_MITTE_X = 570  -- Nahe am rechten Rand bei 640er Auflösung
local UHR_MITTE_Y = 55   -- Im oberen Bereich des Terminals
local UHR_RADIUS  = 42   -- Passt perfekt in die obere rechte Ecke

local RAD_STUNDE  = 20
local RAD_MINUTE  = 32
local RAD_SEKUNDE = 35

local COL_RAHMEN      = 127 -- Cyan / Hellblau
local COL_STUNDE      = 255 -- Weiß
local COL_MINUTE      = 240 -- Orange
local COL_SEKUNDE     = 196 -- Rot
local COL_HINTERGRUND = 1   -- Terminal-Hintergrund

-- Verlaufssicherung für das flackerfreie Löschen
local altStdX, altStdY = UHR_MITTE_X, UHR_MITTE_Y
local altMinX, altMinY = UHR_MITTE_X, UHR_MITTE_Y
local altSekX, altSekY = UHR_MITTE_X, UHR_MITTE_Y

-- Funktion 1: Zeichnet das statische Zifferblatt einmalig
local function initUhrWidget()
    vga.ellipse(UHR_MITTE_X, UHR_MITTE_Y, UHR_RADIUS, UHR_RADIUS, COL_RAHMEN)
    
    -- 4 Haupt-Stunden-Punkte auf den Kreis setzen (12, 3, 6, 9 Uhr)
    for i = 0, 3 do
        local winkel = i * (math.pi / 2)
        local px = math.floor(UHR_MITTE_X + ((UHR_RADIUS - 3) * math.sin(winkel)) + 0.5)
        local py = math.floor(UHR_MITTE_Y - ((UHR_RADIUS - 3) * math.cos(winkel)) + 0.5)
        vga.fillellipse(px, py, 2, 2, COL_RAHMEN, COL_HINTERGRUND)
    end
end

-- Funktion 2: Aktualisiert die Zeiger flackerfrei im Sekunden-Takt
local function updateUhrWidget()
    -- Holt die echten Werte mit Ihrer automatischen Sommer-/Winterzeit aus C++
    local h, m, s = sys.gettime()
    
    -- Winkelberechnungen (Radiant)
    local winkelSek = s * (2 * math.pi / 60)
    local winkelMin = m * (2 * math.pi / 60)
    local winkelStd = (h % 12 + m / 60) * (2 * math.pi / 12)

    -- Neue Pixel-Endkoordinaten berechnen
    local neuSekX = math.floor(UHR_MITTE_X + (RAD_SEKUNDE * math.sin(winkelSek)) + 0.5)
    local neuSekY = math.floor(UHR_MITTE_Y - (RAD_SEKUNDE * math.cos(winkelSek)) + 0.5)

    local neuMinX = math.floor(UHR_MITTE_X + (RAD_MINUTE * math.sin(winkelMin)) + 0.5)
    local neuMinY = math.floor(UHR_MITTE_Y - (RAD_MINUTE * math.cos(winkelMin)) + 0.5)

    local neuStdX = math.floor(UHR_MITTE_X + (RAD_STUNDE * math.sin(winkelStd)) + 0.5)
    local neuStdY = math.floor(UHR_MITTE_Y - (RAD_STUNDE * math.cos(winkelStd)) + 0.5)

    -- A) ALTE Zeiger-Linien exakt weglöschen (Schwarz = 0)
    vga.line(UHR_MITTE_X, UHR_MITTE_Y, altSekX, altSekY, COL_HINTERGRUND)
    vga.line(UHR_MITTE_X, UHR_MITTE_Y, altMinX, altMinY, COL_HINTERGRUND)
    vga.line(UHR_MITTE_X, UHR_MITTE_Y, altStdX, altStdY, COL_HINTERGRUND)

    -- B) NEUE Zeiger scharf zeichnen
    vga.line(UHR_MITTE_X, UHR_MITTE_Y, neuStdX, neuStdY, COL_STUNDE)
    vga.line(UHR_MITTE_X, UHR_MITTE_Y, neuMinX, neuMinY, COL_MINUTE)
    vga.line(UHR_MITTE_X, UHR_MITTE_Y, neuSekX, neuSekY, COL_SEKUNDE)

    -- C) Uhren-Nabe im Zentrum auffrischen
    vga.fillellipse(UHR_MITTE_X, UHR_MITTE_Y, 3, 3, COL_RAHMEN, COL_HINTERGRUND)

    -- D) Koordinaten für den nächsten Takt sichern
    altSekX, altSekY = neuSekX, neuSekY
    altMinX, altMinY = neuMinX, neuMinY
    altStdX, altStdY = neuStdX, neuStdY
end

-- ============================================================================
-- INITIALISIERUNG BEIM START DES TERMINALS
-- ============================================================================
initUhrWidget()

local letztesUhrUpdate = 0

-- ============================================================================
-- IHRE BESTEHENDE TERMINAL-HAUPTSCHLEIFE
-- ============================================================================
while true do
    -- [Hier bleibt Ihre normale Tastatur-Abfrage und Terminal-Befehlslogik]
    local taste = inkey()
    if taste > -1  then
       write(string.char(taste)) 
    end
    if taste == 27 then
       break
    end

    -- AUTOMATISCHES UHR-UPDATE IM HINTERGRUND (Exakt alle 1000ms)
    local jetzt = sys.timer()
    if (jetzt - letztesUhrUpdate) >= 1000 then
        letztesUhrUpdate = jetzt
        updateUhrWidget() -- Berechnet und dreht die Zeiger absolut flackerfrei
    end

    delay(10) -- System entlasten
end