-- ============================================================================
-- SPACE INVADERS ARCADE-MODUL (space_invaders.lua) - TEIL 1
-- HIGH-PERFORMANCE DATA ENGINE FÜR DAS RETRO-SPIEL
-- ============================================================================
local SpaceInvaders = {}

-- --- DESIGN-EINSTELLUNGEN (VGA 640x480) ---
local SLOT_SPIELER = 0   -- Sprite-Slot für das Spielerschiff
local SLOT_ALIEN   = 1   -- Sprite-Slot für die Außerirdischen
local SLOT_LASER   = 2   -- Sprite-Slot für das Laser-Projektil
local SLOT_ALIEN_LASER = 3   -- Sprite-Slot für den Alien-Schuss

-- --- SPIEL-ZUSTAND ---
local spielerX  = 300
local spielerY  = 420
local score     = 0
local leben     = 3
local alienRichtung = 1  -- 1 = Rechts, -1 = Links
local alienSpeed    = 1

-- Tabellen für dynamische Spielobjekte
local aliens     = {}
local projektile = {}
local alienProjektile = {}

-- Initialisiert das Spielfeld und lädt/generiert die Hardware-Sprites
function SpaceInvaders.init()
    sprite.cls(0)
    
    -- 1. GRAFIKEN BEREITSTELLEN
    -- Falls Sie fertige BMPs haben, nutzen Sie: sprite.load("ship.bmp", SLOT_SPIELER)
    -- Hier generieren wir die Sprites direkt über VGA-Primitives für den Sofortstart:
    
    -- A) Spielerschiff (Grün)
    vga.box(0, 0, 16, 16, 0)
    vga.box(2, 4, 12, 12, 24) -- Grüner Rumpf
    vga.box(7, 0, 2, 4, 24)  -- Kanone
    sprite.get(0, 0, SLOT_SPIELER)
    
    -- B) Alien-Krabbe (Magenta/Rot)
    vga.box(0, 0, 16, 16, 0)
    vga.box(2, 4, 12, 6, 196) -- Roter Körper
    vga.box(4, 2, 8, 2, 196)  -- Kopf
    vga.line(2, 10, 4, 14, 196)    -- Beine links
    vga.line(13, 10, 11, 14, 196)  -- Beine rechts
    sprite.get(0, 0, SLOT_ALIEN)
    
    -- C) Laser-Schuss (Gelb)
    vga.box(0, 0, 16, 16, 0)
    vga.box(7, 2, 2, 12, 240) -- Gelber Strich
    sprite.get(0, 0, SLOT_LASER)
    
    -- D) Laser-Schuss Alien (Leuchtend Rot/Orange - Index 196)
    vga.box(0, 0, 16, 16, 0)
    vga.box(6, 2, 4, 12, 196) -- Ein etwas dickerer, roter Bolzen
    sprite.get(0, 0, SLOT_ALIEN_LASER)
    sprite.cls(0)
    
    -- 2. ALIEN-ARMEE AUFBAUEN (5 Spalten x 3 Reihen = 15 Aliens)
    aliens = {}
    local idZaehler = 10
    for reihe = 0, 2 do
        for spalte = 0, 4 do
            table.insert(aliens, {
                x = 100 + (spalte * 40),
                y = 60 + (reihe * 30),
                active = true,
                hw_id =idZaehler
            })
            idZaehler = idZaehler + 1   
        end
    end
    
    -- Projektile leeren
    projektile = {}
    alienProjektile = {}
    leben = 3
    score = 0
    spielerX = 300
    alienRichtung = 1
end

-- Berechnet die Bewegung aller Objekte und prüft auf Treffer
function SpaceInvaders.updateLogik()
    -- 1. LASER-PROJEKTILE BEWEGEN
    for i = #projektile, 1, -1 do
        local p = projektile[i]
        p.y = p.y - 6 -- Schuss fliegt nach oben
        
        -- Wenn der Schuss den oberen Bildschirmrand verlässt, löschen
        if p.y < 20 then
            table.remove(projektile, i)
            sprite.hide(SLOT_LASER) --am oberen Bildschirmrand Projektil loeschen
        end
    end
    -- ====================================================================
    -- ALIEN-LASER BEWEGEN & AN DEN UNTEREN RAND PRÜFEN
    -- ====================================================================
    for i = #alienProjektile, 1, -1 do
        local ap = alienProjektile[i]
        ap.y = ap.y + 4 -- Alien-Schuss fliegt nach UNTEN (etwas langsamer als der Spieler)
        
        if ap.y > 460 then
            table.remove(alienProjektile, i)
        end
    end
    -- 2. ALIEN-ARMEE BEWEGEN (Gleichschritt im Raster)
    local randGetroffen = false
    
    -- Erst prüfen, ob ein aktives Alien den seitlichen Bildschirmrand berührt
    for _, a in ipairs(aliens) do
        if a.active then
            if (alienRichtung == 1 and a.x > 600) or (alienRichtung == -1 and a.x < 20) then
                randGetroffen = true
                break
            end
        end
    end

    -- Wenn ein Rand getroffen wurde: Richtung umkehren und alle Aliens eine Stufe absenken
    if randGetroffen then
        alienRichtung = -alienRichtung
        for _, a in ipairs(aliens) do
            if a.active then
                a.y = a.y + 12 -- Nach unten rücken
            end
        end
    else
        -- Normaler Schritt zur Seite
        for _, a in ipairs(aliens) do
            if a.active then
                a.x = a.x + (alienRichtung * alienSpeed)
            end
        end
    end
    -- ====================================================================
    -- ALIEN ANGRIFFS-KI (Zufälliges Feuern aus der ersten Reihe)
    -- ====================================================================
    -- Ein kleiner Zufallstrigger: ca. alle 30 Frames (0.5 Sek) schießt ein Alien
    if math.random(1, 30) == 1 then
        -- Alle aktuell noch lebenden Aliens in eine Liste packen
        local lebendeAliens = {}
        for _, a in ipairs(aliens) do
            if a.active then table.insert(lebendeAliens, a) end
        end
        
        -- Wenn noch Aliens da sind, ein zufälliges auswählen und feuern lassen!
        if #lebendeAliens > 0 then
            local schuetze = lebendeAliens[math.random(1, #lebendeAliens)]
            table.insert(alienProjektile, { x = schuetze.x, y = schuetze.y + 12 })
        end
    end

    -- 3. KOLLISIONS-PRÜFUNG (Laser trifft Alien)
    -- Wir tasten über eine 2D-Box-Kollision (16x16 Pixel) ab
    for pIdx = #projektile, 1, -1 do
        local p = projektile[pIdx]
        
        for _, a in ipairs(aliens) do
            if a.active then
                -- Prüfen, ob die 16x16 Boxen von Laser und Alien überlappen
                if p.x + 2 >= a.x and p.x <= a.x + 14 and p.y >= a.y and p.y <= a.y + 16 then
                    -- Treffer! 
                    a.active = false -- Alien deaktivieren
                    table.remove(projektile, pIdx) -- Laser löschen
                    score = score + 10 -- Punkte erhöhen
                    sprite.hide(SLOT_LASER) --Spieler Laser loeschen
                    break -- Schleife für diesen Laser abbrechen
                end
            end
        end
    end
    -- ====================================================================
    -- NEU: COLLISIONS-PRÜFUNG (Alien-Laser trifft Spieler)
    -- ====================================================================
    for apIdx = #alienProjektile, 1, -1 do
        local ap = alienProjektile[apIdx]
        
        -- Prüfen, ob der Alien-Schuss die 16x16 Box des Spielerschiffs überlappt
        if ap.x + 2 >= spielerX and ap.x <= spielerX + 16 and ap.y >= spielerY and ap.y <= spielerY + 16 then
            -- Treffer! Schuss entfernen und Leben abziehen
            table.remove(alienProjektile, apIdx)
            leben = leben - 1
            sprite.hide(SLOT_ALIEN_LASER)
           -- [Hier könnte später ein Explosions-Sound abgespielt werden]
            break
        end
    end
end


-- Zeichnet alle Objekte in den flackerfreien Hintergrund-Puffer
local function rendern()
    -- 1. Hintergrund mit Ihrer Kachel-Engine schwärzen
    --sprite.cls(0)
    
    -- 2. HUD (Score) ganz oben platzieren
    vga.text(1, 1, "SCORE: " .. string.format("%04d", score), 255, 0)
    vga.text(16, 1, "LEBEN: " .. string.rep("X", leben), 196, 0) -- Zeichnet "XXX", "XX" oder "X"
    vga.text(32, 1, "=== SPACE INVADERS ===", 47, 0)
    vga.line(0, 18, 640, 18, 40)

    -- 3. INTERAKTIVE ALIEN-ARMEE ZEICHNEN
    local verbleibendeAliens = 0
    for _, a in ipairs(aliens) do
        if a.active then
            sprite.draw(a.hw_id,a.x, a.y, SLOT_ALIEN)
            verbleibendeAliens = verbleibendeAliens + 1
        else
            -- Sicherstellen, dass tote Aliens aus dem Hardware-Register fliegen
            -- (Nutzt Ihr registriertes sprite.hide Kommando)
            -- Da das ein Grid ist, reicht hide() pro zerstörtem Slot aus
           sprite.hide(a.hw_id)
        end
    end

    -- 4. LASER-PROJEKTILE ZEICHNEN
    for _, p in ipairs(projektile) do
        sprite.draw(p.x, p.y, SLOT_LASER)
    end
    -- ====================================================================
    -- ALIEN-LASER PROJEKTILE ZEICHNEN
    -- ====================================================================
    local maxAlienSchuesse = 10 -- Maximale Anzahl gleichzeitig erlaubter Schüsse
    
    for i = 1, maxAlienSchuesse do
        local hardwareKanal = 54 + i
        local ap = alienProjektile[i]
        
        if ap then
            -- Wenn an diesem Index ein Projektil existiert -> Zeichnen!
            sprite.draw(hardwareKanal, ap.x, ap.y, SLOT_ALIEN_LASER)
        else
            -- WICHTIGER FIX: Wenn kein Projektil mehr da ist, blenden wir 
            -- diesen Hardware-Kanal augenblicklich aus! Das löscht die Geister.
            sprite.hide(hardwareKanal)
        end
    end


    -- 5. SPIELER-SCHIFF ZEICHNEN
    sprite.draw(spielerX, spielerY, SLOT_SPIELER)

    -- 6. GEWINN- / VERLUST-PRÜFUNG
    if verbleibendeAliens == 0 then
        vga.text(26, 28, "VICTORY! ALL ALIENS DESTROYED", 47, 0)
        vga.text(24, 30, "Druecke eine Taste fuer Neustart", 255, 0)
        return "NEUSTART_BEREIT"
    end
    -- NEU: Game Over, wenn die Leben auf 0 gesunken sind!
    if leben <= 0 then
        vga.text(28, 28, "GAME OVER! YOUR SHIP WAS DESTROYED", 196, 0)
        vga.text(22, 30, "Druecke LEERTASTE fuer Neustart", 255, 0)
        return "NEUSTART_BEREIT"
    end
    -- Prüfen, ob die Aliens die Verteidigungslinie des Spielers durchbrochen haben
    for _, a in ipairs(aliens) do
        if a.active and a.y >= spielerY - 10 then
            vga.text(28, 28, "GAME OVER! EARTH INVASION", 196, 0)
            vga.text(24, 30, "Druecke eine Taste fuer Neustart", 255, 0)
        end
    end
    
    return "SPIELT_NOCH"
end

-- Startet die interaktive Arcade-Schleife
function SpaceInvaders.start()
    SpaceInvaders.init()
    
    local running = true
    local lastShot = 0
    
    while running do
        -- 1. HARDWARE-TASTENABFRAGE (inkey() liefert reine ASCII-Werte)
        local taste = inkey()
        
        if taste == 27 then -- ESC: Zurück zum Terminal
            running = false
        end
        local spielStatus = rendern()
        if spielStatus == "NEUSTART_BEREIT" then
            if taste == 32 then
                for _, a in ipairs(aliens) do
                    sprite.hide(a.hw_id)
                end
                SpaceInvaders.init()
            end
        else 
            if taste == 216 then -- PFEIL LINKS
            spielerX = spielerX - 8
               if spielerX < 10 then spielerX = 10 end
            elseif taste == 215 then  -- PFEIL RECHTS
               spielerX = spielerX + 8
               if spielerX > 614 then spielerX = 614 end
            elseif taste == 32 then -- LEERTASTE: Laser abfeuern (mit Cooldown)
               local jetzt = sys.timer()
               if jetzt - lastShot > 400 then -- Maximal alle 400ms ein Schuss
                  lastShot = jetzt
                  table.insert(projektile, { x = spielerX, y = spielerY - 12 })
            end
        end

        -- 2. PHYSIK UND KOLLISIONEN BERECHNEN
        SpaceInvaders.updateLogik()
    end
        -- 3. ALLES IM HINTERGRUND AUFBAUEN
        -- rendern()
    
        -- 4. HARDWARE-FLIP (Kopplung an vga.run_gfxengine)
        -- Schiebt das gesamte Bild ruckel- und flackerfrei auf den VGA-Monitor!
        sprite.update()

        vga.waitsync() --delay(16) -- Framerate auf solide ~60 FPS einpegeln
    end
    
    -- Beim Verlassen Bildschirm aufräumen
    for _, a in ipairs(aliens) do sprite.hide(a.hw_id) end
    for i= 0, 64 do 
        sprite.hide(i)
    end
   
    sprite.hide(0)
    sprite.cls(0)
    sprite.update()
end
SpaceInvaders.start()
-- Das Modul an das require()-System übergeben
collectgarbage("collect")
return SpaceInvaders
