-- ===================================================
-- ESP32 LUA SYSTEM INIT SKRIPT
-- ===================================================

-- 1. Globales Farbschema beim Booten setzen (z.B. Weiss auf Dunkelblau)
vga.color(255, 1)
vga.cls()

-- 2. Einen schicken Willkommens-Bildschirm zaubern
vga.rect(10, 10, 220, 40, 60) -- Blauer Rahmen oben
vga.text(7, 2, "*** LUA COMPUTER-SYSTEM ***", 31, 1,2)
vga.text(4, 4, "ESP 32 inside - PSRAM & VGA aktiv", 52, 1,2)
vga.pos(0,9)

-- ============================================================================
-- REQUIRE-ERSATZ
-- ============================================================================
local originales_require = require

require = function(modulName)
    -- 1. RAM-Cache pruefen: Wenn das Modul schon geladen ist, sofort zurueckgeben
    if package.loaded[modulName] then
        return package.loaded[modulName]
    end

    -- Punkte in Schraegstriche umwandeln (z.B. fuer verschachtelte Ordner)
    local bereinigterName = string.gsub(modulName, "%.", "/")
    
    -- Das sind die Pfade, die der Reihe nach auf der SD-Karte geprüft werden
    local suchMuster = {
        "lua/lib/?.lua",
        "lua/?.lua",
        "?.lua"
    }

    -- Alle Pfade durchlaufen
    for _, muster in ipairs(suchMuster) do
        local pfad = string.gsub(muster, "%?", bereinigterName)
        
        -- C++ Ladebefehl aufrufen (Liefert: chunk, err)
        local chunk, err = sys.load(pfad) 
        
        -- WICHTIG: Wir pruefen explizit, ob ein gueltiger Code-Chunk zurueckkam!
        if chunk ~= nil then
            -- Datei erfolgreich geladen und im PSRAM kompiliert! Jetzt ausfuehren.
            local status, result = pcall(chunk)
            if not status then
                error("\n\rLaufzeitfehler beim Ausfuehren von '" .. pfad .. "': " .. tostring(result))
            end
            
            -- Das ausgefuehrte Modul (z.B. die ClockWidget-Tabelle) im RAM cachen
            package.loaded[modulName] = result or true
            return package.loaded[modulName]
        else
            -- Wenn chunk nil ist, pruefen wir, ob es ein Syntaxfehler in deiner clock.lua war
            if err and err ~= "Datei existiert nicht!" then
                error("\n\rSyntaxfehler in Modul '" .. pfad .. "': " .. tostring(err))
            end
        end
    end

    -- Fallback fuer interne C-Module (falls vorhanden)
    local status, result = pcall(originales_require, modulName)
    if status then 
        return result 
    end

    -- Wenn die Datei beim Start nicht existiert
    error("\n\rModul '" .. modulName .. "' wurde auf der SD-Karte nicht gefunden!")
end
