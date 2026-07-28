-- ===================================================
-- INTERAKTIVER JULIA-ZOOMER (320x240) FUER ESP32
-- ===================================================

-- Initialisierung der Zoom- und Positions-Variablen
local centerX = -0.7
local centerY = 0.27015
local zoom    = 1.0

local screenWidth  = 320 
local screenHeight = 240 
local maxIterations = 128 -- Niedriger fuer fluessiges Rendern

-- Feste Parameter fuer die Julia-Insel
local c_re = -0.7
local c_im = 0.27015

-- Hilfsfunktion zum Berechnen und Zeichnen des aktuellen Ausschnitts
local function renderFractal()
    vga.cls()
    vga.pos(0, 0)

    -- Berechne die aktuellen Grenzen basierend auf Center und Zoom
    local widthX = 3.0 / zoom
    local heightY = 2.0 / zoom
    
    local minX = centerX - (widthX / 2)
    local maxX = centerX + (widthX / 2)
    local minY = centerY - (heightY / 2)
    local maxY = centerY + (heightY / 2)

    local factorX = (maxX - minX) / screenWidth
    local factorY = (maxY - minY) / screenHeight


    for y = 0, screenHeight - 1 do
        local start_im = maxY - (y * factorY)
        
        for x = 0, screenWidth - 1 do
            local z_re = minX + (x * factorX)
            local z_im = start_im
            
            local z_re2 = z_re * z_re
            local z_im2 = z_im * z_im
            
            local iteration = 0
            
            while (z_re2 + z_im2 <= 4.0) and (iteration < maxIterations) do
                z_im = (2.0 * z_re * z_im) + c_im
                z_re = z_re2 - z_im2 + c_re
                
                z_re2 = z_re * z_re
                z_im2 = z_im * z_im
                
                iteration = iteration + 1
            end
            
            if iteration < maxIterations then
                local colorIdx = (iteration * 4) % 64
                if colorIdx == 0 then colorIdx = 1 end
                vga.pset(x, y, colorIdx)
            else
                vga.pset(x, y, 0)
            end
        end
        -- Atempause für USB-Host nach jeder Zeile
        delay(1)
    end
end

-- Ersten Frame zeichnen
renderFractal()

-- Hauptschleife für die interaktive Steuerung
local running = true
while running do
    -- Da wir in Lua keine direkte blockierende Tastaturbrücke haben, 
    -- fragen wir hier ab, ob inchar() oder wait_key() ein Event liefert.
    -- Wenn du wait_key(1) als Brücke hast, nutzen wir diese:
    local taste = inkey() 
    
    if taste > 0 then
        -- Schrittweite für Bewegung und Zoom an den aktuellen Zoom anpassen
        local moveStep = 0.5 / zoom
        
        if taste == 27 then      -- ESC -> Beenden
            running = false
            
        elseif taste == 218 then  -- PFEIL HOCH -> Nach oben verschieben
            centerY = centerY + moveStep
            renderFractal()
            
        elseif taste == 217 then  -- PFEIL RUNTER -> Nach unten verschieben
            centerY = centerY - moveStep
            renderFractal()
            
        elseif taste == 216 then  -- PFEIL LINKS -> Nach links verschieben
            centerX = centerX - moveStep
            renderFractal()
            
        elseif taste == 215 then  -- PFEIL RECHTS -> Nach rechts verschieben
            centerX = centerX + moveStep
            renderFractal()
            
        elseif taste == 43 then   -- '+' Taste (ASCII 43) -> In den Zustand reinzoomen
            zoom = zoom * 2.5
            renderFractal()
            
        elseif taste == 45 then   -- '-' Taste (ASCII 45) -> Rauszoomen
            if zoom > 1.0 then
                zoom = zoom / 2.5
                renderFractal()
            end
        end
        
        -- USB-Entprellung
        delay(100)
    end
    delay(10)
end

vga.cls()
print("Zurueck zur Konsole.")