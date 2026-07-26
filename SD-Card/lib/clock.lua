-- ============================================================================
-- ANALOGES PIXEL-UHR-WIDGET FOR TERMINAL (Oben rechts)
-- NATIVE NUTZUNG VON vga.line, vga.ellipse UND vga.filledellipse
-- ============================================================================
local ClockWidget = {}

-- --- CONFIGURATION (Echte Bildschirm-Pixel) ---
local MITTE_X = 570  -- Pixel-X (Nahe am rechten Rand bei 640er Auflösung)
local MITTE_Y = 55   -- Pixel-Y (Im oberen Bereich des Terminals)
local RADIUS  = 42   -- Kompakter Radius, damit es perfekt in die Ecke passt

-- Zeiger-Längen in Pixeln
local RAD_STUNDE  = 20
local RAD_MINUTE  = 32
local RAD_SEKUNDE = 35

-- Farben (VGA Farb-Indizes)
local COL_RAHMEN      = 127 -- Cyan / Hellblau
local COL_STUNDE      = 255 -- Weiß
local COL_MINUTE      = 240 -- Orange
local COL_SEKUNDE     = 196 -- Rot
local COL_HINTERGRUND = 0   -- Schwarz (An Ihren Terminal-Hintergrund anpassen)

-- Verlaufssicherung zum flackerfreien Pixel-Löschen
local altStdX, altStdY = MITTE_X, MITTE_Y
local altMinX, altMinY = MITTE_X, MITTE_Y
local altSekX, altSekY = MITTE_X, MITTE_Y

-- Initialisiert das Zifferblatt einmalig auf Pixelebene
function ClockWidget.init()
    -- Runden Uhrenrahmen zeichnen
    vga.ellipse(MITTE_X, MITTE_Y, RADIUS, RADIUS, COL_RAHMEN)
    
    -- 4 Haupt-Stunden-Punkte auf den Kreis setzen (12, 3, 6, 9 Uhr)
    for i = 0, 3 do
        local winkel = i * (math.pi / 2)
        local px = math.floor(MITTE_X + ((RADIUS - 3) * math.sin(winkel)) + 0.5)
        local py = math.floor(MITTE_Y - ((RADIUS - 3) * math.cos(winkel)) + 0.5)
        vga.fillellipse(px, py, 2, 2, COL_RAHMEN, COL_HINTERGRUND)
    end
end

-- Wird jede Sekunde aus Ihrer Haupt-Terminalschleife aufgerufen
function ClockWidget.update()
    -- Holt die echten Werte mit automatischer Sommer-/Winterzeit aus C++
    local h, m, s = sys.gettime()
    
    -- Winkelberechnungen (Radiant)
    local winkelSek = s * (2 * math.pi / 60)
    local winkelMin = m * (2 * math.pi / 60)
    local winkelStd = (h % 12 + m / 60) * (2 * math.pi / 12)

    -- Neue Pixel-Endkoordinaten berechnen
    local neuSekX = math.floor(MITTE_X + (RAD_SEKUNDE * math.sin(winkelSek)) + 0.5)
    local neuSekY = math.floor(MITTE_Y - (RAD_SEKUNDE * math.cos(winkelSek)) + 0.5)

    local neuMinX = math.floor(MITTE_X + (RAD_MINUTE * math.sin(winkelMin)) + 0.5)
    local neuMinY = math.floor(MITTE_Y - (RAD_MINUTE * math.cos(winkelMin)) + 0.5)

    local neuStdX = math.floor(MITTE_X + (RAD_STUNDE * math.sin(winkelStd)) + 0.5)
    local neuStdY = math.floor(MITTE_Y - (RAD_STUNDE * math.cos(winkelStd)) + 0.5)

    -- A) ALTE Zeiger-Linien exakt weglöschen (Schwarz = 0)
    vga.line(MITTE_X, MITTE_Y, altSekX, altSekY, COL_HINTERGRUND)
    vga.line(MITTE_X, MITTE_Y, altMinX, altMinY, COL_HINTERGRUND)
    vga.line(MITTE_X, MITTE_Y, altStdX, altStdY, COL_HINTERGRUND)

    -- B) NEUE Zeiger scharf zeichnen
    vga.line(MITTE_X, MITTE_Y, neuStdX, neuStdY, COL_STUNDE)
    vga.line(MITTE_X, MITTE_Y, neuMinX, neuMinY, COL_MINUTE)
    vga.line(MITTE_X, MITTE_Y, neuSekX, neuSekY, COL_SEKUNDE)

    -- C) Uhren-Nabe im Zentrum auffrischen
    vga.fillellipse(MITTE_X, MITTE_Y, 3, 3, COL_RAHMEN, COL_HINTERGRUND)

    -- D) Koordinaten für den nächsten Takt sichern
    altSekX, altSekY = neuSekX, neuSekY
    altMinX, altMinY = neuMinX, neuMinY
    altStdX, altStdY = neuStdX, neuStdY
end

return ClockWidget