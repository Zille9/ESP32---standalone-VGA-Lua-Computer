-- =============================================================================
--  UEXT HARDWARE VISUALIZER (WAAGERECHTE ANSICHT)
-- =============================================================================

-- Farbcodes 
local COLOR_BLACK = 0
local COLOR_WHITE = 63  
local COLOR_RED   = 32  -- Rot (Low / 0)
local COLOR_GREEN = 12  -- Gruen (High / 1 / Power)
local COLOR_GRAY  = 42  -- Hintergrund fuer den Stecker

-- Belegungsplan: 2 Reihen a 5 Pins (Draufsicht auf den Port)
-- Ungerade Pins (1, 3, 5, 7, 9) liegen oben bei y = 100
-- Gerade Pins (2, 4, 6, 8, 10) liegen unten bei y = 140
local uext_pins = {
    -- REIHE 1 (OBEN) - x-Abstand jeweils 50 Pixel
    { id = 1,  name = "3.3V",      x = 260, y = 100, static = true,  color = COLOR_GREEN }, -- Pin 1 fest Power
    { id = 3,  name = "D5(TX)",    x = 210, y = 100, static = false },
    { id = 5,  name = "C2(SCL)",   x = 160, y = 100, static = false },
    { id = 7,  name = "A2(MISO)",  x = 110, y = 100, static = false },
    { id = 9,  name = "D4(SCK)",   x = 60,  y = 100, static = false },

    -- REIHE 2 (UNTEN)
    { id = 2,  name = "GND",       x = 260, y = 140, static = true,  color = COLOR_BLACK }, -- Pin 2 fest Masse
    { id = 4,  name = "D6(RX)",    x = 210, y = 140, static = false },
    { id = 6,  name = "C1(SDA)",   x = 160, y = 140, static = false },
    { id = 8,  name = "A1(MOSI)",  x = 110, y = 140, static = false },
    { id = 10, name = "D3(CS)",    x = 60,  y = 140, static = false }
}

-- 1. Hardware initialisieren (Nur die schaltbaren Pins konfigurieren)
print("Initialisiere UEXT-Pins als Eingänge...")
for _, pin in ipairs(uext_pins) do
    if not pin.static then
        gpio.config(pin.id, gpio.IN, 1) -- Als Eingang mit Pull-Up konfiguriert
    end
end

vga.cursor(false)
-- Bildschirm vorbereiten
vga.cls(COLOR_BLACK)

-- Statische Grafik zeichnen: Der UEXT-Wannenstecker (langgezogene Box für 2x5 Pins)
vga.box(35, 55, 260,115, COLOR_GRAY) 
vga.rect(30,50, 270,125,COLOR_WHITE)

-- Wannenstecker-Nase (Die kleine Kerbe oben in der Mitte zur Orientierung)
vga.box(145, 50, 30, 10, COLOR_GRAY)

vga.color(COLOR_WHITE, COLOR_BLACK)
vga.waitsync()
vga.text(10, 2, "--- OLIMEX UEXT PORT VISUALIZER ---")

local running = true

while running do
    if inkey() == 27 then running = false end
    
    -- Pins abfragen und grafisch aktualisieren
    for _, pin in ipairs(uext_pins) do
        local pin_color = pin.color
        
        -- Pegel nur lesen, wenn es kein statischer Pin (wie 3.3V/GND) ist
        if not pin.static then
            local level = gpio.read(pin.id)
            if level == 1 then
                pin_color = COLOR_GREEN
            else
                pin_color = COLOR_RED
            end
        end
        
        -- Pin-Kreis ausfuellen
        --vga.color(pin_color, COLOR_BLACK)
        vga.fillellipse(pin.x, pin.y, 8, 8, pin_color)
        
        -- Aussenring -------
        --vga.color(COLOR_WHITE, COLOR_BLACK)
        vga.ellipse(pin.x, pin.y, 9, 9, COLOR_WHITE)
        
        --vga.color(COLOR_WHITE, COLOR_BLACK)
        
        local text_col = math.floor(pin.x / 5) - 2
        
        local text_row = math.floor(pin.y / 8)
        if pin.y == 100 then
            text_row = text_row - 3
        else
            text_row = text_row + 2
        end
        
        vga.text(text_col, text_row, pin.name, COLOR_BLACK,COLOR_GRAY,1)
    end
    delay(30)
    vga.waitsync() 
end

-- Bildschirm loeschen

vga.cls(COLOR_BLACK)
vga.cursor(true)