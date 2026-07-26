-- ============================================================================
-- CHIPTUNE TRACKER SONG FÜR TEENSY (Reine Lua-Implementierung)
-- ============================================================================

local Song = {}

-- 1. NOTEN-FREQUENZEN (In Hz)
local Note = {
    C2  = 65,   E2  = 82,   F2  = 87,   G2  = 98,   A2  = 110,  B2  = 123,
    A3  = 220,  C4  = 261,  E4  = 329,  G4  = 392,  A4  = 440,  B4  = 494,
    C5  = 523,  D5  = 587,  E5  = 659,  G5  = 784,  A5  = 880,  B5  = 987,
    OFF = 0
}

-- RAUSCH-FREQUENZEN (Für den Noise-Kanal 3)
local Drum = {
    KICK  = 50,   
    SNARE = 350,  
    HIHAT = 1200, 
    OFF   = 0
}

-- LAUTSTÄRKEN
local Vol = { MAX = 200, MED = 120, LOW = 60, OFF = 0 }

-- 2. LIED-MUSTER (PATTERNS)
-- Format pro Step: { Frequenz, Lautstärke }

-- KANAL 0: Hauptmelodie
local mel_A = {
    {Note.E5, Vol.MAX}, {Note.OFF, Vol.OFF}, {Note.B4, Vol.MED}, {Note.C5, Vol.MAX},
    {Note.D5, Vol.MAX}, {Note.OFF, Vol.OFF}, {Note.C5, Vol.MED}, {Note.B4, Vol.MAX},
    {Note.A4, Vol.MAX}, {Note.OFF, Vol.OFF}, {Note.A4, Vol.MED}, {Note.C5, Vol.MAX},
    {Note.E5, Vol.MAX}, {Note.OFF, Vol.OFF}, {Note.D5, Vol.MED}, {Note.C5, Vol.MAX},
}
local mel_B = {
    {Note.B4, Vol.MAX}, {Note.OFF, Vol.OFF}, {Note.C5, Vol.MED}, {Note.D5, Vol.MAX},
    {Note.E5, Vol.MAX}, {Note.OFF, Vol.OFF}, {Note.C5, Vol.MED}, {Note.A4, Vol.MAX},
    {Note.A4, Vol.MAX}, {Note.OFF, Vol.OFF}, {Note.OFF, Vol.OFF},{Note.OFF, Vol.OFF},
    {Note.OFF, Vol.OFF},{Note.OFF, Vol.OFF},{Note.OFF, Vol.OFF},{Note.OFF, Vol.OFF},
}

-- KANAL 1: Pumpende Bassline
local bass_A = {
    {Note.A2, Vol.MAX}, {Note.A2, Vol.LOW},  {Note.E2, Vol.MED}, {Note.A2, Vol.LOW},
    {Note.C2, Vol.MAX}, {Note.C2, Vol.LOW},  {Note.G2, Vol.MED}, {Note.C2, Vol.LOW},
    {Note.F2, Vol.MAX}, {Note.F2, Vol.LOW},  {Note.C2, Vol.MED}, {Note.F2, Vol.LOW},
    {Note.E2, Vol.MAX}, {Note.G2, Vol.MED},  {Note.B2, Vol.MAX}, {Note.E2, Vol.LOW},
}

-- KANAL 3: Drums (Rauschen)
local drum_A = {
    {Drum.KICK, Vol.MAX},  {Drum.HIHAT, Vol.LOW}, {Drum.OFF, Vol.OFF},   {Drum.HIHAT, Vol.LOW},
    {Drum.SNARE, Vol.MAX}, {Drum.HIHAT, Vol.LOW}, {Drum.KICK, Vol.MED},  {Drum.HIHAT, Vol.LOW},
    {Drum.KICK, Vol.MAX},  {Drum.HIHAT, Vol.LOW}, {Drum.SNARE, Vol.MED}, {Drum.HIHAT, Vol.LOW},
    {Drum.SNARE, Vol.MAX}, {Drum.HIHAT, Vol.LOW}, {Drum.KICK, Vol.MAX},  {Drum.HIHAT, Vol.LOW},
}

-- 3. PLAYLIST SEQUENCE (Ablaufsteuerung des Songs)
Song.sequence = {
    { mel = {},    bass = bass_A, drum = drum_A }, -- Intro: Nur Bass & Beat
    { mel = mel_A, bass = bass_A, drum = drum_A }, -- Hauptteil Strophe
    { mel = mel_B, bass = bass_A, drum = drum_A }, -- Hauptteil Refrain
}

-- 4. TIMING & ENGINE VARIABLEN (Vollständig in Lua)
local currentPatternIdx = 1
local currentStep = 1
local tempoBPM = 135

-- Berechne die mathematisch exakte Dauer einer 16tel-Note in Millisekunden
-- Formel: (60000 ms / BPM) / 4 Schritte pro Schlag
local stepDurationMs = (60000 / tempoBPM) / 4  -- Bei 135 BPM exakt 111.11 ms
local drumDurationMs = 40                      -- Knackige 40ms Rausch-Impuls für Drums

local nextStepTime = 0
local stopDrumTime = 0
local drumIsPlaying = false

-- ============================================================================
-- HAUPT-UPDATE-FUNKTION (Wird in der C++ loop() kontinuierlich aufgerufen)
-- ============================================================================
function Song.update(currentTimeMs)
    
    -- Initialisierung beim allerersten Durchlauf
    if nextStepTime == 0 then 
        nextStepTime = currentTimeMs 
    end

    -- DRUM-TIMEOUT SCHUTZ: Schaltet das Rauschen nach X Millisekunden starr ab
    if drumIsPlaying and (currentTimeMs >= stopDrumTime) then
        sound.stop(3)
        drumIsPlaying = false
    end

    -- TRIGGER: Ist die Zeit für den nächsten Musik-Schritt erreicht?
    if currentTimeMs >= nextStepTime then
        
        -- GEGEN TIMING-STOLPERN (Anti-Drift): 
        -- Wir addieren die Dauer fest auf das Wunschergebnis auf, statt 'currentTimeMs'
        -- zu nehmen. Dadurch gleicht Lua kleine Verspätungen der C++ Schleife sofort aus.
        nextStepTime = nextStepTime + stepDurationMs
        
        -- Aktuelles Pattern aus der Playlist holen
        local pattern = Song.sequence[currentPatternIdx]
        if not pattern then
            currentPatternIdx = 1 -- Song-Ende erreicht -> Loop von vorne
            pattern = Song.sequence[currentPatternIdx]
        end
        
        -- --- KANAL 0: Melodie ---
        local m = pattern.mel and pattern.mel[currentStep]
        if m and m[1] > 0 then
            sound.play(m[1], m[2])
        else
            sound.stop(0)
        end
        
        -- --- KANAL 1: Bass ---
        local b = pattern.bass and pattern.bass[currentStep]
        if b and b[1] > 0 then
            sound.play(1, b[1], b[2])
        else
            sound.stop(1)
        end
        
        -- --- KANAL 3: Drums (Noise) ---
        local d = pattern.drum and pattern.drum[currentStep]
        if d and d[1] > 0 then
            sound.play(3, d[1], d[2])
            -- Drum-Timer setzen: genau JETZT + 40ms
            stopDrumTime = currentTimeMs + drumDurationMs
            drumIsPlaying = true
        end
        
        -- WEITERZÄHLEN ZUM NÄCHSTEN STEP
        currentStep = currentStep + 1
        if currentStep > 16 then
            currentStep = 1
            currentPatternIdx = currentPatternIdx + 1
        end
    end
end

return Song