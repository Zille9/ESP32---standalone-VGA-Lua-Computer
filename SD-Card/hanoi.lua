-- ============================================================================
-- TÜRME VON HANOI FÜR ESP32 FABGL (320x240)
-- ============================================================================

-- 1. VGA-Farben (Angepasst an Ihre 64-Farben-Palette)
local FARBE_SCHWARZ = 0
local FARBE_WEISS   = 63
local FARBE_GRAU    = 42
local FARBE_ROT     = 48
local FARBE_GRUEN   = 12
local FARBE_BLAU    = 3
local FARBE_GELB    = 60
local FARBE_MAGENTA = 51

local fc,bc = vga.gcolor()

local scheibenFarben = { FARBE_ROT, FARBE_GELB, FARBE_BLAU, FARBE_GRUEN, FARBE_MAGENTA, FARBE_WEISS }

-- 2. Spiel-Konfiguration fuer 320x240
local anzahlScheiben = 5 
local turmX = { 60, 160, 260 }   -- Perfekt aufgeteilt auf 320 Pixel Breite
local basisY = 180               -- Bodenplatte im unteren Drittel
local stabHoehe = 80             -- Hoehe der Tuerme
local scheibenHoehe = 10         -- Etwas flacher fuer 240er Hoehe
local maxScheibenBreite = 54     -- Maximale Breite der untersten Scheibe

local tuerme = { {}, {}, {} }
local zuege = 0
local auswahlTurm = nil 
local statusText = "Quell-Turm waehlen (1-3) oder ESC"

-- Hilfsfunktion: Wandelt Pixel in Zeichen-Positionen um (geteilt durch 6x8 Textraster)
local function textPos(pixelX, pixelY)
    vga.pos(math.floor(pixelX / 6), math.floor(pixelY / 8))
end

-- 3. Funktionen
local function spielInitialisieren()
    tuerme = { {}, {}, {} }
    zuege = 0
    auswahlTurm = nil
    statusText = "Quell-Turm waehlen (1-3) oder ESC"
    
    for i = anzahlScheiben, 1, -1 do
        table.insert(tuerme[1], i)
    end
    vga.cls()
end

local function zeichneSpielfeld()
    vga.cls()
    vga.color(FARBE_WEISS, bc)
    vga.waitsync()
    -- Titel anzeigen (Mittig im 53-Spalten-Raster)
    textPos(80, 10)
    print("--- TUERME VON HANOI ---")
    vga.waitsync()    
    -- Bodenplatte quer (Pixel-Grafik von x=20 bis x=300)
    vga.box(20, basisY, 280, 6, FARBE_GRAU)
    
    for t = 1, 3 do
        local x = turmX[t]
        -- Vertikaler Stab (Pixel-Grafik, 4 Pixel breit)
        vga.box(x - 2, basisY - stabHoehe, 4, stabHoehe, FARBE_GRAU)
        vga.waitsync()
        -- Turm-Nummern direkt unter den Staeben
        textPos(x + 6 , basisY + 20)
        print(tostring(t))
        
        -- Scheiben auf diesem Turm zeichnen
        for sIndex, groesse in ipairs(tuerme[t]) do
            local breite = 16 + (groesse * (maxScheibenBreite / anzahlScheiben))
            local sx = x - (breite / 2)
            local sy = basisY - (sIndex * scheibenHoehe)
            
            local farbe = scheibenFarben[groesse] or FARBE_WEISS
            vga.box(sx, sy, breite, scheibenHoehe, farbe)
            
            -- Schwarze Kanten für bessere Optik im PSRAM-Monitor
            vga.line(sx, sy, sx + breite, sy, FARBE_SCHWARZ)
            vga.line(sx, sy + scheibenHoehe, sx + breite, sy + scheibenHoehe, FARBE_SCHWARZ)
            vga.waitsync()
        end
    end
    
    -- Wenn ein Quell-Turm gewählt wurde, Markierung über dem Stab anzeigen
    if auswahlTurm then
        local ax = turmX[auswahlTurm]
        textPos(ax , basisY - stabHoehe - 12)
        vga.color(FARBE_ROT, bc)
        print("[X]")
        statusText = "Ziel-Turm waehlen (1-3)"
    end
    
    -- Status und Info-Texte im unteren Displaybereich (Zeile 25 und 27)
    textPos(126, 25)
    vga.color(FARBE_GELB, bc)
    print("Zuege: " .. zuege)
    vga.waitsync()
    textPos(20, 222)
    vga.color(FARBE_WEISS, bc)
    print(statusText)
    vga.waitsync()
end

local function bewegeScheibe(von, nach)
    if #tuerme[von] == 0 then
        statusText = "Fehler: Turm ist leer!"
        auswahlTurm = nil
        return
    end
    
    local obersteVon = tuerme[von][#tuerme[von]]
    
    if #tuerme[nach] > 0 then
        local obersteNach = tuerme[nach][#tuerme[nach]]
        if obersteVon > obersteNach then
            statusText = "Ungueltig: Nur kleinere auf groessere!"
            auswahlTurm = nil
            return
        end
    end
    
    table.remove(tuerme[von])
    table.insert(tuerme[nach], obersteVon)
    
    zuege = zuege + 1
    statusText = "Zug erfolgreich! Naechster Zug: (1-3)"
    auswahlTurm = nil
end

local function pruefeSieg()
    if #tuerme[2] == anzahlScheiben or #tuerme[3] == anzahlScheiben then
        zeichneSpielfeld()
        
        -- Sieges-Popup kompakt in die Mitte setzen
        textPos(100, 40)
        vga.color(FARBE_GRUEN, bc)
        print("!!! GEWONNEN !!!")
        
        textPos(100, 60)
        vga.color(FARBE_WEISS, bc)
        print("Sieg in " .. zuege .. " Zuegen!")
        
        textPos(100, 75)
        vga.color(FARBE_GELB, bc)
        if zuege < 34 then 
            print("Sie sind ein Profi!") 
        elseif zuege >= 34 and zuege < 38 then 
            print("Sie haben Potential")
        else 
            print("Sie muessen noch ueben")
        end 
        vga.waitsync()
        vga.color(FARBE_WEISS, bc)
        textPos(100, 90)
        print("ENTER fuer neues Spiel")
        
        local t = waitkey() --inkey()
        if t == 13 or t == "enter" then
           spielInitialisieren()
           zeichneSpielfeld()
           return true

        elseif t == 27 or t == "q" or t == "Q" then
           return false
        end
    end
   return true
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================
spielInitialisieren()
zeichneSpielfeld()

local spielLaeuftNoch = true

while spielLaeuftNoch do
    local taste = waitkey() --inkey()
    
    if taste then
        if taste == 27 or taste == "q" or taste == "Q" then
            spielLaeuftNoch = false
        
        elseif taste == "1" or taste == 49 then
            if not auswahlTurm then 
                auswahlTurm = 1 
            else 
                bewegeScheibe(auswahlTurm, 1) 
            end
            zeichneSpielfeld()
            
        elseif taste == "2" or taste == 50 then
            if not auswahlTurm then 
                auswahlTurm = 2 
            else 
                bewegeScheibe(auswahlTurm, 2) 
            end
            zeichneSpielfeld()
            
        elseif taste == "3" or taste == 51 then
            if not auswahlTurm then 
                auswahlTurm = 3 
            else 
                bewegeScheibe(auswahlTurm, 3) 
            end
            zeichneSpielfeld()
        end
        
        if spielLaeuftNoch then
            spielLaeuftNoch = pruefeSieg()
        end
    end
    
    delay(10)
end

vga.cls()
print("Tuerme von Hanoi beendet. Zurueck zur Shell.")
