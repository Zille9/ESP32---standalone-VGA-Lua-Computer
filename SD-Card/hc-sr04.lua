-- ============================================================================
-- LIVE-TEST FÜR REINES LUA ULTRA-SCHALL MODUL (test_sonar.lua)
-- ============================================================================

local sonar = require("sonar")

-- --- PINS DEFINIEREN (An Ihr Setup anpassen!) ---
local TRIG_PIN = 17  -- Ihr VGA-sicherer Lieblings-Pin
local ECHO_PIN = 18  -- Sicherer Digital-Pin (mit 3.3V Spannungsteiler!)

print("====================================")
print("     ULTRASCHALL TEST-PROGRAMM      ")
print("====================================")
print(" Pins: Trigger=" .. TRIG_PIN .. " | Echo=" .. ECHO_PIN)
print(" Druecke ESC, um den Test zu beenden.")
print("====================================")

local running = true

while running do
    -- 1. Distanz messen
    local cm, err = sonar.getDistance(TRIG_PIN, ECHO_PIN)
    
    -- 2. Ergebnis auf der VGA-Konsole ausgeben
    if not err then
        -- string.format säubert die Ausgabe, "\r" springt an den Zeilenanfang
        -- Dadurch überschreibt sich die Zeile live, ohne nach unten zu scrollen!
        print(string.format(" Entfernung: %.1f cm      \r", cm))
    else
        print(string.format(" Fehler: %s               \r", err))
    end
    
    -- 3. Tastatur abfragen (ESC prüfen)
    local taste = inkey()
    if taste == 27 then
        running = false
    end
    
    -- 4. Dem OS und dem Teensy kurze Atempause gönnen
    delay(100) -- Alle 100ms neu messen (10-mal pro Sekunde)
    
end

-- Sauberer Ausstieg
print("\nTest beendet. Zurueck zum OS...")
collectgarbage("collect") -- RAM1 sofort wieder freischaufeln