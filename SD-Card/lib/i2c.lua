local i2c = {}

-- Standard-Pins beim Teensy 4.1 für dieses Software-I2C
local SDA = 18
local SCL = 19

-- Hilfsfunktionen, die direkt Ihre C++ Funktion aufrufen
local function sda_high() io_control(SDA, "INPUT_PULLUP") end
local function sda_low()  io_control(SDA, "OUTPUT", "LOW") end
local function scl_high() io_control(SCL, "INPUT_PULLUP") end
local function scl_low()  io_control(SCL, "OUTPUT", "LOW") end

-- ÖFFENTLICH: Initialisierung des Bus
function i2c.init(sda_pin, scl_pin)
    if sda_pin then SDA = sda_pin end
    if scl_pin then SCL = scl_pin end
    scl_high()
    sda_high()
end

-- I2C Start-Bedingung
local function i2c_start()
    sda_high()
    scl_high()
    delay(1) 
    sda_low()
    delay(1)
    scl_low()
end

-- I2C Stop-Bedingung
local function i2c_stop()
    sda_low()
    delay(1)
    scl_high()
    delay(1)
    sda_high()
    delay(1)
end

-- 1 Byte (8 Bit) rein über Lua auf den Bus schieben
local function i2c_write_byte(byte)
    for i = 7, 0, -1 do
        local bit = math.floor(byte / (2^i)) % 2
        if bit == 1 then sda_high() else sda_low() end
        delay(1)
        scl_high()
        delay(1)
        scl_low()
    end
    
    -- ACK (Bestätigung) vom I2C-Gerät einlesen
    sda_high()
    scl_high()
    local ack = io_control(SDA, "INPUT_PULLUP")
    scl_low()
    
    return ack == 0 
end

-- 1 Byte (8 Bit) vom I2C-Bus einlesen
local function i2c_read_byte(send_ack)
    local byte = 0
    sda_high() 
    
    for i = 7, 0, -1 do
        delay(1)
        scl_high()
        delay(1)
        
        local bit = io_control(SDA, "INPUT_PULLUP") or 0
        if bit == 1 then
            byte = byte + (2^i)
        end
        
        scl_low()
    end
    
    -- ACK/NACK an das Gerät zurücksenden
    -- send_ack == true  -> SDA auf LOW ziehen (Mehr Daten anfordern)
    -- send_ack == false -> SDA auf HIGH lassen (Letztes Byte signalisieren)
    if send_ack then sda_low() else sda_high() end
    delay(1)
    scl_high()
    delay(1)
    scl_low()
    sda_high() 
    
    return byte
end

-- ÖFFENTLICHE HAUPTFUNKTION: i2c.write(adresse, register, daten)
function i2c.write(addr, reg, data)
    i2c_start()
    if not i2c_write_byte(addr * 2) then i2c_stop(); return false end
    if not i2c_write_byte(reg)      then i2c_stop(); return false end
    if not i2c_write_byte(data)     then i2c_stop(); return false end
    i2c_stop()
    return true
end

-- ÖFFENTLICHE LESEFUNKTION: i2c.read(adresse, register)
function i2c.read(addr, reg)
    i2c_start()
    if not i2c_write_byte(addr * 2) then i2c_stop(); return nil end
    if not i2c_write_byte(reg)      then i2c_stop(); return nil end
    
    i2c_start()
    if not i2c_write_byte(addr * 2 + 1) then i2c_stop(); return nil end
    
    local data = i2c_read_byte(false)
    i2c_stop()
    return data
end

-- ÖFFENTLICHE VERFÜGBARKEITS-PRÜFUNG: i2c.available(adresse)
function i2c.available(addr)
    i2c_start()
    local success = i2c_write_byte(addr * 2)
    i2c_stop()
    return success
end

-- ============================================================================
-- i2c.requestFrom(adresse, anzahlBytes)
-- ============================================================================
function i2c.requestFrom(addr, anzahl)
    local empfangeneBytes = {}
    
    i2c_start()
    -- Lese-Modus starten (R/W Bit = 1)
    if not i2c_write_byte(addr * 2 + 1) then 
        i2c_stop()
        return nil 
    end
    
    -- Bytes nacheinander vom Bus saugen
    for k = 1, anzahl do
        -- Solange es nicht das letzte Byte ist, senden wir ein ACK (true)
        local nochMehrAuffordern = (k < anzahl)
        
        local byte = i2c_read_byte(nochMehrAuffordern)
        table.insert(empfangeneBytes, byte)
    end
    
    i2c_stop()
    return empfangeneBytes -- Gibt eine Lua-Tabelle mit den Rohdaten zurück
end

return i2c