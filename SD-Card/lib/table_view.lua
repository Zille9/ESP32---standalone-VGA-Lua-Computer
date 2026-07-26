-- ============================================================================
-- INTERAKTIVES TABELLEN-MODUL (table_view.lua) - TEIL 1
-- COMFORT-DATENRASTER FÜR TEXTBASIERTE AUSGABEN
-- ============================================================================
local TableView = {}

-- --- STANDARD-EINSTELLUNGEN FÜR DAS TABELLENFENSTER ---
local MAX_ZEILEN = 20  -- Wie viele Datenzeilen passen gleichzeitig auf den Schirm
local START_Y    = 2   -- Startzeile im Textraster für die Tabelle

-- Farben (VGA-Indizes)
local COL_HEADER_TXT = 240 -- Orange für die Spaltenüberschriften
local COL_HEADER_BG  = 3   -- Blau als Balken hinter dem Header
local COL_GRID       = 127 -- Cyan für Trennlinien
local COL_DATA       = 255 -- Weiß für normalen Text
local COL_BG         = 0   -- Schwarz für den Hintergrund

-- Hilfsfunktion: Berechnet die maximale Textlänge in einer Spalte,
-- damit die Tabelle später automatisch die perfekte Breite hat.
local function berechneSpaltenBreiten(headers, daten)
    local breiten = {}
    
    -- 1. Basis-Breite anhand der Header-Namen ermitteln
    for i, h in ipairs(headers) do
        breiten[i] = string.len(h)
    end
    
    -- 2. Durch alle Datenzeilen gehen und die Spaltenbreite anpassen,
    -- falls ein Daten-Eintrag länger ist als die Überschrift.
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
            wert = string.sub(wert, 1, breite - 2) .. "~" -- Kürzen mit Tilde, falls zu lang
        end
        
        -- Text mit Leerzeichen auffüllen, um Spaltenbreite auszufüllen
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
    
    -- 3. Leere Zeilen auffüllen, falls die Tabelle kürzer als das Fenster ist
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
-- INTERAKTIVE TASTENSTEUERUNG UND SEITENWEISES BLÄTTERN (ASCII)
-- ============================================================================

-- Öffnet die Tabelle im interaktiven Vollbildmodus mit Scroll-Unterstützung
-- Parameter: titel (String), headers (Table), daten (Table von Zeilen)
function TableView.zeigeInteraktiv(titel, headers, daten)
    -- vga.cls()
    
    -- Große Titelzeile ganz oben platzieren
    vga.text(2, 1, "=== " .. tostring(titel) .. " ===", COL_HEADER_TXT, COL_BG)
    -- vga.text(2, 2, "Pfeiltasten: Blaettern | ESC: Zurueck zum Terminal", COL_GRID, COL_BG)
    
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
-- Gibt bei ENTER den gewählten Index zurück, bei ESC nil
function TableView.zeigeSelektor(titel, headers, daten, initialerIndex)
    --vga.cls()
    
    local spaltenBreiten = berechneSpaltenBreiten(headers, daten)
    local gesamtBreite = 0
    for _, b in ipairs(spaltenBreiten) do gesamtBreite = gesamtBreite + b end
    
    -- Titel und Steuerungshinweise zeichnen
    vga.text(2, 1, "=== " .. tostring(titel) .. " ===", COL_HEADER_TXT, COL_BG)
    
    local cursorZeile = initialerIndex or 1
    if cursorZeile < 1 then cursorZeile = 1 end
    if cursorZeile > #daten then cursorZeile = #daten end
    
    local startIdx = 1
    if cursorZeile > MAX_ZEILEN then
        startIdx = cursorZeile - math.floor(MAX_ZEILEN / 2) -- Mittig platzieren
        if startIdx > #daten - MAX_ZEILEN + 1 then
            startIdx = #daten - MAX_ZEILEN + 1
        end
        if startIdx < 1 then startIdx = 1 end
    end

    local aktiv = true

    while aktiv do
        -- 1. Tabelle im aktuellen Ausschnitt zeichnen
        TableView.zeichneTabelle(headers, daten, startIdx)
        
        -- 2. Den Auswahlbalken (Highlight) über die aktuelle Zeile zeichnen
        -- Wir berechnen, wo die ausgewählte Zeile visuell auf dem Bildschirm liegt
        local visuelleZeile = cursorZeile - startIdx + 1
        local absoluteY = START_Y + 1 + visuelleZeile
        
        -- Die Zeile noch einmal mit invertierten Farben (oder Highlight-Farbe) zeichnen
        if cursorZeile <= #daten then
            zeichneZeile(absoluteY, spaltenBreiten, daten[cursorZeile], COL_BG, COL_HEADER_TXT)
        end
        
        -- Statuszeile unten aktualisieren
        local statusText = string.format("Auswahl: %d / %d                      ", cursorZeile, #daten)
        vga.text(1, START_Y + MAX_ZEILEN + 3, statusText, COL_HEADER_TXT, COL_HEADER_BG)
        
        -- 3. Tastatur abfragen (Reine ASCII-Werte)
        local taste = 0
        taste = waitkey(false)

        if taste == 27 then -- ESC: Abbrechen
            vga.cls()
            return nil
        
        elseif taste == 218 then -- PFEIL HOCH: Balken nach oben bewegen
            if cursorZeile > 1 then
                cursorZeile = cursorZeile - 1
                -- Wenn der Cursor oben aus dem Bildschirm rutscht, scrollen
                if cursorZeile < startIdx then
                    startIdx = startIdx - 1
                end
            end
                        
        elseif taste == 217 then -- PFEIL RUNTER: Balken nach unten bewegen
            if cursorZeile < #daten then
                cursorZeile = cursorZeile + 1
                -- Wenn der Cursor unten aus dem Bildschirm rutscht, scrollen
                if cursorZeile >= startIdx + MAX_ZEILEN then
                    startIdx = startIdx + 1
                end
            end
            
        elseif taste == 211 then --Page UP
            
            if cursorZeile > 1 then
               cursorZeile = cursorZeile - MAX_ZEILEN
               startIdx = startIdx - MAX_ZEILEN

               if cursorZeile < 1 then 
                  cursorZeile = 1 
               end
               if startIdx < 1 then 
                  startIdx = 1 
               end
            end   
            
        elseif taste == 210 then -- HOME
               cursorZeile = 1
               startIdx = 1               
            
        elseif taste == 213 then -- END
               cursorZeile = #daten
               startIdx = #daten - MAX_ZEILEN +1
               if startIdx < 1 then startIdx = 1 end
            
        elseif taste == 214 then -- Page DOWN
            if cursorZeile < #daten then
               cursorZeile = cursorZeile + MAX_ZEILEN
               startIdx = startIdx + MAX_ZEILEN

               if cursorZeile > #daten then cursorZeile = #daten end
               if startIdx > #daten - MAX_ZEILEN + 1 then
                  startIdx = #daten - MAX_ZEILEN +1
               end
               if startIdx < 1 then startIdx = 1 end
            end                 
            

        elseif taste == 212 then -- DEL
            return cursorZeile, taste

        elseif taste == 13 or taste > 31 and taste < 206 then
            return cursorZeile, taste

        end -- if taste 
        
        delay(16)
    end -- while

    return nil, 0 -- Absicherung

end -- function

return TableView

