local dht = require("dht")

-- Sensor an Pin 17 auslesen (Beispiel als DHT22)
local temp, hum, err = dht.read(17, 22)

if not err then
    print(string.format("Temperatur : %.1f *C", temp))
    print(string.format("Luftfeuchte: %.1f %% RH", hum))
else
    print("Fehler: " .. err)
end
collectgarbage("collect")
