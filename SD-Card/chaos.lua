-- ===================================================
-- LUA SIERPINSKI-DREIECK VIA CHAOS-SPIEL (640x480)
-- ===================================================

vga.cls()
vga.pos(0, 0)
print("Sierpinski Chaos-Spiel. Druecke eine Taste zum Abbrechen...\n\r")

-- Die drei Eckpunkte des Hauptdreiecks festlegen
local ecken = {
    { x = 160, y = 10  },  -- Oben Mitte
    { x = 10,  y = 220 },  -- Unten Links
    { x = 310, y = 220 }   -- Unten Rechts
}

-- Startpunkt irgendwo in der Mitte
local curX = 320
local curY = 120

-- Wir zeichnen 50.000 Punkte
for i = 1, 50000 do
    -- Eine Ecke zufällig auswählen (1, 2 oder 3)
    local zielEcke = math.random(1, 3)
    local ecke = ecken[zielEcke]
    
    -- Den Mittelpunkt der Strecke zwischen aktuellem Punkt und der Ecke berechnen
    curX = (curX + ecke.x) / 2
    curY = (curY + ecke.y) / 2
    
    -- Jede Ecke bekommt im 256-Farben-Modus ihre eigene Farbpalette!
    local farbe = 100 + (zielEcke * 40) + (i % 8)
    
    -- Pixel zeichnen
    vga.pset(math.floor(curX), math.floor(curY), farbe % 256)
    
    -- Alle 200 Punkte kurz dem System Luft geben, damit es flüssig zeichnet
    if i % 200 == 0 then
        delay(1)
    end
end

vga.pos(0, 1)
