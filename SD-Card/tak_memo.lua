local cache = {}

local function tak_fast(x, y, z)
    -- Packe x, y, z in einen einzigen 32-Bit-Integer (Bit-Shifting)
    -- Reserviert je 10 Bit pro Zahl (erlaubt Werte von 0 bis 1023)
    local key = (x << 20) | (y << 10) | z
    
    if cache[key] then
        return cache[key]
    end
    
    local result
    if y < x then
        result = tak_fast(
            tak_fast(x - 1, y, z),
            tak_fast(y - 1, z, x),
            tak_fast(z - 1, x, y)
        )
    else
        result = z
    end
    
    cache[key] = result
    return result
end   

-- Testaufruf
local start = sys.timer()
print(tak_fast(36, 26, 16)) -- Gibt sofort 17 aus
print((sys.timer() - start) / 1000 .. " sek.")

cache = {} -- Cache komplett löschen
collectgarbage("collect") -- Erzwingt die Speicherbereinigung auf dem Teensy