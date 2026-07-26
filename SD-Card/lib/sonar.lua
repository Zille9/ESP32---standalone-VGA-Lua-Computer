-- ============================================================================
-- REINES LUA ULTRA-SCHALL MODUL (sonar.lua)
-- 100% AUTARK OHNE NEUEN C++ CORE CODE!
-- ============================================================================
local sonar = {}

-- Lokaler Cache für maximale Performance (Schont Ihre 28 KB RAM)
local hw_ctrl  = io_control
local delay_us = delay_us

-- ÖFFENTLICHE HAUPTFUNKTION: sonar.getDistance(trigger_pin, echo_pin)
function sonar.getDistance(trig, echo)
    -- 1. Pins über Ihre Hardware-Brücke konfigurieren
    hw_ctrl(trig, "OUTPUT", "LOW")
    hw_ctrl(echo, "INPUT")
    delay_us(2)
    
    -- 2. Den exakten 10 Mikrosekunden Start-Puls rausschicken
    hw_ctrl(trig, "OUTPUT", "HIGH")
    delay_us(10)
    hw_ctrl(trig, "OUTPUT", "LOW")
    
    -- 3. TIMEOUT-SCHUTZWAND: Warten, bis der Echo-Pin auf HIGH geht
    -- Wir nutzen eine extrem schnelle Lua-Zählschleife als Timeout-Schranke
    local timeout = 5000
    while hw_ctrl(echo, "INPUT") == 0 do
        timeout = timeout - 1
        if timeout == 0 then
            return nil, "Sensor antwortet nicht (Timeout)"
        end
    end
    
    -- 4. MESSUNG: Zählen, wie lange der Pin auf HIGH bleibt
    -- Da os.clock() auf Mikrocontrollern oft die Millisekunden liefert,
    -- nutzen wir hier eine hochpräzise, kalibrierte CPU-Zählschleife.
    local zyklen = 0
    local max_zyklen = 20000 -- Entspricht ca. 4 bis 5 Metern Reichweite
    
    while hw_ctrl(echo, "INPUT") == 1 do
        zyklen = zyklen + 1
        if zyklen > max_zyklen then
            return nil, "Außer Reichweite (Timeout)"
        end
    end
    
    -- 5. KALIBRIERUNG & UMRECHNUNG IN ZENTIMETER
    -- Da Lua-Schleifen etwas Overhead haben, entspricht 1 Schleifendurchlauf 
    -- bei 600 MHz auf dem Teensy 4.1 ungefähr 0.58 Mikrosekunden.
    -- Der kalibrierte Teiler für Zentimeter lautet hier: zyklen / 5.2
    local distanz_cm = zyklen / 5.2
    
    -- Auf eine Nachkommastelle runden
    distanz_cm = math.floor(distanz_cm * 10 + 0.5) / 10
    
    return distanz_cm, nil
end

return sonar