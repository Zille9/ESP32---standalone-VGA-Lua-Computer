-- ============================================================================
-- INTERAKTIVES TABELLEN-MODUL (table_view.lua) - TEIL 1
-- COMFORT-DATENRASTER FÜR TEXTBASIERTE AUSGABEN
-- ============================================================================
local TableView = {}

-- --- STANDARD-EINSTELLUNGEN FUER DAS TABELLENFENSTER ---
local MAX_ZEILEN = 22  -- Wie viele Datenzeilen passen gleichzeitig auf den Schirm
local START_Y    = 2   -- Startzeile im Textraster für die Tabelle

-- Farben (VGA-Indizes)
local COL_HEADER_TXT = 240 -- Orange fuer die Spaltenüberschriften
local COL_HEADER_BG  = 3   -- Blau als Balken hinter dem Header
local COL_GRID       = 127 -- Cyan fuer Trennlinien
local COL_DATA,COL_BG = vga.gcolor()

-- Hilfsfunktion: Berechnet die maximale Textlänge in einer Spalte,
-- damit die Tabelle später automatisch die perfekte Breite hat.
local function berechneSpaltenBreiten(headers, daten)
    local breiten = {}
    
    -- 1. Basis-Breite anhand der Header-Namen ermitteln
    for i, h in ipairs(headers) do
        breiten[i] = string.len(h)
    end
    
    -- 2. Durch alle Datenzeilen gehen und die Spaltenbreite anpassen,
    -- falls ein Daten-Eintrag laenger ist als die Ueberschrift.
    for _, zeile in ipairs(daten) do
        for i, wert in ipairs(zeile) do
            local laenge = string.len(tostring(wert or ""))
            if laenge > (breiten[i] or 0) then
                breiten[i] = laenge
            end
        end
    end
    
    -- 3. Ein wenig Sicherheits-Abstand (Padding) zwischen den Spalten hinzufügen
    for i = 1, #breiten do
        breiten[i] = breiten[i] + 2
    end
    
    return breiten
end

-- ============================================================================
-- INTERAKTIVES TABELLEN-MODUL (table_view.lua) - TEIL 2
-- RECHNEN UND ZEICHNEN DES GRIDS UND DER DATENZEILEN
-- ============================================================================

-- Interne Hilfsfunktion: Zeichnet eine Zeile mit vertikalen Trennstrichen (Grid)
local function zeichneZeile(y, spaltenBreiten, datenZeile, textFarbe, bgFarbe)
    local aktuellesX = 1
    
    for i, breite in ipairs(spaltenBreiten) do
        -- Wert holen und auf die exakte Spaltenbreite formatieren (linksbündig)
        local wert = tostring(datenZeile[i] or "")
        if string.len(wert) > breite - 1 then
            wert = string.sub(wert, 1, breite - 2) .. "~" -- Kuerzen mit Tilde, falls zu lang
        end
        
        -- Text mit Leerzeichen auffuellen, um Spaltenbreite auszufuellen
        local formatText = wert .. string.rep(" ", breite - string.len(wert))
        
        -- Text auf den VGA-Schirm drucken 
        vga.text(aktuellesX, y, formatText, textFarbe, bgFarbe)
        
        -- Trennstrich (Grid) hinter der Spalte zeichnen
        aktuellesX = aktuellesX + breite
        if i < #spaltenBreiten then
            vga.text(aktuellesX - 1, y, "|", COL_GRID, bgFarbe)
        end
    end
end

-- Hauptfunktion zum Rendern einer statischen Tabelle
-- Parameter: headers (Tabelle von Strings), daten (Tabelle von Tabellen), startIndex (Scroll-Offset)
function TableView.zeichneTabelle(headers, daten, startVerzeichnisIndex)
    local spaltenBreiten = berechneSpaltenBreiten(headers, daten)
    local startIdx = startVerzeichnisIndex or 1
    
    -- 1. Kopfzeile (Header) mit Hintergrundfarbe zeichnen
    zeichneZeile(START_Y, spaltenBreiten, headers, COL_HEADER_TXT, COL_HEADER_BG)
    
    -- Eine Trennlinie unter dem Header ziehen
    local gesamtBreite = 0
    for _, b in ipairs(spaltenBreiten) do gesamtBreite = gesamtBreite + b end
     vga.text(1, START_Y + 1, string.rep("-", gesamtBreite - 1), COL_GRID, COL_BG)
    
    -- 2. Datenzeilen im sichtbaren Bereich ausgeben
    local gedruckteZeilen = 0
    for i = startIdx, #daten do
        if gedruckteZeilen >= MAX_ZEILEN then break end
        
        local aktuelleY = START_Y + 2 + gedruckteZeilen
        zeichneZeile(aktuelleY, spaltenBreiten, daten[i], COL_DATA, COL_BG)
        
        gedruckteZeilen = gedruckteZeilen + 1
    end
    
    -- 3. Leere Zeilen auffuellen, falls die Tabelle kuerzer als das Fenster ist
    if gedruckteZeilen < MAX_ZEILEN then
        for y = (START_Y + 2 + gedruckteZeilen), (START_Y + 1 + MAX_ZEILEN) do
            vga.text(1, y, string.rep(" ", gesamtBreite - 1), COL_DATA, COL_BG)
        end
    end
    
    -- Statuszeile zurückgeben, um dem User anzuzeigen, wo er scrollt
    return startIdx, math.min(startIdx + gedruckteZeilen - 1, #daten), #daten
end

-- ============================================================================
-- INTERAKTIVES TABELLEN-MODUL (table_view.lua) - TEIL 3 (FINALE)
-- INTERAKTIVE TASTENSTEUERUNG UND SEITENWEISES BLAETTERN (ASCII)
-- ============================================================================

-- Oeffnet die Tabelle im interaktiven Vollbildmodus mit Scroll-Unterstuetzung
-- Parameter: titel (String), headers (Table), daten (Table von Zeilen)
function TableView.zeigeInteraktiv(titel, headers, daten)
    -- vga.cls()
    
    -- Grosse Titelzeile ganz oben platzieren
    vga.text(2, 1, "=== " .. tostring(titel) .. " ===", COL_HEADER_TXT, COL_BG)
    
    
    local startIdx = 1
    local aktiv = true
    
    -- Haupt-Anzeigeschleife
    while aktiv do
        -- Tabelle im aktuellen Ausschnitt zeichnen und die Zeilen-Grenzen holen
        local von, bis, gesamt = TableView.zeichneTabelle(headers, daten, startIdx)
        
        -- Komfortable Seitennummerierung ganz unten einblenden
        local statusText = string.format(" Zeile %d bis %d von %d (ESC fuer Ende) ", von, bis, gesamt)
        vga.text(2, START_Y + MAX_ZEILEN + 3, statusText, COL_HEADER_TXT, COL_HEADER_BG)
        
        -- Warten auf Tastendruck (Nutzt Ihre blockierende ASCII-Tastaturfunktion)
        local taste = 0
        taste = waitkey(false)
         
        if taste == 27 then -- ESC-Taste
            aktiv = false
                       
        elseif taste == 218 then -- PFEIL TASTE HOCH: Eine Seite zurückblättern
            startIdx = startIdx - MAX_ZEILEN
            if startIdx < 1 then startIdx = 1 end
        elseif taste == 217 then -- PFEIL TASTE RUNTER: Eine Seite weiterblättern
            if startIdx + MAX_ZEILEN <= gesamt then
                startIdx = startIdx + MAX_ZEILEN
            end
        end
        
        delay(10) -- System entlasten
    end
    
    -- Nach dem Beenden Bildschirm loeschen
    vga.cls()
end

-- ============================================================================
-- ERWEITERUNG FÜR APP-STARTER: INTERAKTIVER ZEILENSELEKTOR
-- ============================================================================

-- Zeigt die Tabelle mit einem beweglichen Auswahlbalken
-- Gibt bei ENTER den gewaehlten Index zurueck, bei ESC nil
local FONT_W = 6  -- Breite eines Zeichens in Pixeln (ggf. auf 5, 6 oder 8 ändern)
local FONT_H = 8  -- Hoehe eines Zeichens in Pixeln (ggf. auf 8, 12 oder 16 ändern)

function TableView.zeigeSelektor(titel, headers, daten, initialerIndex)
    local spaltenBreiten = berechneSpaltenBreiten(headers, daten)
    local gesamtBreite = 0
    for _, b in ipairs(spaltenBreiten) do gesamtBreite = gesamtBreite + b end
    
    vga.text(2, 1, "=== " .. tostring(titel) .. " ===", COL_HEADER_TXT, COL_BG)
    
    local cursorZeile = initialerIndex or 1
    if cursorZeile < 1 then cursorZeile = 1 end
    if cursorZeile > #daten then cursorZeile = #daten end
    
    local startIdx = 1
    if cursorZeile > MAX_ZEILEN then
        startIdx = cursorZeile - math.floor(MAX_ZEILEN / 2)
        if startIdx > #daten - MAX_ZEILEN + 1 then startIdx = #daten - MAX_ZEILEN + 1 end
        if startIdx < 1 then startIdx = 1 end
    end

    -- HILFSFUNKTION: Rechnet Text-Koordinaten in Pixel-Koordinaten um und führt vga.swap aus
    local function invertiereTextZeile(zeilenIndex)
        local visZeile = zeilenIndex - startIdx  + 2
        -- KORREKTUR: Datenzeilen beginnen bei START_Y + 2 (da START_Y+1 die Trennlinie ist)
        local absoluteY = START_Y + 2 + (visZeile - 1)
        
        -- Umrechnung von 1-basierten Text-Koordinaten in Pixel (0-basiert)
        local pixelX = 1 * FONT_W
        local pixelY = (absoluteY - 1) * FONT_H
        local pixelW = (gesamtBreite - 1) * FONT_W
        local pixelH = (1 * FONT_H)-1  -- Genau 1 Zeile hoch
        
        vga.swap(pixelX, pixelY, pixelW, pixelH)
    end

    local mussNeuZeichnen = true
    local aktiv = true

    while aktiv do
        if mussNeuZeichnen then
            TableView.zeichneTabelle(headers, daten, startIdx)
            -- Initialen Balken per Pixel-Inversion setzen
            invertiereTextZeile(cursorZeile)
            mussNeuZeichnen = false
        end
        
        local statusText = string.format("Auswahl: %d / %d                      ", cursorZeile, #daten)
        vga.text(1, START_Y + MAX_ZEILEN + 3, statusText, COL_HEADER_TXT, COL_HEADER_BG)
        
        local taste = waitkey(false)
        local alteZeile = cursorZeile
        local altesStartIdx = startIdx

        if taste == 27 then -- ESC
            vga.cls()
            return nil
        
        elseif taste == 218 then -- PFEIL HOCH
            if cursorZeile > 1 then
                cursorZeile = cursorZeile - 1
                if cursorZeile < startIdx then startIdx = startIdx - 1 end
            end
                        
        elseif taste == 217 then -- PFEIL RUNTER
            if cursorZeile < #daten then
                cursorZeile = cursorZeile + 1
                if cursorZeile >= startIdx + MAX_ZEILEN then startIdx = startIdx + 1 end
            end
            
        elseif taste == 211 then -- Page UP
            if cursorZeile > 1 then
                cursorZeile = cursorZeile - MAX_ZEILEN + 1
                startIdx = startIdx - MAX_ZEILEN + 1
                if cursorZeile < 1 then cursorZeile = 1 end
                if startIdx < 1 then startIdx = 1 end
            end   
            
        elseif taste == 210 then -- HOME
            cursorZeile = 1
            startIdx = 1               
            
        elseif taste == 213 then -- END
            cursorZeile = #daten
            startIdx = #daten - MAX_ZEILEN + 1
            if startIdx < 1 then startIdx = 1 end
            
        elseif taste == 214 then -- Page DOWN
            if cursorZeile < #daten then
                cursorZeile = cursorZeile + MAX_ZEILEN - 1
                startIdx = startIdx + MAX_ZEILEN - 1
                if cursorZeile > #daten then cursorZeile = #daten end
                if startIdx > #daten - MAX_ZEILEN + 1 then startIdx = #daten - MAX_ZEILEN + 1 end
                if startIdx < 1 then startIdx = 1 end
            end                 

        elseif taste == 212 or taste == 13 or (taste > 31 and taste < 206) then -- DEL, ENTER etc.
            return cursorZeile, taste
        end
        
        -- --- BLITZSCHNELLE REFRESH-LOGIK MIT PIXEL-INVERSION ---
        if startIdx ~= altesStartIdx then
            mussNeuZeichnen = true
        else
            if cursorZeile ~= alteZeile then
                -- Alten Balken pixelgenau löschen
                invertiereTextZeile(alteZeile)
                -- Neuen Balken pixelgenau zeichnen
                invertiereTextZeile(cursorZeile)
            end
        end
        
        delay(16)
    end

    return nil, 0
end

return TableView
