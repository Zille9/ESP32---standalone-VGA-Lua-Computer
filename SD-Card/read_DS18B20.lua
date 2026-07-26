local ow = require("onewire")

-- Initialisierung und Nutzung bleibt absolut identisch:
ow.init(17) 

local temp, err = ow.readTemperature()
if temp then
    print(string.format("Temperatur: %.2f *C", temp))
else
    print("Fehler: " .. err)
end

collectgarbage("collect")