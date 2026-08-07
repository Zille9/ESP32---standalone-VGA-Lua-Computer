-- ============================================================================
-- MATHEMATISCHES GRAFIK-MODUL (plotter.lua) - TEIL 1
-- SYSTEMNAHE KOORDINATEN-TRANSFORMATION FÜR VGA (640x480)
-- ============================================================================
local Plotter = {}

-- --- STANDARD-EINSTELLUNGEN FÜR DAS GRAFIKFENSTER ---
local VIEW_X1 = 40   -- Pixel-Rand links für Beschriftung
local VIEW_Y1 = 10   -- Pixel-Rand oben
local VIEW_X2 = 310  -- Pixel-Rand rechts
local VIEW_Y2 = 210  -- Pixel-Rand unten (Platz fuer X-Achse)

-- Standard-Wertebereiche der mathematischen Funktion
local X_MIN = -2 * math.pi -- Startwert auf der X-Achse (ca. -6.28)
local X_MAX =  2 * math.pi -- Endwert auf der X-Achse (ca. +6.28)
local Y_MIN = -1.2         -- Minimaler Funktionswert (Y-Achse)
local Y_MAX =  1.2         -- Maximaler Funktionswert (Y-Achse)

-- Standard-Farben (VGA-Indizes)
local COL_ACHSEN = 127 -- Cyan für das Koordinatenkreuz
local COL_RAHMEN = 40  -- Dunkelgrau für die Box
local COL_TEXT   = 255 -- Weiß für Zahlen

-- ============================================================================
-- INTERNE TRANSFORMATION: MATHEMATIK -> PIXEL
-- ============================================================================

-- Wandelt einen mathematischen X-Wert in eine VGA-Pixelspalte um
local function transformX(mathX)
    local prozent = (mathX - X_MIN) / (X_MAX - X_MIN)
    return math.floor(VIEW_X1 + prozent * (VIEW_X2 - VIEW_X1) + 0.5)
end

-- Wandelt einen mathematischen Y-Wert in eine VGA-Pixelzeile um
-- HINWEIS: Bei VGA ist Pixel 0 oben, in der Mathematik ist Y oben positiv!
local function transformY(mathY)
    local prozent = (mathY - Y_MIN) / (Y_MAX - Y_MIN)
    -- Spiegelung an der Y-Achse (1.0 - prozent), damit +Y nach oben gezeichnet wird
    return math.floor(VIEW_Y1 + (1.0 - prozent) * (VIEW_Y2 - VIEW_Y1) + 0.5)
end

-- Erlaubt es dem Lua-Skript, die Achsen-Skalierung dynamisch zu ändern
function Plotter.setzeBereich(xMin, xMax, yMin, yMax)
    X_MIN, X_MAX = xMin, xMax
    Y_MIN, Y_MAX = yMin, yMax
end

-- ============================================================================
-- MATHEMATISCHES GRAFIK-MODUL (plotter.lua) - TEIL 2
-- RECHNEN UND ZEICHNEN DES ACHSENKREUZES, DER TICKS UND TEXTE
-- ============================================================================

-- Zeichnet das Koordinatensystem basierend auf den gesetzten Grenzwerten
function Plotter.zeichneAchsen()
    -- 1. Äußeren Kasten zeichnen (Nutzt Ihre registrierten Ellipsen/Linien-Systeme)
    -- Da vga.drawRect vermutlich existiert, nutzen wir Linien für absolute Sicherheit
    vga.line(VIEW_X1, VIEW_Y1, VIEW_X2, VIEW_Y1, COL_RAHMEN) -- Oben
    vga.line(VIEW_X1, VIEW_Y2, VIEW_X2, VIEW_Y2, COL_RAHMEN) -- Unten
    vga.line(VIEW_X1, VIEW_Y1, VIEW_X1, VIEW_Y2, COL_RAHMEN) -- Links
    vga.line(VIEW_X2, VIEW_Y1, VIEW_X2, VIEW_Y2, COL_RAHMEN) -- Rechts

    -- 2. Position der mathematischen Null-Linien berechnen
    local nullX = transformX(0.0)
    local nullY = transformY(0.0)

    -- 3. X-Achse zeichnen (Horizontale Linie bei Y = 0)
    -- Falls Y=0 außerhalb des Sichtfeldes liegt, wird die Achse an den unteren Rand geklemmt
    if nullY < VIEW_Y1 then nullY = VIEW_Y1 end
    if nullY > VIEW_Y2 then nullY = VIEW_Y2 end
    vga.line(VIEW_X1, nullY, VIEW_X2, nullY, COL_ACHSEN)

    -- 4. Y-Achse zeichnen (Vertikale Linie bei X = 0)
    if nullX < VIEW_X1 then nullX = VIEW_X1 end
    if nullX > VIEW_X2 then nullX = VIEW_X2 end
    vga.line(nullX, VIEW_Y1, nullX, VIEW_Y2, COL_ACHSEN)

    -- 5. SKALIERUNG UND TEILSTRICHE (TICKS) GENERIEREN
    -- A) X-Achsen-Teilstriche (5 Abschnitte von links nach rechts)
    for i = 0, 5 do
        local mathX = X_MIN + (i / 5) * (X_MAX - X_MIN)
        local pixelX = transformX(mathX)
        
        -- Kleinen vertikalen Strich an der Achse ziehen
        vga.line(pixelX, nullY - 4, pixelX, nullY + 4, COL_ACHSEN)
        
        -- Text-Label im 8x8 Textraster darunter platzieren (Umrechnung Pixel -> Spalte)
        local textSpalte = math.floor(pixelX / 4) - 2
        local textZeile = math.floor((nullY + 6) / 6)
        if textZeile > 53 then textZeile = 53 end -- Begrenzung am unteren Rand
        
        local label = string.format("%.1f", mathX)
        vga.text(textSpalte, textZeile, label, 60, COL_HINTERGRUND,15)
    end

    -- B) Y-Achsen-Teilstriche (4 Abschnitte von unten nach oben)
    for i = 0, 4 do
        local mathY = Y_MIN + (i / 4) * (Y_MAX - Y_MIN)
        local pixelY = transformY(mathY)
        
        -- Kleinen horizontalen Strich an der Achse ziehen
        vga.line(nullX - 4, pixelY, nullX + 4, pixelY, COL_ACHSEN)
        
        -- Text-Label links neben der Achse platzieren
        local textSpalte = math.floor((nullX - 8) / 4)
        if textSpalte < 0 then textSpalte = 0 end
        local textZeile = math.floor(pixelY / 6)
        
        local label = string.format("%.1f", mathY)
        vga.text(textSpalte, textZeile, label, 60, COL_HINTERGRUND,15)
    end
end

-- Zeichnet eine mathematische Funktion als durchgehende Kurve
-- Parameter: matheFunktion (z.B. math.sin oder eine eigene Funktion)
-- Parameter: farbe (VGA-Farb-Index für die Kurve)
function Plotter.zeichneFunktion(matheFunktion, farbe)
    local ersterPunkt = true
    local altPixelX, altPixelY = 0, 0

  -- Wir wandern Pixel für Pixel von der linken zur rechten Kastengrenze
  for pixelX = VIEW_X1, VIEW_X2 do
    -- 1. Pixel-Spalte zurückrechnen in den mathematischen X-Wert
    local prozentX = (pixelX - VIEW_X1) / (VIEW_X2 - VIEW_X1)
    local mathX = X_MIN + prozentX * (X_MAX - X_MIN)
    
    -- 2. Den Y-Wert berechnen, indem wir X in die übergebene Funktion stecken
    -- pcall fängt mathematische Fehler ab (z.B. Teilen durch Null)
    local status, mathY = pcall(matheFunktion, mathX)
    
    if status and mathY and type(mathY) == "number" then
      -- 3. Mathematischen Y-Wert in VGA-Pixelzeile umwandeln
      local pixelY = transformY(mathY)
      
      -- Sicherheitsprüfung: Nur zeichnen, wenn wir uns innerhalb des Kastens befinden
      if pixelY >= VIEW_Y1 and pixelY <= VIEW_Y2 then
        if not ersterPunkt then
          -- Den vorherigen Pixel mit dem aktuellen über eine feine Linie verbinden
          vga.line(altPixelX, altPixelY, pixelX, pixelY, farbe)
        else
          ersterPunkt = false
        end
        
        -- Werte für das nächste Linienstück merken
        altPixelX = pixelX
        altPixelY = pixelY
      else
        -- Wenn die Kurve den Kasten verlässt, reißt die Linie ab
        ersterPunkt = true
      end
    else
      -- Bei mathematischen Fehlern (z.B. Division durch 0) Linie unterbrechen
      ersterPunkt = true
    end
  end
end

-- Das komplette Modul an das require()-System übergeben
return Plotter
