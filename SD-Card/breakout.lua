-- ============================================================================
-- HIGH-SPEED BREAKOUT (640x480 VGA-Pixel)
-- ABSOLUT FLACKERFREI DURCH GEZIELTES KANTEN-ÜBERSCHREIBEN
-- ============================================================================

-- --- CONFIGURATION ---
local FeldX1 = 10
local FeldX2 = 310
local FeldY1 = 30
local FeldY2 = 230
local fcolor, bcolor = vga.gcolor()
-- Schläger- und Ball-Maße
local SchlaegerBreite = 40
local SchlaegerHoehe   = 10
local BallGroesse      = 5
local SchlaegerGeschw  = 24

-- Steine-Raster (4 Zeilen x 10 Spalten)
local STEIN_ZEILEN   = 5
local STEIN_SPALTEN  = 10
local STEIN_BREITE   = 25
local STEIN_HOEHE    = 7
local STEIN_ABSTAND_X = 2
local STEIN_ABSTAND_Y = 2
local STEIN_START_Y  = 30

-- --- VARIABLEN ---
local schlaegerX = 160
local schlaegerY = 200
local ballX      = 160
local ballY      = 200

-- Ball-Vektoren (Pixel-Schritte)
local ballDX = 3
local ballDY = -4

-- Merker für den letzten Frame (Zum flackerfreien Löschen)
local altSchlaegerX = schlaegerX
local altBallX      = ballX
local altBallY      = ballY

-- Spiel-Zustand
local punkte         = 0
local leben          = 3
local spielLaeuftNoch = true
local geschwindigkeit = 25  -- Millisekunden pro Frame (~60 FPS)
local letztesUpdate   = sys.timer()

-- --- STEINE-ARRAY INITIALISIEREN ---
-- Jedes Element speichert den VGA-Farb-Index des Steins. 0 = Zerstört.
local steine = {}
local farben = { 196, 240, 255, 127 ,171} -- Rot, Orange, Gelb/Weiß, Cyan

for z = 1, STEIN_ZEILEN do
    steine[z] = {}
    for s = 1, STEIN_SPALTEN do
        steine[z][s] = farben[z] -- Jede Zeile bekommt eine eigene Farbe
    end
end

-- ============================================================================
-- HILFSFUNKTIONEN
-- ============================================================================

-- Zeichnet die statischen Wände und das Steinfeld einmalig komplett auf
local function initialerSpielfeldAufbau()
    vga.cls()
    -- Oberer und seitliche Rahmen (Nutzt Ihre vga.line-Funktion)
    vga.line(FeldX1-5, FeldY1-5, FeldX2+5, FeldY1-5, 127) -- Oben
    vga.line(FeldX1-5, FeldY1-5, FeldX1-5, FeldY2, 127) -- Links
    vga.line(FeldX2+5, FeldY1-5, FeldX2+5, FeldY2, 127) -- Rechts
    vga.box(ballX, ballY, BallGroesse, BallGroesse, 0)
    -- Statuszeile ganz oben im Textraster ausgeben
    vga.text(2, 1, "SCORE: 0000", 255, bcolor,true)
    vga.text(65, 1, "LIVES: OOO", 196, bcolor,true)

    -- Alle Steine initial auf den Schirm bringen
    for z = 1, STEIN_ZEILEN do
        for s = 1, STEIN_SPALTEN do
            if steine[z][s] > 0 then
                local sx = FeldX1 + 10 + (s - 1) * (STEIN_BREITE + STEIN_ABSTAND_X)
                local sy = STEIN_START_Y + (z - 1) * (STEIN_HOEHE + STEIN_ABSTAND_Y)
                vga.box(sx, sy, STEIN_BREITE, STEIN_HOEHE, steine[z][s])
            end
        end
    end
    
    -- Schläger initial zeichnen
    vga.box(schlaegerX, schlaegerY, SchlaegerBreite, SchlaegerHoehe, 255)
end
-- Aktualisiert die Text-Anzeigen oben am Rand, ohne den Rest zu stören
local function updateStatusText()
    vga.text(9, 1, string.format("%04d", punkte), 255, bcolor,true)
    
    local herzen = ""
    for i = 1, leben do herzen = herzen .. "O" end
    for i = leben + 1, 3 do herzen = herzen .. " " end
    vga.text(72, 1, herzen, 196, bcolor,true)
end    
 -- Setzt den Ball nach einem Leben-Verlust zurück
local function ballZuruecksetzen()
    -- Alten Ball auf dem Schirm löschen
    vga.fillellipse(ballX, ballY, BallGroesse, BallGroesse, bcolor,bcolor)
    -- unterste Zeile loeschen, damit der Ball wirklich verschwindet
    vga.box(FeldX1,FeldY2-8,FeldX2-FeldX1,12,bcolor)   
    ballX = schlaegerX + math.floor(SchlaegerBreite / 2) - 4
    ballY = 300
    ballDX = 3
    if math.random(1, 2) == 1 then ballDX = -3 end
    ballDY = -4
    
    altBallX = ballX
    altBallY = ballY
end

-- ============================================================================
-- INITIALISIERUNG VOR DEM START
-- ============================================================================
initialerSpielfeldAufbau()

-- ============================================================================
-- HAUPTSCHLEIFE
-- ============================================================================
while spielLaeuftNoch do

    -- 1. ECHTZEIT-TASTENABFRAGE (Pfeiltasten Links=21; Rechts=6; ESC=27)
    local taste = inkey()
    if taste then
        --if taste == 27 then
        --    spielLaeuftNoch = false
        if taste == 216 then -- PFEIL LINKS
            schlaegerX = schlaegerX - SchlaegerGeschw
            if schlaegerX < FeldX1 + 8 then schlaegerX = FeldX1 + 8 end
        elseif taste == 215 then -- PFEIL RECHTS
            schlaegerX = schlaegerX + SchlaegerGeschw
            if schlaegerX > FeldX2 - SchlaegerBreite - 8 then schlaegerX = FeldX2 - SchlaegerBreite - 8 end
        end
    end

    -- 2. ZEITGESTEUERTES PHYSIK- UND GRAFIK-UPDATE
    local jetzt = sys.timer()
    if (jetzt - letztesUpdate) >= geschwindigkeit and spielLaeuftNoch then
        letztesUpdate = jetzt
        
        -- --- BALL-PHYSIK ---
        ballX = ballX + ballDX
        ballY = ballY + ballDY
        
        -- Wand-Kollision links / rechts
        if ballX <= FeldX1 + 2 then
            ballX = FeldX1 + 2
            ballDX = -ballDX
        elseif ballX >= FeldX2 - BallGroesse - 2 then
            ballX = FeldX2 - BallGroesse - 2
            ballDX = -ballDX
        end
        
        -- Wand-Kollision oben
        if ballY <= FeldY1 + 2 then
            ballY = FeldY1 + 2
            ballDY = -ballDY
        end
        
        -- --- KOLLISION MIT DEM SCHLÄGER ---
        if ballDY > 0 and ballY + BallGroesse >= schlaegerY and ballY <= schlaegerY + SchlaegerHoehe then
            if ballX + BallGroesse >= schlaegerX and ballX <= schlaegerX + SchlaegerBreite then
                -- Abprall-Winkel berechnen je nachdem, wo der Ball den Schläger trifft
                local relativeTrefferStelle = (ballX + (BallGroesse / 2)) - schlaegerX
                local prozent = relativeTrefferStelle / SchlaegerBreite
                
                -- Beeinflusst den horizontalen Vektor für steile/flache Winkel
                ballDX = 8 * (prozent - 0.5)
                ballDY = -ballDY
                ballY = schlaegerY - BallGroesse -- Festkleben verhindern
            end
        end
        
        -- --- KOLLISION MIT DEN STEINEN ---
        local ballMitteX = ballX + (BallGroesse)
        local ballMitteY = ballY + (BallGroesse)
        
        for z = 1, STEIN_ZEILEN do
            for s = 1, STEIN_SPALTEN do
                if steine[z][s] > 0 then
                    local sx = FeldX1 + 10 + (s - 1) * (STEIN_BREITE + STEIN_ABSTAND_X)
                    local sy = STEIN_START_Y + (z - 1) * (STEIN_HOEHE + STEIN_ABSTAND_Y)
                    
                    -- AABB Kollisionsprüfung
                    if ballMitteX >= sx and ballMitteX <= sx + STEIN_BREITE and
                       ballMitteY >= sy and ballMitteY <= sy + STEIN_HOEHE then
                        
                        -- Stein zerstören: Aus dem Array nehmen und SCHWARZ löschen
                        steine[z][s] = 0
                        vga.box(sx, sy, STEIN_BREITE, STEIN_HOEHE, bcolor)
                        
                        -- Ball abprallen lassen und Score erhöhen
                        ballDY = -ballDY
                        punkte = punkte + 10
                        updateStatusText()
                        
                        -- Aus den Schleifen ausbrechen, damit nur 1 Stein pro Frame getroffen wird
                        goto stein_getroffen
                    end
                end
            end
        end
        ::stein_getroffen::
        
        -- --- AUS-PRÜFUNG (Unten durchgerutscht) ---
        if ballY > FeldY2 then
            leben = leben - 1
            updateStatusText()
            
            if leben <= 0 then
                vga.text(15, 15, "GAME OVER! DRUECKE ESC", 196, bcolor,true)
                   -- Warten auf ESC
                   --local taste = waitkey()
                   if taste == 27 then
                      spielLaeuftNoch = false
                    
                      
                   end
                ballZuruecksetzen()
            end
        end
        
        -- ====================================================================
        -- DIE FLACKERFREIE INTERAKTIV-GRAFIK (Dirty-Edge-Changer)
        -- ====================================================================
        if spielLaeuftNoch then
            
            -- 1. SCHLÄGER-GRAFIK: Nur die überstehenden Kanten verschieben
            if schlaegerX < altSchlaegerX then
                -- Bewegung nach LINKS: Rechts abschneiden, links anstücken
                local diff = altSchlaegerX - schlaegerX
                vga.box(schlaegerX + SchlaegerBreite, schlaegerY, diff, SchlaegerHoehe, bcolor)
                vga.box(schlaegerX, schlaegerY, diff, SchlaegerHoehe, 255)
            elseif schlaegerX > altSchlaegerX then
                -- Bewegung nach RECHTS: Links abschneiden, rechts anstücken
                local diff = schlaegerX - altSchlaegerX
                vga.box(altSchlaegerX, schlaegerY, diff, SchlaegerHoehe, bcolor)
                vga.box(altSchlaegerX + SchlaegerBreite, schlaegerY, diff, SchlaegerHoehe, 255)
            end
            
            -- 2. BALL-GRAFIK: Da er klein ist, komplett löschen und neu zeichnen
            vga.fillellipse(altBallX, altBallY, BallGroesse, BallGroesse, bcolor)
            vga.fillellipse(ballX, ballY, BallGroesse, BallGroesse, 196)
            
            -- 3. Merker für den nächsten Frame sichern
            altSchlaegerX = schlaegerX
            altBallX      = ballX
            altBallY      = ballY
        end
    end
    
    --delay(2) -- System-Schonung
end

-- Nach dem Beenden Bildschirm loeschen
collectgarbage()
vga.cls()
