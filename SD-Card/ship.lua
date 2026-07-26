-- ===================================================
-- LUA BURNING-SHIP-FRAKTAL FÜR TEENSY 4.1 VGA (640x480)
-- ===================================================

vga.cls()
vga.pos(0, 0)

local screenWidth  = 320 --640
local screenHeight = 240 --480

-- Sichtfenster exakt auf das Schiff ausrichten (Werte sind sehr empfindlich!)
local minX = -1.8
local maxX = -1.65
local minY = -0.05
local maxY =  0.1

local maxIterations = 64

local factorX = (maxX - minX) / screenWidth
local factorY = (maxY - minY) / screenHeight

for y = 0, screenHeight - 1 do
    -- Wichtig: Beim Burning Ship ist die Y-Achse invertiert
    local c_im = minY + (y * factorY)
    
    for x = 0, screenWidth - 1 do
        local c_re = minX + (x * factorX)
        
        local z_re = 0.0
        local z_im = 0.0
        local z_re2 = 0.0
        local z_im2 = 0.0
        
        local iteration = 0
        
        -- FORMEL: Z = (|Re(Z)| + i|Im(Z)|)^2 + C
        while (z_re2 + z_im2 <= 4.0) and (iteration < maxIterations) do
            -- Hier nutzen wir math.abs für die Absolutwerte vor dem Quadrieren
            z_im = math.abs(2.0 * z_re * z_im) + c_im
            z_re = z_re2 - z_im2 + c_re
            
            z_re2 = z_re * z_re
            z_im2 = z_im * z_im
            
            iteration = iteration + 1
        end
        
        if iteration < maxIterations then
            -- Feuriges Farb-Mapping (Nutze z.B. deine Rot/Gelb/Orange Töne aus der Palette)
            local colorIdx = (iteration * 4) % 2565
            if colorIdx == 0 then colorIdx = 1 end
            vga.pset(x, y, colorIdx)
        else
            vga.pset(x, y, 0) -- Hintergrund schwarz
        end
    end
    
    delay(1) -- Atempause für USB-Host
end

vga.pos(0, 1)
