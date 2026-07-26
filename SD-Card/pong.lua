-- ============================================================================
-- PONG: SPIELER GEGEN ESP32-CPU (VGA 320x240)
-- ============================================================================

-- 1. VGA-Farben (RGB565)
local FARBE_SCHWARZ = 0
local FARBE_WEISS   = 255
local FARBE_GRAU    = 114
local FARBE_ROT     = 48 
local FARBE_GRUEN   = 8
local FARBE_BRAUN   = 104

-- 2. Spiel-Konfiguration (Spielfeldbereich)
local FeldX1 = 20
local FeldY1 = 20
local FeldX2 = 290
local FeldY2 = 210

local SchlaegerBreite = 4
local SchlaegerHoehe  = 35
local BallGroesse     = 8
local SpielerGeschw   = 20

-- 3. Spiel-Variablen
local spielerY = 70 -- Start-Y links
local cpuY     = 70 -- Start-Y rechts (CPU)

local ballX  = 120
local ballY  = 120
local ballDX = 2   -- Geschwindigkeit X (Richtung)
local ballDY = 2   -- Geschwindigkeit Y (Richtung)
local altSpielerY = spielerY
local altCpuY = cpuY
local altBallX = ballX
local altBallY = ballY

local punkteSpieler = 0
local punkteCpu     = 0

local letztesUpdate = sys.timer()
local geschwindigkeit = 16 -- ca. 60 FPS Update-Intervall


-- Hilfsfunktion fuer Text-Positionierung (Zeichen-Raster: geteilt durch 8)
local function textPos(pixelX, pixelY)
    vga.pos(math.floor(pixelX / 6), math.floor(pixelY / 8))
end

local function ballZuruecksetzen(richtung)
    ballX = 120
    ballY = 120
    ballDX = richtung * 4
    ballDY = (math.random(0, 1) == 0 and 3 or -3)
    vga.box(FeldX1-9,FeldY1,FeldX2-FeldX1,FeldY2-FeldY1+11, FARBE_GRUEN)

end



local function zeichneSpielfeld()
    -- Nur den Spielbereich saeubern, um Flackern zu minimieren
        
    -- Rahmen aussen herum zeichnen
    vga.rect(FeldX1-10,FeldY1-10, FeldX2+11,FeldY2+2,FARBE_WEISS)
    
    -- Mittellinie (gestrichelt simuliert ueber kurze Linien)
    for y = FeldY1, FeldY2-10, 20 do
        vga.line(155, y, 155, y + 10, FARBE_WEISS)
    end
    
    -- Linker Schläger (Spieler)
    vga.box(FeldX1 + 10, spielerY, SchlaegerBreite, SchlaegerHoehe, FARBE_WEISS)
    
    -- Rechter Schläger (CPU)
    vga.box(FeldX2 - 10 + SchlaegerBreite , cpuY, SchlaegerBreite, SchlaegerHoehe, FARBE_WEISS)
    
    -- Ball zeichnen
    vga.fillellipse(ballX, ballY, BallGroesse, BallGroesse, FARBE_ROT, FARBE_GRUEN)
    
    -- Punktestand anzeigen (Text-Raster)
    vga.text(60/6,0,tostring(punkteSpieler),FARBE_WEISS,104,true)
    vga.text(260/6,0,tostring(punkteCpu),FARBE_WEISS,104,true)
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================
local spielLaeuftNoch = true


local function gewonnen(gewinner)
   if gewinner == 1 then 
      vga.text(12,10,"Computer gewinnt " .. punkteCpu .. " zu " .. punkteSpieler,FARBE_WEISS,FARBE_GRUEN)
      spielLaeuftNoch = false
   elseif gewinner == 2 then
      vga.text(12,10,"Spieler gewinnt " .. punkteSpieler .. " zu " .. punkteCpu,FARBE_WEISS,FARBE_GRUEN)
      spielLaeuftNoch = false
   end
   
   vga.text(12,12,"Nochmal? [ENTER] Beenden [ESC]",FARBE_WEISS,FARBE_GRUEN)
   
   while true do
      local taste = waitkey()
      
      -- Fall A: ENTER (Code 13) -> Alles zuruecksetzen!
      if taste == 13 then
         spielLaeuftNoch = true
         punkteSpieler = 0
         punkteCpu = 0
         spielerY = 170
         cpuY = 170
         ballZuruecksetzen(1) -- Spiel von vorn
         -- Wichtig: Wir brechen die Auswahlschleife ab, spielLaeuftNoch bleibt TRUE!
         break 
         
      -- Fall B: ESC (Code 27) -> Spiel wirklich beenden
      elseif taste == 27 then
         spielLaeuftNoch = false -- Beendet die while-Schleife des Hauptspiels
         vga.cls()
         vga.text(17,12,"PONG beendet !",245,0)
         delay(5000)
         vga.cls()
         break
      end
      
      delay(5) -- Kleine Entlastung fuer den Core   
  end
end




-- Vor der Schleife: Das Spielfeld EINMALIG komplett aufbauen
    vga.cls(FARBE_BRAUN)
    vga.box(FeldX1-9,FeldY1-9,FeldX2-FeldX1+30,FeldY2-FeldY1+21, FARBE_GRUEN)

    zeichneSpielfeld()


while spielLaeuftNoch do
    -- 1. Tastabfrage fuer den Spieler
    local taste = inkey()
    if taste then
        if taste == 27 then
            spielLaeuftNoch = false
        elseif (taste == 218) then
            spielerY = spielerY - SpielerGeschw
            if spielerY < FeldY1 + 5 then spielerY = FeldY1 + 5 end
        elseif (taste == 217) then
            spielerY = spielerY + SpielerGeschw
            if spielerY > FeldY2 - SchlaegerHoehe - 5 then spielerY = FeldY2 - SchlaegerHoehe - 5 end
        end
    end

    -- 2. Zeitgesteuertes Update
    local jetzt = sys.timer()
    if (jetzt - letztesUpdate) >= geschwindigkeit and spielLaeuftNoch then
        letztesUpdate = jetzt
        
        -- --- BALL-PHYSIK ---
        ballX = ballX + ballDX
        ballY = ballY + ballDY
        
        if ballY <= FeldY1 + 2 or ballY >= FeldY2 - BallGroesse - 2 then
            ballDY = -ballDY
        end
        
        -- --- CPU KI STEUERUNG ---
        local cpuMitte = cpuY + (SchlaegerHoehe / 2)
        if ballY < cpuMitte - 10 then
            cpuY = cpuY - 2
        elseif ballY > cpuMitte + 10 then
            cpuY = cpuY + 2
        end
        if cpuY < FeldY1 + 5 then cpuY = FeldY1 + 5 end
        if cpuY > FeldY2 - SchlaegerHoehe - 5 then cpuY = FeldY2 - SchlaegerHoehe - 5 end
        
        -- --- KOLLISION MIT SCHLÄGERN ---
        if ballDX < 0 and ballX <= FeldX1 + 10 + SchlaegerBreite and ballX >= FeldX1 + 5 then
            if ballY + BallGroesse >= spielerY and ballY <= spielerY + SchlaegerHoehe then
                ballDX = -ballDX
                ballDX = ballDX * 1.05 
                ballX = FeldX1 + 10 + SchlaegerBreite + 1
            end
        end
        if ballDX > 0 and ballX + BallGroesse >= FeldX2 - 10 - SchlaegerBreite and ballX <= FeldX2 - 5 then
            if ballY + BallGroesse >= cpuY and ballY <= cpuY + SchlaegerHoehe then
                ballDX = -ballDX
                ballDX = ballDX * 1.05
                ballX = FeldX2 - 10 - SchlaegerBreite - BallGroesse - 1
            end
        end
        
        -- --- PUNKTE / AUS-PRUEFUNG ---
        local punktErziehlt = false
        
        if ballX < FeldX1 then
            punkteCpu = punkteCpu + 1
            punktErziehlt = true
            if punkteCpu >= 21 and (punkteCpu - punkteSpieler) >= 2 then
               gewonnen(1)
            end
            if spielLaeuftNoch then ballZuruecksetzen(1) end
            
        elseif ballX > FeldX2 then
            punkteSpieler = punkteSpieler + 1
            punktErziehlt = true
            if punkteSpieler >= 21 and (punkteSpieler - punkteCpu) >= 2 then
               gewonnen(2)
            end
            if spielLaeuftNoch then ballZuruecksetzen(-1) end
        end
        
            zeichneSpielfeld()

        -- ====================================================================
        -- SCHNELLES ZEICHNEN DER AKTIVEN OBJEKTE
        -- ====================================================================
        if spielLaeuftNoch then
            -- 1. ALTE Positionen loeschen (Schwarz = 0)
            vga.box(FeldX1 + 10, altSpielerY, SchlaegerBreite, SchlaegerHoehe, FARBE_GRUEN)
            vga.box(FeldX2 - 10 + SchlaegerBreite, altCpuY, SchlaegerBreite, SchlaegerHoehe, FARBE_GRUEN)
            vga.fillellipse(altBallX, altBallY, BallGroesse+2, BallGroesse+2, FARBE_GRUEN)
            
            -- 2. NEUE Positionen zeichnen (Weiss = 255)
            vga.box(FeldX1 + 10, spielerY, SchlaegerBreite, SchlaegerHoehe, FARBE_WEISS)
            vga.box(FeldX2 - 10 + SchlaegerBreite, cpuY, SchlaegerBreite, SchlaegerHoehe, 255)
            vga.fillellipse(ballX, ballY, BallGroesse, BallGroesse, FARBE_ROT,FARBE_ROT)
            
            -- 3. Positionen merken
            altSpielerY = spielerY
            altCpuY = cpuY
            altBallX = ballX
            altBallY = ballY
        end
    end
    
    vga.waitsync() --delay(5)
end
    

-- Aufraeumen bei Rueckkehr ins Terminal
vga.cls()
print("Pong beendet. Zurueck zum Terminal.")