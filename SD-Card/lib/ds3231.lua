-- Hilfsfunktion: Konvertiert ein BCD-Byte der externen RTC in eine normale Lua-Zahl
local function bcdToDec(val)
    return math.floor(val / 16) * 10 + (val % 16)
end

-- HAUPTFUNKTION FÜR IHR OS: Liest die externe Uhr und gibt einen fertigen String zurück
function getExterneUhrzeit()
    -- 1. Der RTC sagen, dass wir bei Register 0x00 (Sekunden) starten wollen
    -- (Wir nutzen hier direkt die Funktionen aus Ihrem neuen I2C-Modul)
    i2c_start()
    if not i2c_write_byte(0x68 * 2) then i2c_stop(); return "NO RTC" end -- 0x68 = DS3231 [1]
    if not i2c_write_byte(0x00)     then i2c_stop(); return "ERR REG" end
    
    -- 2. Sekunden, Minuten und Stunden in einem Rutsch als Tabelle anfordern!
    local rohDaten = i2c.requestFrom(0x68, 3)
    
    if not rohDaten or #rohDaten < 3 then
        return "ERR READ"
    end
    
    -- 3. BCD-Bits in echte, lesbare Dezimalzahlen umrechnen
    local sekunden = bcdToDec(rohDaten[1])
    local minuten  = bcdToDec(rohDaten[2])
    
    -- Stunden-Register maskieren (Bit 6 entscheidet bei der DS3231 über 12h/24h Modus)
    local stunden  = bcdToDec(rohDaten[3] % 64) 
    
    -- 4. Als wunderschön formatierten Text für die Titelzeile zurückgeben
    return string.format("%02d:%02d:%02d", stunden, minuten, sekunden)
end
