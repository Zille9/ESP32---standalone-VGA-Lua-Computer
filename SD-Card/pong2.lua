-- ============================================================================
-- TEXT-BASED PONG (Turnier-Edition: 21 Punkte)
-- ABSOLUT FLACKERFREI DURCH DIRECT TERM-BUFFER IMPLEMENTIERUNG
-- ============================================================================

-- --- CONFIGURATION (Spielfeldmaße im Textraster 80x60) ---
local SPALTEN = 80
local ZEILEN  = 60

local FeldX1 = 2
local FeldX2 = 77
local FeldY1 = 4
local FeldY2 = 56

-- --- VARIABLEN (In Text-Koordinaten) ---
local spielerY = 25
local cpuY     = 25
local ballX    = 40
local ballY    = 28

-- Ball-Richtungs-Vektoren (Bewegungsschritte im Raster)
local ballDX = 1
local ballDY = 1

-- Merker für den letzten Frame (Zum selektiven Löschen)
local altSpielerY = spielerY
local altCpuY     = cpuY
local altBallX    = ballX
local altBallY    = ballY

-- Spielparameter
local schlaegerHoehe = 8
local punkteSpieler  = 0
local punkteCpu       = 0
local spielLaeuftNoch = true
local geschwindigkeit = 60  -- Millisekunden pro Schritt (kleiner = schneller)
local letztesUpdate   = sys.timer()

-- --- ZEICHEN (Retro Vollblock '█' und Ball 'O') ---
local CHAR_SCHLAEGER = string.char(127) 
local CHAR_BALL      = "O"
local CHAR_LEER      = " "

-- ============================================================================
-- HILFSFUNKTIONEN
-- ============================================================================

-- Setzt den Ball nach einem Punkt zurück
local function ballZuruecksetzen(richtung)
    ballX = 40
    ballY = 28
    ballDX = richtung
    ballDY = 1
    if math.random(1, 2) == 1 then ballDY = -1 end
    
    -- Grafikmerker zurücksetzen, um Reste zu vermeiden
    altBallX = ballX
    altBallY = ballY
end

-- Gewinner-Bildschirm mit Neustart-Logik
local function gewonnen(gewinner)
    vga.cls()
    
    if gewinner == 1 then 
        vga.text(22, 22, "COMPUTER GEWINNT " .. punkteCpu .. " ZU " .. punkteSpieler, 255, 0)
    elseif gewinner == 2 then
        vga.text(22, 22, "SPIELER GEWINNT " .. punkteSpieler .. " ZU " .. punkteCpu, 255, 0)
    end
    
    vga.text(22, 26, "Druecke ENTER fuer neues Spiel", 255, 0)
    vga.text(22, 28, "Druecke ESC zum Beenden", 255, 0)
    
    while true do
        local taste = waitkey(false)
        
        -- ENTER -> Spiel von vorne starten
        if taste == 13 then
            punkteSpieler = 0
            punkteCpu = 0
            spielerY = 25
            cpuY = 25
            vga.cls()
            -- Rahmen und Punkte einmalig neu aufbauen
            vga.text(15, 2, "SPIELER: 0", 255, 0)
            vga.text(55, 2, "CPU: 0", 255, 0)
            for x = FeldX1, FeldX2 do
                vga.text(x, FeldY1, string.char(127), 255, 0)
                vga.text(x, FeldY2, string.char(127), 255, 0)
            end
            ballZuruecksetzen(1)
            break 
            
        -- ESC -> Zurück zum Terminal
        elseif taste == 27 then
            spielLaeuftNoch = false
            break
        end
        delay(5)
    end
end

-- Zeichnet die statische Umgebung (Wände & Punkte)
local function zeichneSpielfeld()
    -- Punkte aktualisieren (Nur an den festen Positionen überschreiben)
    vga.text(15, 2, "SPIELER: " .. punkteSpieler, 255, 0)
    vga.text(55, 2, "CPU: " .. punkteCpu, 255, 0)
    
    -- Obere und untere Begrenzungslinie
    for x = FeldX1, FeldX2 do
        vga.text(x, FeldY1, string.char(127), 24, 0)
        vga.text(x, FeldY2, string.char(127), 24, 0)
    end
end

-- ============================================================================
-- INITIALISIERUNG VOR DEM START
-- ============================================================================
vga.cls()
zeichneSpielfeld()

-- ============================================================================
-- HAUPTSCHLEIFE
-- ============================================================================
while spielLaeuftNoch do

    -- 1. ECHTZEIT-TASTENABFRAGE (Spieler-Steuerung per Pfeiltasten)
    local taste = inkey()
    if taste then
        if taste == 27 then
            spielLaeuftNoch = false
        elseif (taste == 218) then -- PFEIL HOCH
            spielerY = spielerY - 2
            if spielerY < FeldY1 + 2 then spielerY = FeldY1 + 1 end
        elseif (taste == 217) then -- PFEIL RUNTER
            spielerY = spielerY + 2
            if spielerY > FeldY2 - schlaegerHoehe then spielerY = FeldY2 - schlaegerHoehe end
        end
    end

    -- 2. ZEITGESTEUERTES PHYSIK- UND GRAFIK-UPDATE
    local jetzt = sys.timer()
    if (jetzt - letztesUpdate) >= geschwindigkeit and spielLaeuftNoch then
        letztesUpdate = jetzt
        
        -- --- BALL-PHYSIK ---
        ballX = ballX + ballDX
        ballY = ballY + ballDY
        
        -- Wand-Kollision oben / unten
        if ballY <= FeldY1 + 1 then
            ballY = FeldY1 + 1
            ballDY = -ballDY
        elseif ballY >= FeldY2 - 1 then
            ballY = FeldY2 - 1
            ballDY = -ballDY
        end
        
        -- --- CPU KI STEUERUNG (Folgt dem Ball intelligent) ---
        local cpuMitte = cpuY + math.floor(schlaegerHoehe / 2)
        if ballY < cpuMitte and math.random(1, 10) > 2 then
            cpuY = cpuY - 1
        elseif ballY > cpuMitte and math.random(1, 10) > 2 then
            cpuY = cpuY + 1
        end
        -- CPU Grenzen einhalten
        if cpuY < FeldY1 + 1 then cpuY = FeldY1 + 1 end
        if cpuY > FeldY2 - schlaegerHoehe then cpuY = FeldY2 - schlaegerHoehe end
        
        -- --- KOLLISION MIT DEN SCHLÄGERN ---
        -- Linker Schläger (Spieler in Spalte 4)
        if ballDX < 0 and ballX == 5 then
            if ballY >= spielerY and ballY < spielerY + schlaegerHoehe then
                ballDX = -ballDX
                ballX = 6 -- Tunneling verhindern
            end
        end
        
        -- Rechter Schläger (CPU in Spalte 74)
        if ballDX > 0 and ballX == 74 then
            if ballY >= cpuY and ballY < cpuY + schlaegerHoehe then
                ballDX = -ballDX
                ballX = 73 -- Tunneling verhindern
            end
        end
        
        -- --- PUNKTE- UND TURNIERPRÜFUNG (Offiziell bis 21 mit 2 Vorsprung) ---
        local punktErziehlt = false
        
        if ballX <= FeldX1 then
            punkteCpu = punkteCpu + 1
            punktErziehlt = true
            if punkteCpu >= 21 and (punkteCpu - punkteSpieler) >= 2 then
                gewonnen(1)
            end
            if spielLaeuftNoch then ballZuruecksetzen(1) end
            
        elseif ballX >= FeldX2 then
            punkteSpieler = punkteSpieler + 1
            punktErziehlt = true
            if punkteSpieler >= 21 and (punkteSpieler - punkteCpu) >= 2 then
                gewonnen(2)
            end
            if spielLaeuftNoch then ballZuruecksetzen(-1) end
        end
        
        -- Wenn gepunktet wurde, einmal Schirm putzen und Feld auffrischen
        if punktErziehlt and spielLaeuftNoch then
            vga.cls()
            zeichneSpielfeld()
        end

        -- ====================================================================
        -- DIE FLACKERFREIE TEXT-GRAFIKZENTRALE (Direkt über den termBuffer)
        -- ====================================================================
        if spielLaeuftNoch then
            -- A) ALTE Positionen restlos löschen (Leerzeichen drüberdrucken)
            for i = 0, schlaegerHoehe - 1 do
                vga.text(4, altSpielerY + i, CHAR_LEER)
                vga.text(75, altCpuY + i, CHAR_LEER)
            end
            vga.text(altBallX, altBallY, CHAR_LEER)
            
            -- B) NEUE Positionen in Mikrosekunden drüberzeichnen
            for i = 0, schlaegerHoehe - 1 do
                vga.text(4, spielerY + i, CHAR_SCHLAEGER)
                vga.text(75, cpuY + i, CHAR_SCHLAEGER)
            end
            vga.text(ballX, ballY, CHAR_BALL)
            
            -- C) Die aktuellen Positionen als "alt" für den nächsten Takt sichern
            altSpielerY = spielerY
            altCpuY     = cpuY
            altBallX    = ballX
            altBallY    = ballY
        end
    end
    
    --delay(2) -- Minimale Entlastung für das OS-Multitasking
end

-- Nach dem regulären Verlassen (ESC) den Bildschirm für das Terminal säubern
vga.cls()