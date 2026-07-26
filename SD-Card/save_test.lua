local file = sd.open("highscore.txt", "w")

if file then
    -- Einen einfachen String hineinschreiben
    sd.write(file, "PLAYER1: 45200\n")
    sd.write(file, "PLAYER2: 31000\n")
    
    sd.close(file)
    print("Highscores erfolgreich als Text gespeichert.")
end