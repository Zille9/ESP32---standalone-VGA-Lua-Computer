-- ============================================================================
-- HIGH-RESOLUTION PIXEL-UHR (Fuer 640x480 VGA)
-- NATIVE NUTZUNG VON vga.line, vga.ellipse UND vga.filledellipse
-- ============================================================================

-- --- CONFIGURATION (In echten Bildschirm-Pixeln) ---
local MITTE_X = 160  -- Genau die Mitte des 640er Bildschirms
local MITTE_Y = 120  -- Genau die Mitte des 480er Bildschirms
local RADIUS  = 150  -- Radius des Zifferblatts
local fc,bc = vga.gcolor()

-- Zeiger-Laengen in Pixeln
local RAD_STUNDE  = 80
local RAD_MINUTE  = 120
local RAD_SEKUNDE = 140

-- Farben (VGA Farb-Indizes)
local COL_RAHMEN      = 127 -- Cyan / Hellblau
local COL_STUNDE      = 255 -- Weiß
local COL_MINUTE      = 240 -- Orange
local COL_SEKUNDE     = 196 -- Rot
local COL_HINTERGRUND = bc  -- aktuelle Hintergrundfarbe

-- Variablen fuer die Zeiger-Verlaufssicherung (Zum flackerfreien Pixel-Löschen)
local altStdX, altStdY = MITTE_X, MITTE_Y
local altMinX, altMinY = MITTE_X, MITTE_Y
local altSekX, altSekY = MITTE_X, MITTE_Y

local laufzeitAktiv = true
local letztesUpdate = 0

-- ============================================================================
-- UHR-GEOMETRIE INITIALISIEREN
-- ============================================================================
vga.cursor(false)
vga.cls()

-- 1. Grossen runden Uhrenrahmen zeichnen (Nutzt vga.ellipse)
-- Die Ellipse wird mit Breite und Hoehe als Radius aufgespannt
vga.ellipse(MITTE_X, MITTE_Y, RADIUS, RADIUS, COL_RAHMEN)
vga.ellipse(MITTE_X, MITTE_Y, RADIUS + 4, RADIUS + 4, COL_RAHMEN) -- Doppelter Rand

-- 2. Stunden-Striche/Marker auf den Kreis zeichnen (1 bis 12)
for std = 1, 12 do
    local winkel = std * (2 * math.pi / 12)
    -- Startpunkt des Strichs (am aeusseren Rand)
    local xStart = math.floor(MITTE_X + (((RADIUS - 10) * math.sin(winkel)))/2)-- + 0.5)/2)
    local yStart = math.floor(MITTE_Y - (((RADIUS - 10) * math.cos(winkel)))/2)-- + 0.5)
    -- Endpunkt des Strichs
    local xEnd = math.floor(MITTE_X + (((RADIUS * math.sin(winkel)) + 0.5))/2)
    local yEnd = math.floor(MITTE_Y - (((RADIUS * math.cos(winkel)) + 0.5))/2)
    
    -- Strich zeichnen (Nutzt vga.line)
    vga.line(xStart , yStart, xEnd, yEnd, COL_RAHMEN)
end

-- ============================================================================
-- HAUPTSCHLEIFE
-- ============================================================================
while laufzeitAktiv do

    -- 1. ECHTZEIT-TASTENABFRAGE (ESC zum Beenden)
    local taste = inkey()
    if taste == 27 then
        laufzeitAktiv = false
    end

    -- 2. DYNAMISCHES UPDATE (Jede Sekunde / 1000ms)
    local jetzt = sys.timer()
    if (jetzt - letztesUpdate) >= 1000 and laufzeitAktiv then
        letztesUpdate = jetzt
        
        -- HINWEIS: Hier die RTC-Echtzeit einspeisen, falls vorhanden!
        local h ,m ,s = sys.gettime()
        
        -- ====================================================================
        -- PIXEL-WINKELBERECHNUNGEN (Radiant)
        -- ====================================================================
        local winkelSek = s * (2 * math.pi / 60)
        local winkelMin = m * (2 * math.pi / 60)
        -- Stundenzeiger wandert flüssig mit den Minuten mit
        local winkelStd = (h % 12 + m / 60) * (2 * math.pi / 12)

        -- Neue Pixel-Endkoordinaten der Zeiger berechnen
        local neuSekX = math.floor(MITTE_X + ((RAD_SEKUNDE * math.sin(winkelSek)) + 0.5)/2)
        local neuSekY = math.floor(MITTE_Y - ((RAD_SEKUNDE * math.cos(winkelSek)) + 0.5)/2)

        local neuMinX = math.floor(MITTE_X + ((RAD_MINUTE * math.sin(winkelMin)) + 0.5)/2)
        local neuMinY = math.floor(MITTE_Y - ((RAD_MINUTE * math.cos(winkelMin)) + 0.5)/2)

        local neuStdX = math.floor(MITTE_X + ((RAD_STUNDE * math.sin(winkelStd)) + 0.5)/2)
        local neuStdY = math.floor(MITTE_Y - ((RAD_STUNDE * math.cos(winkelStd)) + 0.5)/2)

        -- ====================================================================
        -- FLACKERFREIES LÖSCHEN UND ZEICHNEN (In Mikrosekunden)
        -- ====================================================================
        
        -- A) ALTE Zeiger-Linien exakt loeschen (Mit Hintergrundfarbe Schwarz = 0 überschreiben)
        vga.line(MITTE_X, MITTE_Y, altSekX, altSekY, COL_HINTERGRUND)
        vga.line(MITTE_X, MITTE_Y, altMinX, altMinY, COL_HINTERGRUND)
        vga.line(MITTE_X, MITTE_Y, altStdX, altStdY, COL_HINTERGRUND)

        -- B) NEUE Zeiger mit den echten Farben scharf auf den Schirm zeichnen
        vga.line(MITTE_X, MITTE_Y, neuStdX, neuStdY, COL_STUNDE)   -- Stundenzeiger
        vga.line(MITTE_X, MITTE_Y, neuMinX, neuMinY, COL_MINUTE)   -- Minutenzeiger
        vga.line(MITTE_X, MITTE_Y, neuSekX, neuSekY, COL_SEKUNDE)  -- Sekundenzeiger

        -- C) Den Mittelpunkt saeubern/verzieren (Nutzt vga.fillellipse fuer eine schicke Rad-Nabe)
        vga.fillellipse(MITTE_X, MITTE_Y, 6, 6, COL_RAHMEN, COL_HINTERGRUND)

        -- D) Die aktuellen Pixelkoordinaten fuer das Loeschen im naechsten Takt merken
        altSekX, altSekY = neuSekX, neuSekY
        altMinX, altMinY = neuMinX, neuMinY
        altStdX, altStdY = neuStdX, neuStdY
        
        -- Optionale digitale Textanzeige via Textraster ganz unten im Eck
        local zeitText = string.format("ZEIT: %02d:%02d:%02d", h, m, s)
        vga.text(32, 54, zeitText, COL_STUNDE, COL_HINTERGRUND,true)
    end

    delay(20) -- CPU-Schonung
end

-- Nach dem Beenden des Skripts Bildschirm loeschen
vga.cls()
vga.cursor(true)
