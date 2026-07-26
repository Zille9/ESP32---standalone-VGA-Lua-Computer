print("--- Starte SPI-Test-Skript ---")

-- 1. Bus starten
spi.begin()

-- 2. Auf 8 MHz und SPI-Modus 0 stellen
spi.settings(1000000, 0)

-- Definiere Pins für verschiedene SPI-Geräte am Teensy 4.1
local DISPLAY_CS = 17
local SENSOR_CS  = 18

-- EINZEL-TRANSFER TEST:
-- Schreibt das Byte 0x3F an den Sensor auf Pin 9. 
-- C++ zieht Pin 9 automatisch auf LOW und danach wieder auf HIGH!
local antwort = spi.write(0x3F, SENSOR_CS)
print("Sensor-Antwort-Byte erhalten: " .. antwort)
vga.waitsync()
-- BUFFER-TRANSFER TEST (Hocheffizient):
-- Streamt eine Tabelle mit Grafikdaten direkt an das Display auf Pin 10.
local displayDaten = {0xAA, 0x55, 0x00, 0xFF, 0x12, 0x34}
spi.writeBuffer(displayDaten, DISPLAY_CS)
print("Großer Datenpuffer erfolgreich gesendet!")
vga.waitsync()
-- BLOCK-LESEN TEST:
-- Liest 4 Bytes am Stück von Pin 9 (unter Verwendung von Dummy-Byte 0x00)
local blockDaten = spi.readBuffer(4, 0x00, SENSOR_CS)
print("Erstes Byte aus dem gelesenen Block: " .. blockDaten[1])
