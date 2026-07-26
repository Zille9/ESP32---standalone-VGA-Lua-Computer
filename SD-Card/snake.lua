-- ============================================================================
-- SNAKE FÜR TEENSY VGA
-- ============================================================================

-- 1. Spiel-Konfiguration (Abgestimmt auf VGA 320x240)
local FeldBreite  = 33   -- Anzahl der Raster-Blöcke horizontal
local FeldHoehe   = 25   -- Anzahl der Raster-Blöcke vertikal
local BlockGroesse = 8  -- Pixelgröße pro Block (40 * 12 = 480, 30 * 12 = 360)
local StartX       = 20 -- X-Versatz auf dem VGA-Bildschirm für Zentrierung
local StartY       = 20  -- Y-Versatz auf dem VGA-Bildschirm

-- Farben (Passen Sie die Werte an Ihre VGA-Lib an, z.B. RGB565)
local FARBE_SCHWARZ = 0
local FARBE_GRUEN   = 12  -- Beispiel für RGB565 Grün
local FARBE_ROT     = 48 -- Beispiel für RGB565 Rot
local FARBE_WEISS  = 63 -- Beispiel für RGB565 Weiß

-- 2. Spiel-Variablen
local schlange = {}      -- Array für die Körperteile {x, y}
local richtung = "RECHTS" -- Aktuelle Bewegungsrichtung
local futter   = {x = 0, y = 0}
local punkte   = 0
local spielAktiv = true
local Spiellaeuft= true
local geschwindigkeit = 150 -- Update-Intervall in Millisekunden (niedriger = schneller)
local letztesUpdate    = sys.timer() -- Nutzt Ihren registrierten system.timer()

local fcolor, bcolor = vga.gcolor()


local rx1 = StartX - 2
local ry1 = StartY - 2
local rx2 = StartX + (FeldBreite * BlockGroesse) - 1
local ry2 = StartY + (FeldHoehe * BlockGroesse) - 1

vga.cursor(false)

-- 3. Funktionen
local function erstelleFutter()
    -- Futter an zufälliger Position generieren (srand wurde in C++ gesetzt!)
    futter.x = math.random(1, FeldBreite)
    futter.y = math.random(1, FeldHoehe)
end

local function spielInitialisieren()
    schlange = {
        {x = 5, y = 15}, -- Kopf
        {x = 4, y = 15}, -- Körper
        {x = 3, y = 15}  -- Schwanz
    }
    richtung = "RECHTS"
    punkte = 0
    spielAktiv = true
    erstelleFutter()
    vga.cls(bcolor)
end

local function zeichneBlock(bx, by, farbe)
    -- Berechnet die echten VGA-Pixelkoordinaten
    local px = StartX + (bx - 1) * BlockGroesse
    local py = StartY + (by - 1) * BlockGroesse
    -- Zeichnet ein ausgefülltes Rechteck für den Block
    vga.box(px, py, BlockGroesse - 2, BlockGroesse - 2, farbe)
end

local function spielfeldZeichnen()
    -- Rahmen um das Spielfeld zeichnen
    vga.rect(rx1, ry1, rx2-rx1 , ry2-ry1, FARBE_WEISS)

    -- Futter zeichnen
    zeichneBlock(futter.x, futter.y, FARBE_ROT)

    -- Schlange zeichnen
    for i, segment in ipairs(schlange) do
        zeichneBlock(segment.x, segment.y, FARBE_GRUEN)
    end

    -- Punktestand anzeigen
    vga.pos(1,1)
    vga.color(FARBE_WEISS, FARBE_SCHWARZ)
    print("PUNKTE: " .. punkte)
    --print(schlange[1].x .. "  " .. schlange[1].y)
end

local function tastaturAbfrage()
    -- Nutzt Ihre registrierte 'inkey' Funktion, um die Tastatur abzufragen
    -- (Passen Sie die Tasten 'w', 'a', 's', 'd' oder Pfeiltasten an Ihr System und Scancodes an)
    local taste = inkey() 
    
    if taste then
        if (taste == 218) and richtung ~= "UNTEN" then richtung = "OBEN" end
        if (taste == 217) and richtung ~= "OBEN" then richtung = "UNTEN" end
        if (taste == 216) and richtung ~= "RECHTS" then richtung = "LINKS" end
        if (taste == 215) and richtung ~= "LINKS" then richtung = "RECHTS" end
        if (taste == 27) then Spiellaeuft = false end

        -- Wenn das Spiel vorbei ist und man ENTER (Code 13) drückt -> Neustart
        --if not spielAktiv and (taste == 13 or taste == "enter") then
        --    spielInitialisieren()
        --end
    end
end

local function spielLogik()
    -- Berechne neue Kopfposition basierend auf der Richtung
    local kopfX = schlange[1].x
    local kopfY = schlange[1].y

    if richtung == "OBEN"   then kopfY = kopfY - 1 end
    if richtung == "UNTEN"  then kopfY = kopfY + 1 end
    if richtung == "LINKS"  then kopfX = kopfX - 1 end
    if richtung == "RECHTS" then kopfX = kopfX + 1 end

    -- Kollision mit der Wand prüfen
    if kopfX < 1 or kopfX > FeldBreite or kopfY < 1 or kopfY > FeldHoehe then
        spielAktiv = false
        return
    end

    -- Kollision mit dem eigenen Körper prüfen
    for i, segment in ipairs(schlange) do
        if segment.x == kopfX and segment.y == kopfY then
            spielAktiv = false
            return
        end
    end

    -- Neuen Kopf vorne am Array einfuegen
    table.insert(schlange, 1, {x = kopfX, y = kopfY})

    -- Pruefen, ob Futter gefressen wurde
    if kopfX == futter.x and kopfY == futter.y then
        punkte = punkte + 10
        erstelleFutter()
        -- Altes Bild kurz saeubern, damit gefressenes Futter verschwindet
        vga.box(rx1, ry1, rx2-rx1, ry2-ry1, bcolor) 
    else
        -- Wenn kein Futter gefressen wurde, entfernen wir das Schwanzsegment
        -- Das lässt die Schlange sich vorwärts bewegen, ohne zu wachsen
        local alt = table.remove(schlange)
        -- Den alten Block auf dem VGA-Schirm löschen, um Schlieren zu vermeiden
        zeichneBlock(alt.x, alt.y, bcolor)
    end
end

-- ============================================================================
-- MAIN LOOP (Hauptschleife des Spiels)
-- ============================================================================
spielInitialisieren()

-- Wenn Ihr Teensy das Skript blockierend ausführt, nutzen wir eine while-Schleife.
-- Drücken Sie Strg+C (oder wie Ihr System abbricht), um das Spiel zu beenden.
while Spiellaeuft do
    tastaturAbfrage()

    if spielAktiv then
        -- Zeitgesteuertes Update (Nicht-blockierend!)
        local jetzt = sys.timer()
        if (jetzt - letztesUpdate) >= geschwindigkeit then
            letztesUpdate = jetzt
            spielLogik()
            spielfeldZeichnen()
        end
    else
        -- Game Over Bildschirm
        vga.pos(18, 10)
        vga.color(FARBE_ROT, bcolor)
        print("--- GAME OVER ---")
        vga.pos(14, 13)
        vga.color(FARBE_WEISS, bcolor)
        print("Druecke ENTER fuer Neustart")
        vga.waitsync()
        local was = waitkey()
        if was == 27 then Spiellaeuft = false end
        if was == 13 then spielInitialisieren() end
        
    end
    
    -- Kurze Entlastung für das Teensy-System (Nutzt Ihren C++ delay-Wrapper)
    vga.waitsync() 
end
vga.cursor(true)
collectgarbage("collect")