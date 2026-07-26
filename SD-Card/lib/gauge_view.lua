-- ============================================================================
-- ANALOGES GAUGE / TACHO-MODUL (gauge_view.lua) - TEIL 1
-- GRAFISCHE ANZEIGE VON HARDWARE-WERTEN AUF PIXELEBENE
-- ============================================================================
local GaugeView = {}

-- --- STANDARD-FARBEN (VGA-Indizes) ---
local COL_SKALA       = 27  -- Cyan für den Tacho-Bogen
local COL_ZEIGER      = 48  -- Rot für den Nadel-Zeiger
local COL_TEXT        = 63  -- Weiß für Min/Max/Wert-Beschriftung
local COL_HINTERGRUND = 0   -- Schwarz
local fc,bc = vga.gcolor()
COL_HINTERGRUND = bc -- Hintergrundfarbe dynamisch anpassen
-- Interne Verlaufssicherung pro Tacho (Merker zum flackerfreien Löschen)
-- Unterstützt bis zu 5 verschiedene Tachos gleichzeitig auf dem Schirm!
local altZeigerX = {}
local altZeigerY = {}

-- Hilfsfunktion: Wandelt einen Wert (von Min bis Max) in den passenden Winkel um.
-- Ein klassischer Tacho geht von links unten (135 Grad) bis rechts unten (45 Grad).
-- Im Bogenmaß (Radiant) entspricht das einem Kreisausschnitt von ca. 270 Grad.
local function wertZuWinkel(wert, minWert, maxWert)
    -- Wert begrenzen, damit der Zeiger nicht durchdreht
    if wert < minWert then wert = minWert end
    if wert > maxWert then wert = maxWert end
    
    local prozent = (wert - minWert) / (maxWert - minWert)
    
    -- Startwinkel: Links unten (math.pi * 0.75)
    -- Endwinkel: Rechts unten (-math.pi * 0.25)
    local startWinkel = math.pi * 0.75
    local gesamtWinkel = math.pi * 1.5 -- 270 Grad Gesamtausschnitt
    
    return startWinkel - (prozent * gesamtWinkel)
end

-- ============================================================================
-- ANALOGES GAUGE / TACHO-MODUL (gauge_view.lua) - TEIL 2
-- RECHNEN UND ZEICHNEN DER STATISCHEN SKALA UND BESCHRIFTUNGEN
-- ============================================================================

-- Zeichnet die statische Skala für ein bestimmtes Gauge
-- Jedes Gauge erhält eine eindeutige ID (1, 2, 3...), um parallel auf dem Schirm zu existieren
function GaugeView.zeichneSkala(id, mitteX, mitteY, radius, minWert, maxWert, einheit)
    -- 1. Großen Außenbogen zeichnen (Nutzt Ihre schnelle vga.ellipse Funktion)
    vga.ellipse(mitteX, mitteY, radius, radius, COL_SKALA)
    vga.ellipse(mitteX, mitteY, radius - 1, radius - 1, COL_SKALA) -- Doppelter Rand

    -- 2. Kleine Skalen-Teilstriche (Ticks) im 270-Grad-Bogen generieren (10 Schritte)
    for i = 0, 10 do
        local prozent = i / 10
        local startWinkel = math.pi * 0.75
        local winkel = startWinkel - (prozent * math.pi * 1.5)
        
        -- Startpunkt des Strichs (am äußeren Bogen)
        local xStart = math.floor(mitteX + ((radius - 6) * math.sin(winkel)) + 0.5)
        local yStart = math.floor(mitteY - ((radius - 6) * math.cos(winkel)) + 0.5)
        -- Endpunkt des Strichs
        local xEnd = math.floor(mitteX + (radius * math.sin(winkel)) + 0.5)
        local yEnd = math.floor(mitteY - (radius * math.cos(winkel)) + 0.5)
        
        vga.line(xStart, yStart, xEnd, yEnd, COL_SKALA)
    end

    -- 3. Min- und Max-Labels im Textraster platzieren (Umrechnung Pixel -> Spalten)
    -- Minimum (Links unten)
    local minX = math.floor((mitteX - radius) / 6)
    local minY = math.floor((mitteY + radius) / 8)
    vga.text(minX, minY, tostring(minWert), COL_TEXT, COL_HINTERGRUND)

    -- Maximum (Rechts unten)
    local maxX = math.floor((mitteX + radius - 16) / 8)
    local maxY = math.floor((mitteY + radius) / 8)
    vga.text(maxX, maxY, tostring(maxWert), COL_TEXT, COL_HINTERGRUND)

    -- Einheit (Zentriert unter der Tacho-Nabe)
    local einheitX = math.floor(mitteX / 6) - math.floor(string.len(einheit) / 2)
    local einheitY = math.floor((mitteY + (radius / 2)) / 8)
    vga.text(einheitX, einheitY, einheit, COL_SKALA, COL_HINTERGRUND)

    -- 4. Verlaufssicherung für diese ID initialisieren, falls noch nicht geschehen
    altZeigerX[id] = mitteX
    altZeigerY[id] = mitteY
end

-- ============================================================================
-- ANALOGES GAUGE / TACHO-MODUL (gauge_view.lua) - TEIL 3 (FINALE)
-- DYNAMISCHES UPDATE UND ZEIGER-RENDERING
-- ============================================================================

-- Aktualisiert den Zeiger und die Digitalanzeige eines Tachos flackerfrei
-- Parameter: id, mitteX, mitteY, radius, aktuellerWert, minWert, maxWert
function GaugeView.updateWert(id, mitteX, mitteY, radius, aktuellerWert, minWert, maxWert)
    -- 1. Winkel für den neuen Wert berechnen
    local winkel = wertZuWinkel(aktuellerWert, minWert, maxWert)
    
    -- Zeigerlänge beträgt 85% des Radius
    local zeigerLaenge = math.floor(radius * 0.85)
    
    -- Neue Pixel-Endkoordinaten des Zeigers ermitteln
    local neuX = math.floor(mitteX - (zeigerLaenge * math.sin(winkel)) + 0.5)
    local neuY = math.floor(mitteY - (zeigerLaenge * math.cos(winkel)) + 0.5)

    -- 2. FLACKERFREIER GRAFIK-WECHSEL
    -- A) ALTEN Zeiger exakt weglöschen (Schwarz = 0)
    if altZeigerX[id] and altZeigerY[id] then
        vga.line(mitteX, mitteY, altZeigerX[id], altZeigerY[id], COL_HINTERGRUND)
    end

    -- B) NEUEN Zeiger scharf einzeichnen (Rot = 196)
    vga.line(mitteX, mitteY, neuX, neuY, COL_ZEIGER)

    -- C) Kleine Naben-Kappe in der Mitte auffrischen
    vga.fillellipse(mitteX, mitteY, 4, 4, COL_SKALA, COL_HINTERGRUND)

    -- D) Aktuelle Koordinaten für das nächste Löschen merken
    altZeigerX[id] = neuX
    altZeigerY[id] = neuY

    -- 3. DIGITALE TEXTANZEIGE (Mittelbündig unter der Nabe)
    local digitalText = string.format("%5.1f", aktuellerWert)
    local txtX = math.floor(mitteX / 6) - 2
    local txtY = math.floor((mitteY + (radius / 3)) / 8)
    vga.text(txtX, txtY, digitalText, COL_TEXT, COL_HINTERGRUND)
end

-- Das komplette Modul an das require()-System übergeben
return GaugeView
