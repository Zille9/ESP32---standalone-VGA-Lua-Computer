-- ===================================================
-- LUA RETRO-SAMMELSPIEL (640x480)
-- ===================================================

local fcolor, bcolor = vga.gcolor()

vga.cls(bcolor)

-- 1. SPIELER-EINSTELLUNGEN
local playerX = 320
local playerY = 120
local playerSize = 16
local playerColor = 127 -- Cyan
local speed = 10        -- Bewegungsgeschwindigkeit

-- 2. SPIELFELD & CORE-VARIABLEN
local minX = 10
local maxX = 625 - playerSize
local minY = 20
local maxY = 465 - playerSize
local score = 0

-- Spielfeld-Rahmen (Gelb = 14) einmalig zeichnen
vga.rect(minX - 2, minY - 2, maxX + playerSize + 2, maxY + playerSize + 2, 252)

-- 3. FUTTER-EINSTELLUNGEN
local foodSize = 8
local foodColor = 163 -- Hellgrün
local foodX = 0
local foodY = 0

-- Funktion, um das Futter an einer zufälligen Position neu zu platzieren
local function spawnFood()
    -- math.random liefert Werte im sicheren Spielfeldbereich
    foodX = math.random(minX + 10, maxX - 10)
    foodY = math.random(minY + 10, maxY - 10)
    -- Das neue Futter als gefüllte Ellipse (Kreis) zeichnen
    vga.fillellipse(foodX, foodY, foodSize, foodSize, foodColor, bcolor)
end

-- Erstes Futter platzieren
spawnFood()

-- Hilfsfunktion für das Score-Update oben links
local function drawScore()
    vga.pos(2, 0)
    vga.text("SCORE: " .. score .. "  |  Pfeiltasten: Bewegen | ESC: Exit",255,bcolor,true)
end

drawScore()

-- HAUPT-SPIELSCHLEIFE
local running = true
while running do
    local taste = inkey()
    
    local oldX = playerX
    local oldY = playerY
    local moved = false

    -- Tastaturabfrage
    if taste > 0 then
     if taste == 27 then running = false
     elseif taste==218 and playerY>minY then playerY=playerY-speed;moved = true
     elseif taste==217 and playerY<maxY then playerY=playerY+speed;moved = true
     elseif taste==216 and playerX>minX then playerX=playerX-speed;moved = true
     elseif taste==215 and playerX<maxX then playerX=playerX+speed;moved = true
     end
    end

    -- GRAFIK-UPDATE: Spieler bewegen
    if moved then
        -- Alte Position mit Schwarz (0) auslöschen
        vga.box(oldX, oldY, playerSize, playerSize, bcolor)
        -- Neue Position in Spielerfarbe zeichnen
        vga.box(playerX, playerY, playerSize, playerSize, playerColor)
    else
        vga.box(playerX, playerY, playerSize, playerSize, playerColor)
    end

    -- KOLLISIONSPRÜFUNG (Bounding Box / Hitbox)
    -- Wir prüfen, ob sich die Box des Spielers und der Kreis des Futters überschneiden
    if (playerX < foodX + foodSize) and (playerX + playerSize > foodX) and
       (playerY < foodY + foodSize) and (playerY + playerSize > foodY) then
        
        -- Futter wurde gefressen!
        score = score + 1
        drawScore() -- Punkteanzeige aktualisieren
        
        -- Altes Futter visuell löschen (mit schwarzem Kreis überschreiben)
        vga.fillellipse(foodX, foodY, foodSize, foodSize, bcolor, bcolor)
        
        -- Neues Futter generieren
        spawnFood()
    end

    -- TIMING (Ca. 60 FPS + Entlastung für die Teensy-Interrupts)
    delay(16)
end

vga.cls()
print("Spiel beendet. Dein Highscore: " .. score)
