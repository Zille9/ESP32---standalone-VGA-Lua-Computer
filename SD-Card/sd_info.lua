local dateien = sd.listfile()
local gesamtGroesseKB = 0
local dateiZaehler = 0
local ordnerZaehler = 0
vga.cls()
for i = 1, #dateien do
    if dateien[i][3] == "ORDNER" then
        ordnerZaehler = ordnerZaehler + 1
    else
        dateiZaehler = dateiZaehler + 1
        -- "12.4 KB" -> Text filtern und in Zahl wandeln
        local groesseText = string.match(dateien[i][2], "([%d%.]+)")
        gesamtGroesseKB = gesamtGroesseKB + tonumber(groesseText or 0)
    end
end

print("--- SD-KARTEN STATISTIK ---\n\r")
print("Dateien gesamt : " .. dateiZaehler .. "\n\r")
print("Ordner gesamt  : " .. ordnerZaehler .. "\n\r")
print("Speicher Lua   : " .. string.format("%.2f MB", gesamtGroesseKB / 1024) .. "\n\r")
