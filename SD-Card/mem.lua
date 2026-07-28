-- 1. Startwert anzeigen
info()

-- 2. Eine große Tabelle im Speicher erstellen
print("Erstelle Tabelle..." .. "mit 15000 Werten")
local testTabelle = {}
for i = 1, 15000 do
    testTabelle[i] = "Wert_" .. i
end

-- 3. Speicher nach Erstellung pruefen
info()

-- 4. Tabelle loeschen und Garbage Collector zwingen zu laufen
testTabelle = nil
collectgarbage("collect")

-- 5. Endwert pruefen (sollte fast wieder beim Startwert sein)
info()
