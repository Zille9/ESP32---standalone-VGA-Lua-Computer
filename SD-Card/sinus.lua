-- Modul laden
package.loaded ["plotter"] = nil
local plotter = require("plotter")
vga.cursor(false)
vga.cls()

-- 1. Wertebereich festlegen (X von -6.28 bis +6.28, Y von -1.5 bis +1.5)
plotter.setzeBereich(-2 * math.pi, 2 * math.pi, -1.5, 1.5)

-- 2. Das Koordinatennetz und die Zahlenbeschriftung auf den Schirm bringen
plotter.zeichneAchsen()

-- 3. Sinus-Kurve in ROT (Farb-Index 196) zeichnen
plotter.zeichneFunktion(math.sin, 196)

-- 4. Kosinus-Kurve in ORANGE (Farb-Index 240) drüberzeichnen
plotter.zeichneFunktion(math.cos, 240)

-- 5. Eine eigene mathematische Funktion definieren und in WEISS (255) plotten
local meineFormel = function(x)
    return math.sin(x) * math.cos(x * 2)
end
plotter.zeichneFunktion(meineFormel, 255)

-- Warten auf ESC, um zurück ins Terminal zu kehren
while inkey() ~= 27 do 
    delay(20) 
end
vga.cls()
vga.cursor(true)
