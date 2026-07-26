---- neues skript -----
local fcolor, bcolor = vga.gcolor()
vga.cls(bcolor)
vga.waitsync()
for i=0,63 do
  vga.color(0,i)
  write(" ")
  write(i)
  write(" ")
  
end
---- Farben zuruecksetzen ----
vga.color(fcolor,bcolor)

---- Naechste Zeile ----------
--print("\n\r")
print("-Taste-")
waitkey()
