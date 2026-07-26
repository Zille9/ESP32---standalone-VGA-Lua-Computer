-- ============================================================================
-- RETRO-OS HARDWARE-MONITOR (Nutzt hocheffizientes require-Caching)
-- ============================================================================

-- 1. Module speicherschonend laden (wird nur beim 1. Mal von SD gelesen!)
local i2c = require("i2c")
local ow  = require("onewire")

-- 2. Hardware initialisieren
i2c.init(18, 19) -- SDA=18, SCL=19
ow.init(17)        -- DQ=17

-- Hilfsfunktion: BCD-Dekodierung für die I2C-Uhr
local function bcdToDec(val)
    return math.floor(val / 16) * 10 + (val % 16)
end

-- ============================================================================
-- DIE LIVE-ABFRAGE FÜR DIE TITELZEILE
-- ============================================================================
function updateSystemBar()
    -- --- A) Uhrzeit über I2C holen ---
    i2c_start() -- (Nutzt die internen Start/Schreib-Befehle Ihres I2C-Moduls)
    i2c_write_byte(0x68 * 2) 
    i2c_write_byte(0x00)     
    
    local zeitDaten = i2c.requestFrom(0x68, 3)
    local uhrzeitText = "00:00:00"
    
    if zeitDaten and #zeitDaten >= 3 then
        local sek = bcdToDec(zeitDaten[1])
        local min = bcdToDec(zeitDaten[2])
        local std = bcdToDec(zeitDaten[3] % 64)
        uhrzeitText = string.format("%02d:%02d:%02d", std, min, sek)
    end
    
    -- --- B) Temperatur über 1-Wire holen ---
    local temp, err = ow.readTemperature()
    local tempText = "--.- *C"
    if temp then
        tempText = string.format("%.1f *C", temp)
    end
 
    local Zeit = string.format("[ %s ]  |  [ %s ]", uhrzeitText, tempText)
    print(Zeit)
end

collectgarbage("collect")