local tableview = require("table_view")
-- Ein Beispiel, wie schön Ihre Dateiliste jetzt aussehen könnte:
local spalten = { "Dateiname", "Groesse", "Typ" }
local dateien = sd.listfile() -- Ihre C++ Dateilisten-Funktion

local tableview = require("table_view")
tableview.zeigeInteraktiv("SD-KARTEN VERZEICHNIS", spalten, dateien)