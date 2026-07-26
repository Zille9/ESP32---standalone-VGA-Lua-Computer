-- ===================================================
-- LUA JULIA-MENGE FUER ESP32 VGA (320x240)
-- ===================================================
local dauer = sys.timer()
-- Farben sichern ----------------
local fcolor, bcolor = vga.gcolor()

-- Bildschirm leeren (bColor)
vga.cls()

vga.pos(0, 0)

-- Auflösung der VGA-Karte auf 640x480 festlegen
local screenWidth  = 320 
local screenHeight = 240 

-- Sichtfenster für den Bildausschnitt koordinieren
local minX = -1.5
local maxX =  1.5
local minY = -1.0
local maxY =  1.0

-- Maximale Rechentiefe für feine Strukturen
local maxIterations = 128

-- Vorberechnete Faktoren für maximale Pixel-Geschwindigkeit
local factorX = (maxX - minX) / screenWidth
local factorY = (maxY - minY) / screenHeight

-- DER JULIA-PARAMETER (C): 
-- Ändern Sie diese beiden Werte im Editor, um völlig neue Formen zu generieren!
-- Klassische schöne Werte: 
-- c_re = -0.7,  c_im = 0.27015
-- c_re = -0.4,  c_im = 0.6
-- c_re = -0.8,  c_im = 0.156
local c_re = -0.7
local c_im = 0.27015

-- Hauptschleife über alle 480 Zeilen
for y = 0, screenHeight - 1 do
    -- Imaginärteil (Startwert Z_im) für diese Zeile
    local start_im = maxY - (y * factorY)
    
    -- Schleife über alle 640 Spalten
    for x = 0, screenWidth - 1 do
        -- Realteil (Startwert Z_re) für dieses Pixel
        local z_re = minX + (x * factorX)
        local z_im = start_im
        
        local z_re2 = z_re * z_re
        local z_im2 = z_im * z_im
        
        local iteration = 0
        
        -- Die Julia-Gleichung: Z_neu = Z_alt^2 + C
        while (z_re2 + z_im2 <= 4.0) and (iteration < maxIterations) do
            z_im = (2.0 * z_re * z_im) + c_im
            z_re = z_re2 - z_im2 + c_re
            
            z_re2 = z_re * z_re
            z_im2 = z_im * z_im
            
            iteration = iteration + 1
        end
        
        -- Pixel einfärben
        if iteration < maxIterations then
            -- Fließendes Farb-Mapping für Ihre 256 Farben
            local colorIdx = (iteration * 4) % 256
            
            -- Hintergrundfarbe (0) für das Fraktal ausschließen
            if colorIdx == 0 then colorIdx = 1 end
            
            vga.pset(x, y, colorIdx)
        else
            -- Der "See" im Inneren der Julia-Insel bleibt tiefschwarz
            vga.pset(x, y, 0)
        end
    end
    
    -- WICHTIG: Jede Zeile dem Teensy-Kern kurz Zeit geben,
    -- die Hintergrundaufgaben (USB-Tastatur, PC-Schnittstelle) zu verarbeiten!
    vga.waitsync() --delay(1)
end

--- Farben wieder herstellen ---
vga.color(fcolor,bcolor)
--- Home-Position --------------
collectgarbage("collect")
vga.pos(0,1)
print((sys.timer()-dauer)/1000 .. " sek.")
