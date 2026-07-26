-- Globales Farbschema: Cyan (11) auf Schwarz (0)
vga.color(63, 1)
vga.cls() -- Leert Schirm und termBuffer!

-- Titelzeile im 8x8 Raster ausgeben
vga.text(2, 1, "--- SPEICHER- UND GRAFIKVALIDIERUNG ---",0,90)

-- Geometrische Formen zeichnen (Pixel-Koordinaten)
vga.rect(16, 32, 100, 100, math.random(255)) -- Leerer Rahmen
vga.box(180, 32, 100, 100, math.random(255))  -- Gefuellte Box

vga.ellipse(80, 170, 40, 30, math.random(255))       -- Leere Ellipse
vga.fillellipse(240, 170, 50, 25, math.random(255)) -- Gefuellte Ellipse
delay(1000)

-- mathematische Funktionen ------
vga.pos(10,30)
print("Sin(81)=")
vga.pos(18,30)
print(math.sin(81))

vga.pos(10,32)
print("(5+6)/7=")
vga.pos(18,32)
a=(5+6)/7
print(a)

delay(3000)


-- Text dynamisch an die aktuelle Position haengen
-- vga.cls()
-- vga.text("Dateien auf SD-Karte:")

-- Moduluebergreifend arbeiten: Verzeichnis sauber gefiltert ausgeben!
-- sd.ls("*.lua")
