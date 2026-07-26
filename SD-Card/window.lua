-- Farben festlegen (RGB565 Beispielwerte)
local FARBE_BLAU = 11
local FARBE_ROT  = 196

-- Ein blaues Infofenster in der Bildschirmmitte zeichnen
vga.openWindow(0,10, 10, 210, 75, 255, FARBE_BLAU, "SYSTEM-INFO", "Der USB-Tastaturtreiber wurde erfolgreich geladen. Was moechten Sie noch tun?", 87)

-- Ein rotes Warnfenster darunter zeichnen
vga.openWindow(1,50, 60, 120, 60, 255, 96, "WARNUNG", "SD-Karte fast voll!", FARBE_ROT)

--- Auf Taste warten ---
waitkey(0)

--- Fenster 1 loeschen ---
vga.closeWindow(1)

--- Auf Taste warten ---
waitkey(0)

--- Fenster 0 loeschen ---
vga.closeWindow(0)


