local dht = {}

-- Lokaler Cache der schnellen C++ Core Funktion
local native_read = dht_read

-- ÖFFENTLICHE HAUPTFUNKTION: dht.read(pin, typ)
-- typ: 11 für DHT11, 22 für DHT22 (Standard ist 22)
function dht.read(pin, typ)
    typ = typ or 22
    
    -- Native C++ Bit-Messung triggern
    local raw = native_read(pin)
    if not raw or #raw < 5 then
        return nil, nil, "Sensor antwortet nicht (Timeout)"
    end
    
    -- Prüfsumme validieren: Byte 1 + Byte 2 + Byte 3 + Byte 4 = Byte 5
    local checksum = (raw[1] + raw[2] + raw[3] + raw[4]) % 256
    if checksum ~= raw[5] then
        return nil, nil, "Checksummen-Fehler (Daten korrupt)"
    end
    
    local humidity = 0
    local temperature = 0
    
    -- Datendekodierung je nach Sensortyp
    if typ == 22 then
        -- DHT22 / AM2302: 16-Bit Wert mit einer Nachkommastelle
        humidity = ((raw[1] * 256) + raw[2]) / 10
        
        -- Temperatur inklusive Vorzeichenprüfung (Bit 15 bestimmt Minusgrade)
        local raw_temp = (raw[3] * 256) + raw[4]
        if math.floor(raw_temp / 32768) == 1 then
            temperature = -(raw_temp % 32768) / 10
        else
            temperature = raw_temp / 10
        end
    else
        -- DHT11: Einfache Bytes für Ganzzahl + Nachkomma
        humidity = raw[1] + (raw[2] / 10)
        temperature = raw[3] + (raw[4] / 10)
    end
    
    return temperature, humidity, nil
end

return dht