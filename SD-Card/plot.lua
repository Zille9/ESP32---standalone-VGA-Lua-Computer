-- Modul laden
local plotter = require("plotter")

-- Simuliert eine Stoßdämpfer-Federung, die langsam zur Ruhe kommt
plotter.zeichneFunktion(function(x) return math.exp(-0.2 * x) * math.sin(x) end, 255)

waitkey()
-- Eine Trägerwelle, die von einer zweiten Frequenz gestaucht und gedehnt wird
plotter.zeichneFunktion(function(x) return math.sin(x + math.sin(x * 2)) end, 127)

waitkey()

-- Erzeugt zackige Spitzen wie bei einer Säge
plotter.zeichneFunktion(function(x) return (x % (2 * math.pi)) / math.pi - 1 end, 240)