-- Tabellenmodul laden
local tableview = require("table_view")

-- Überschriften definieren
local spalten = { "ID", "Name", "Aufgabe / Beruf", "Status" }

-- Zeilenweise Testdaten generieren (Wir erstellen 50 Zeilen, um das Scrollen zu testen!)
local datenSatz = {}
for i = 1, 50 do
    datenSatz[i] = {
        string.format("#%03d", i),
        "Benutzer " .. i,
        "System-Task " .. (i * 7 % 5),
        (i % 3 == 0) and "Aktiv" or "Standby"
    }
end

-- Das Modul interaktiv im Terminal aufrufen!
tableview.zeigeInteraktiv("PROZESS-DATENBANK", spalten, datenSatz)
collectgarbage()
