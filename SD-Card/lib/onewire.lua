local ow = {}

-- Standard-Pin für 1-Wire beim Teensy 4.1 (Frei wählbar)
local DQ = 17 

-- Lokaler Cache für maximale Geschwindigkeit
local hw_ctrl  = io_control
local delay_us = delay_us

-- Bus freigeben (High über den externen 4.7k Ohm Pull-Up Widerstand)
local function pin_high() hw_ctrl(DQ, "INPUT_PULLUP") end
-- Bus aktiv auf Masse (Low) ziehen
local function pin_low()  hw_ctrl(DQ, "OUTPUT", "LOW") end

-- ÖFFENTLICH: Initialisierung des Pins
function ow.init(pin)
    if pin then DQ = pin end
    pin_high()
end

-- 1-Wire Reset-Puls: Sagt allen Geräten am Bus "Achtung, es geht los!"
function ow.reset()
    local presence = 1
    pin_low()
    delay_us(480) -- 480µs Low puls
    pin_high()
    delay_us(70)  -- Warten, bis der Sensor antwortet
    
    -- Sensor zieht die Leitung als Antwort auf LOW
    presence = hw_ctrl(DQ, "INPUT_PULLUP")
    delay_us(410) -- Den Rest des 480µs-Fensters abwarten
    
    return presence == 0 -- true = Sensor hat sich erfolgreich gemeldet!
end

-- Schreibt ein einzelnes Bit auf den Bus
local function ow_write_bit(bit)
    if bit == 1 then
        pin_low()
        delay_us(10) -- Kurzer Low-Impuls für eine "1"
        pin_high()
        delay_us(55)
    else
        pin_low()
        delay_us(65) -- Langer Low-Impuls für eine "0"
        pin_high()
        delay_us(5)
    end
end

-- Liest ein einzelnes Bit vom Bus ein
local function ow_read_bit()
    pin_low()
    delay_us(3) -- Bus kurz triggern
    pin_high()  -- Freigeben, damit der Sensor antworten kann
    delay_us(10) -- Kurz vor dem Ende des 15µs-Fensters messen
    
    local bit = hw_ctrl(DQ, "INPUT_PULLUP") or 0
    delay_us(50) -- Rest des Slots abwarten
    return bit
end

-- Schreibt ein ganzes Byte (8 Bit) auf den Bus (LSB zuerst)
function ow.write_byte(byte)
    for i = 0, 7 do
        local bit = math.floor(byte / (2^i)) % 2
        ow_write_bit(bit)
    end
end

-- Liest ein ganzes Byte (8 Bit) vom Bus ein
function ow.read_byte()
    local byte = 0
    for i = 0, 7 do
        if ow_read_bit() == 1 then
            byte = byte + (2^i)
        end
    end
    return byte
end

-- ============================================================================
-- ANWENDUNG: Temperatur von einem DS18B20 Sensor auslesen
-- ============================================================================
function ow.readTemperature()
    if not ow.reset() then return nil, "Kein Sensor gefunden" end
    
    ow.write_byte(0xCC) -- Skip ROM Befehl (gilt für alle Sensoren am Bus)
    ow.write_byte(0x44) -- Convert T Befehl (Messung starten)
    
    -- Der DS18B20 braucht Zeit zum Messen. Wir warten kurz im normalen OS-Takt
    delay(750) 
    
    if not ow.reset() then return nil, "Sensor verloren" end
    ow.write_byte(0xCC) -- Skip ROM
    ow.write_byte(0xBE) -- Read Scratchpad (Speicher auslesen)
    
    -- Wir lesen die ersten beiden Bytes (Temperaturdaten)
    local low_byte  = ow.read_byte()
    local high_byte = ow.read_byte()
    
    -- Kombinieren der beiden Bytes zu einer 16-Bit-Zahl
    local raw_temp = (high_byte * 256) + low_byte
    
    -- Vorzeichenprüfung (Falls es unter 0°C kalt ist)
    if raw_temp > 32767 then
        raw_temp = raw_temp - 65536
    end
    
    -- Der DS18B20 löst standardmäßig in 0.0625°C Schritten auf (raw / 16)
    local celsius = raw_temp / 16
    return celsius
end

return ow
