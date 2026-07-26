-- ============================================================================
-- 1. HIER IST DIE FUNKTION: Der CSV-Parser für den Teensy
-- ============================================================================
local function parseCSVWithHeader(zeilen, separator)
    separator = separator or ";"
    local datensaetze = {}
    local header = nil
    
    for _, zeile in ipairs(zeilen) do
        -- Unsichtbare Windows-Zeichen (\r) entfernen und trimmen
        zeile = string.gsub(zeile, "\r", "")
        zeile = string.match(zeile, "^%s*(.-)%s*$")
        
        -- Nur verarbeiten, wenn die Zeile nicht leer ist und kein Kommentar ist
        if zeile ~= "" and not string.match(zeile, "^#") then
            local werte = {}
            
            -- Zeile anhand des Trennzeichens zerlegen
            local pattern = "([^" .. "%" .. separator .. "]+)"
            for wert in string.gmatch(zeile, pattern) do
                local sauber = string.match(wert, "^%s*(.-)%s*$") or wert
                local zahl = tonumber(sauber)
                table.insert(werte, zahl or sauber)
            end
            
            -- Datensätze verknüpfen
            if #werte > 0 then
                if not header then
                    -- Erste Zeile wird als Spaltennamen (Header) gespeichert
                    header = werte
                else
                    -- Folgende Zeilen werden mit den Spaltennamen verknüpft
                    local datensatz = {}
                    for spaltenIndex, spaltenName in ipairs(header) do
                        datensatz[spaltenName] = werte[spaltenIndex]
                    end
                    table.insert(datensaetze, datensatz)
                end
            end
        end
    end
    
    return datensaetze
end

-- ============================================================================
-- 2. HAUPTPROGRAMM: Datei laden, parsen und auf VGA anzeigen
-- ============================================================================

local zeilen = sd.readline("log.csv")

if zeilen then
    -- 2. Die ganze Datei auf einmal parsen
    local logDaten = parseCSVWithHeader(zeilen, ";")
    
    if #logDaten > 0 then
        vga.cls(1) -- Bildschirm einmalig löschen
        vga.color(255, 1) -- Ihre VGA-Farbe

        vga.pos(20, 2)
        vga.print("--- ALLE LOGDATEN ---")

        -- Start-Y-Position für den ersten Datensatz
        local yPos = 5 
        -- Zeilenabstand in Pixeln (passen Sie dies an Ihre Schriftgröße an)
        local zeilenAbstand = 1 

        -- 3. HIER ist die Schleife: Wir gehen alle Datensätze von 1 bis zum Ende durch
        for i = 1, #logDaten do
            local aktuell = logDaten[i]

            -- Werte für diese Zeile auslesen
            local zeit   = aktuell.Zeitstempel
            local temp   = aktuell.Temperatur
            local feucht = aktuell.Luftfeuchtigkeit

            -- Textzeile für VGA zusammenbauen
            local ausgabeText = string.format("[%s] T: %.1f C | H: %s %%", zeit, temp, feucht)

            -- Position für diesen Eintrag setzen und drucken
            vga.pos(20, yPos)
            vga.print(ausgabeText)
            print("")
            -- Y-Position für den nächsten Eintrag nach unten verschieben
            yPos = yPos + zeilenAbstand
            
            -- Sicherheits-Stopp: Wenn der Bildschirm voll ist, Schleife abbrechen
            if yPos > 440 then 
                vga.pos(20, yPos)
                vga.print("... weitere Daten auf SD-Karte ...")
                if inkey()==27 then
                   break 
                end
            end
        end
        
    else
        vga.cls()
        vga.pos(20, 20)
        vga.print("Fehler: Keine Daten in CSV gefunden!")
    end
else
    vga.cls()
    vga.pos(20, 20)
    vga.print("Fehler: log.csv konnte nicht geladen werden!")
end