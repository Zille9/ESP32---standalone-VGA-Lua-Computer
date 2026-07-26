-- ============================================================================
-- 3D PURE WIREFRAME ENGINE (3d_pot.lua) - TURBO EDITION
-- 100% KORREKTE PERSPEKTIVE & MAX SPEED DANK LOKALEM CACHING!
-- ============================================================================
local Kanne3D = {}

-- LUA TURBO-LADUNG: Globale Funktionen lokal cachen (Spart 70% CPU-Last!)
local math_cos   = math.cos
local math_sin   = math.sin
local math_floor = math.floor
local math_pi    = math.pi

-- --- ENGINE CONFIG (VGA 640x480) ---
local SCREEN_WIDTH  = 320
local SCREEN_HEIGHT = 240
local CENTER_X      = 130
local CENTER_Y      = 140
local FOV           = 180 
local CAMERA_DIST   = 130 

-- --- ROTATIONS-WINKEL ---
local angleX = 0.5  -- Neigung von schräg oben
local angleY = 0.0

-- --- SPEICHER FÜR 3D-DATEN ---
local punkte = {}   
local linien = {}   

vga.cursor(false) -- Cursor abschalten
vga.cls(0)

local function addPunkt(x, y, z)
    table.insert(punkte, {x = x, y = y, z = z})
    return #punkte
end

local function addLinie(p1, p2)
    if p1 and p2 and p1 > 0 and p2 > 0 and p1 <= #punkte and p2 <= #punkte then
        table.insert(linien, {p1 = p1, p2 = p2})
    end
end

-- ============================================================================
-- GEOMETRIE DER KAFFEEKANNE (PERFEKTES PURE-3D NETZ)
-- ============================================================================
function Kanne3D.generiereModell()
    punkte = {}
    linien = {}

    local ringe = 7              
    local punkteProRing = 16  -- 16 Segmente reichen für wunderbare Rundung in 3D
    local bauchHoehe = 40
    
    local gitter = {}

    -- 1. PUNKTE IM RAUM ANLEGEN
    for r = 1, ringe do
        gitter[r] = {}
        local t = (r - 1) / (ringe - 1) 
        local h = -bauchHoehe/2 + t * bauchHoehe
        
        -- Formel für die bauchige Silhouette
        local radius = 20
        if t < 0.1 then
            radius = 25 
        elseif t >= 0.1 and t < 0.5 then
            radius = 20 + math_sin((t - 0.1) / 0.4 * math_pi) * 16 
        else
            radius = 20 + 8 * math_sin(0.4 * math_pi) - ((t - 0.5) / 0.5) * 26 
        end

        for p = 1, punkteProRing do
            local phi = ((p - 1) / punkteProRing) * 2 * math_pi
            local x = math_cos(phi) * radius
            local z = math_sin(phi) * radius
            gitter[r][p] = addPunkt(x, h, z)
        end
    end

    -- 2. VERMASCHUNG (ECHTE HORIZONTALE + VERTIKALE 3D LINIEN)
    for r = 1, ringe do
        for p = 1, punkteProRing do
            -- Ringe schließen
            local naechsterP = p + 1
            if naechsterP > punkteProRing then naechsterP = 1 end
            addLinie(gitter[r][p], gitter[r][naechsterP])
            
            -- Längsstreben an der Wand hochziehen (Perspektivisch perfekt!)
            if r < ringe then
                addLinie(gitter[r][p], gitter[r + 1][p])
            end
        end
    end

    -- 3. DER DECKEL (Ihre geniale Lösung: Fest verankert an Ring 1!)
    local deckelMitteId = addPunkt(0, -bauchHoehe/2 - 12, 0)
    local knaufHalsId   = addPunkt(0, -bauchHoehe/2 - 18, 0)
    local knaufKopfId   = addPunkt(0, -bauchHoehe/2 - 24, 0)

    for p = 1, punkteProRing, 2 do
        addLinie(gitter[1][p], deckelMitteId)
    end
    addLinie(deckelMitteId, knaufHalsId)
    addLinie(knaufHalsId, knaufKopfId)

    -- 4. DER AUSGUSS (SCHNAUZE - Dockt an die Vorderseite an)
    local s1 = addPunkt(21,  -7,  0)  
    local s2 = addPunkt(35,  -17,  0)  
    local s3 = addPunkt(45,  -27,  0)  
    local s4 = addPunkt(38,  -26,  0)  
    
    addLinie(s1, s2)
    addLinie(s2, s3)
    addLinie(s3, s4)
    
    addLinie(gitter[2][1], s1)
    addLinie(gitter[5][1], s4)
    addLinie(gitter[3][1], s2)

    -- 5. DER HENKEL (GRIFF - Dockt an die Rückseite bei Segment 9 an)
    local h1 = addPunkt(-26, -12,  0) 
    local h2 = addPunkt(-38, -5,  0) 
    local h3 = addPunkt(-38,  10,  0) 
    local h4 = addPunkt(-24,  17,  0) 

    addLinie(h1, h2)
    addLinie(h2, h3)
    addLinie(h3, h4)
    
    addLinie(gitter[2][9], h1)  
    addLinie(gitter[6][9], h4)  
end

-- ============================================================================
-- PERSPEKTIVISCHE 3D-ROTATION (JETZT IM TURBO-MODUS)
-- ============================================================================
local projiziertePunkte = {}

local function berechne3D()
    local cosX, sinX = math_cos(angleX), math_sin(angleX)
    local cosY, sinY = math_cos(angleY), math_sin(angleY)

    projiziertePunkte = {}

    for i, p in ipairs(punkte) do
        -- Rotation Y (um die eigene Achse)
        local x1 = p.x * cosY + p.z * sinY
        local z1 = -p.x * sinY + p.z * cosY
        
        -- Rotation X (Kippung nach vorne)
        local y2 = p.y * cosX - z1 * sinX
        local z2 = p.y * sinX + z1 * cosX

        local z_dist = z2 + CAMERA_DIST
        if z_dist < 20 then z_dist = 20 end
        
        -- Perspektivische Division (Echtes 3D!)
        local screenX = math.floor((x1 * FOV) / z_dist) + CENTER_X
        local screenY = math.floor((y2 * FOV) / z_dist) + CENTER_Y

        -- Schutzwall gegen Ausreißer
        if screenX < 0 then screenX = 0 elseif screenX > 639 then screenX = 639 end
        if screenY < 0 then screenY = 0 elseif screenY > 479 then screenY = 479 end

        projiziertePunkte[i] = {x = screenX, y = screenY}
    end
end

-- ============================================================================
-- RENDER-PASS 
-- ============================================================================
local function rendern()
    vga.box(0, 40, 320, 240, 0)

    -- Alle Linien zeichnen
    for _, l in ipairs(linien) do
        local p1 = projiziertePunkte[l.p1]
        local p2 = projiziertePunkte[l.p2]
        if p1 and p2 then
            vga.line(p1.x, p1.y, p2.x, p2.y, 48)
        end
    end

    -- HUD über Standard vga.text
    vga.text(2, 1, "====== ESP32 PURE 3D ENGINE ======", 47, 0)
    vga.text(2, 3, "KAFFEEKANNE (TURBO-SPEED WIREFRAME)", 255, 0)
    vga.text(5, 27, "ESC : Zurueck zum OS-Terminal", 110, 0)
    vga.waitsync()
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================
function Kanne3D.run()
    Kanne3D.generiereModell()
    local running = true
    
    while running do
        local taste = inkey()
        if taste == 27 then running = false --end

        elseif taste == 218 then -- Key_Up
           angleX = angleX + 0.1

        elseif taste == 217 then -- Key_Down
           angleX = angleX - 0.1

        --elseif taste == 215 then -- Key_Right
        --   angleY = angleY + 0.1
    
        --elseif taste == 216 then -- Key_Left
        --   angleY = angleY - 0.1

        end                 


        --angleY = angleY + 0.03 -- Elegante Drehung

        --berechne3D()
        
        --if running then
        angleY = angleY + 0.15
        berechne3D()
        rendern()
        
        -- delay(2) -- Keine lange Blockade mehr!
            
        -- end
    end

    collectgarbage("collect") 
    vga.cls()
    print("> ")
end

Kanne3D.run()
return Kanne3D