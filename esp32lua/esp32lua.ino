////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                    LUA für ESP32 und Fabgl                                                                                     //
//                                    VGA Ausgabe 320x240 - Juli 2026                                                                             //
//                                    Zeichenausgabe 53x30 Zeichen                                                                                //
//                                                                                                                                                //
//                              Fliesskomma-Arithmetik mit float-Präzision                                                                        //
//                              Editor für Skripte mit :-Block-Kopier und Einfügefunktion                                                         //
//                                                      -Block-Löschfunktion                                                                      //
//                                                                                                                                                //
//                              Farb- und Grafikfunktionen 64 Farben                                                                              //
//                              mathematische Funktionen                                                                                          //
//                              SD-Card-Funktionen                                                                                                //
//                              Flashloader für bin-Dateien - fehlt noch                                                                          //
//                                                                                                                                                //
//                                                                                                                                                //
//      von:Reinhard Zielinski <zille09@gmail.com>                                                                                                //
//                                                                                                                                                //
//      Connections: SD-Card -> TTGO VGA 1.4                                                                                                      //
//                   VGA-Beschaltung: siehe FabGl/TTGO VGA                                                                                        //
//                                                                                                                                                //
//                                                                                                                                                //
//                                                                                                                                                //
//                                                                                                                                                //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ################################################### Projekt-Tagebuch ############################################################################
// 25.07.2026
// zusätzliche Funktionstasten im Terminal eingebaut F2 -> letzte Datei editieren (edit), F3 -> letzte Datei ausführen (run)
// Editor erweitert, Fehler im Programm lässt den Cursor beim Aufrufen des Editors in die Fehlerzeile springen
// Soundfunktion aus FabGl integriert -> sound(kanal(0-5), Note (1-127), Dauer(ms), Lautstärke (0-127))
//
// 24.07.2026
// Grafikfunktionen denen des Teensy angepasst, damit die Lua-Skripte laufen
// Inkey-Funktion aufgebohrt, jetzt werden auch Sondertasten korrekt interpretiert
// Lua-Befehl vga.cursor(true/false) eingefügt, um den Cursor bei Bedarf abzuschalten
// bei Editor-Start wird der Cursor immer eingeschaltet, damit auch editiert werden kann
// interne RTC des ESP32 kann abgefragt werden, Zeit/Datum wird beim Flashen gestellt, ist nach dem Ausschalten aber weg, da noch keine echte RTC dranhängt
// Olimex SBC FabGl-Board ist auf dem Weg, damit lässt sich hoffentlich genauso gut arbeiten, wie mit dem TTGO VGA
//
// 20.07.2026
// Version ist noch nicht beendet, der Speicher ist für einen normalen ESP32 zu knapp, um ernsthaft mit Lua zu arbeiten
// TTGO VGA mit 4MB PSRAM hilft, das Speicherproblem zu lösen
// Bearbeitungs- und Lua-Speicher in den PSRAM ausgelagert, das schafft massiv Platz
// Window-Funktionen sind jetzt ebenfalls integriert, auch überlappende Fenster funktionieren, solange man immer das oberste Fenster zuerst wieder löscht
//

#include <Arduino.h>
#include "fabgl.h" //********************************************* Bibliotheken zur VGA-Signalerzeugung *********************************************
fabgl::Terminal         Terminal;
fabgl::VGAController    VGAController;      //VGA-Variante
fabgl::Canvas           GFX(&VGAController);
TerminalController      tc(&Terminal);
fabgl::SoundGenerator SoundGenerator;

//**************************** EDITOR - Varablen **********************************************
// Der dedizierte 48 KB Bearbeitungspuffer im internen RAM
#define EDIT_BUFF_SIZE 131072       // 128 KB (Oder 262144 für 256 KB – ganz nach Wunsch!)
char* textBuffer = nullptr;         // Ein Pointer auf den Speicherbereich im PSRAM
uint32_t textLen = 0;
uint32_t topIndex = 0; // Byte-Adresse im textBuffer, ab der die aktuelle Seite gerendert wird
uint32_t leftColumn = 1; // Startspalte für die Anzeige (Standard: 1)

#define LUA_MAX_PSRAM  1048576   // 1 MB Limit für Lua (1 * 1024 * 1024)
size_t luaCurrentMemoryUsage = 0; // Zähler für den aktuellen Verbrauch

//------------------------- Editor Zwischenablage -------------------------
#define CLIPBOARD_SIZE 16384       // 16 KB maximaler Zeilenpuffer im PSRAM
char* clipboardBuffer = nullptr;   // Pointer zeigt direkt in den PSRAM
uint32_t clipboardLen = 0;
bool selectionModeActive = false; // Steuert, ob der Block-Anfang gesetzt ist
uint32_t blockStartPos = 0;       // Speichert die Cursorposition des Block-Starts
int fehlerZeile = 1;

byte x_char[]  PROGMEM = {8, 5, 6, 8,  10, 8,  8,  8,  8,  8,  8,  8,  8,  6,  8,  4, 6,  7,  7,  8, 8, 8, 6, 9, 8, 8, 6}; //x-werte der Fontsätze zur Berechnung der Terminalbreite
byte y_char[]  PROGMEM = {8, 8, 8, 14, 20, 14, 14, 16, 16, 14, 14, 14, 16, 10, 14, 6, 12, 13, 14, 9, 14, 14, 13, 15, 16, 8, 8}; //y-werte der Fontsätze zur Berechnung der Terminalhöhe

int current_Font = 26;                                   //Systemfont 6x8Pixel
// Terminal-Größe
const int MAX_C = 320 / x_char[current_Font];           //Anzahl Textspalten
const int MAX_R = 240 / y_char[current_Font];           //Anzahl Textzeilen


String inputBuffer = "";
uint8_t fColor = 63; // Vordergrundfarbe weiss
uint8_t bColor = 1;   // Hintergrundfarbe dunkelblau

bool Cursor = true;   //globaler Cursor-Merker

// Globaler Bildschirmpuffer für Overlays/Popups (im PSRAM)
RGB222* globalScreenBackup = nullptr;
Rect globalBackupRect; // Merkt sich die ursprüngliche Position und Größe


//------------------------------------------ Tastatur,GFX-Treiber- und Terminaltreiber -------------------------------------------------------------
fabgl::PS2Controller    PS2Controller;
fabgl::Keyboard Keyboard;

// Tastencode-Dolmetscher
#define KEY_UP        218
#define KEY_DOWN      217
#define KEY_RIGHT     215
#define KEY_LEFT      216
#define KEY_DELETE    212
#define KEY_PAGE_UP   211
#define KEY_PAGE_DOWN 214
#define KEY_ESC       27
#define KEY_HOME      210
#define KEY_END       213

// Funktionstasten F1 bis F12
#define KEY_F1        194
#define KEY_F2        195
#define KEY_F3        196
#define KEY_F4        197
#define KEY_F5        198
#define KEY_F6        199
#define KEY_F7        200
#define KEY_F8        201
#define KEY_F9        202
#define KEY_F10       203
#define KEY_F11       204
#define KEY_F12       205

//------------------------------------------------------------- Soundgenerator ----------------------------------------------------------------------------
unsigned int noteTable []  PROGMEM = {16350, 17320, 18350, 19450, 20600, 21830, 23120, 24500, 25960, 27500, 29140, 30870}; //Notentabelle für Soundausgabe
//------------------------------------------------------------- Soundgenerator ----------------------------------------------------------------------------
//***************************************** WINDOW **********************************************
// Struktur für die Fenster-Verwaltung
struct WindowSlot {
  int x;
  int y;
  int w;
  int h;
  int fc;
  int bc;
  String titel;
  String inhalt;
  uint16_t titelFarbe;
  bool aktiv;

  // ================= NEU: LOKALER SCREENBUFFER PRO SLOT =================
  RGB222* screenBackup = nullptr; // Individueller Zeiger in den PSRAM
  Rect savedRect;                 // Speichert die exakten Maße dieses Fensters
};

// Ihr bestehendes Array (jetzt mit integrierten Puffern)
WindowSlot windowManager[8];
bool Window_aktiv = false;
//------------------------------------------ SD-Karte ----------------------------------------------------------------------------------------------

#include <SD.h>
#include <SPI.h>

SPIClass spiSD(HSPI);
File fp;

#define kSD_CS   13
#define kSD_MISO 2 //16
#define kSD_MOSI 12
#define kSD_CLK  14
const char* currentEditingFilename = '\0';
uint32_t speedHz = 16000000;
//------------------------------------- OTA-Update-Lib --------------------------------------------------------------------------------------------
#include <Update.h>
//-------------------------------------------------------------------------------------------------------------------------------------------------

//------------------------------------- ESP32-Time-Lib fuer Datei-zeitstempel ---------------------------------------------------------------------
#include <ESP32Time.h>
ESP32Time e_rtc(0);  // offset in seconds GMT+1
//-------------------------------------------------------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------------------------------------------------------
/*
  #include <Wire.h>           // for I2C
  #include "RTClib.h"         //to show time
  TwoWire myI2C = TwoWire(0); //eigenen I2C-Bus erstellen
  RTC_DS3231 rtc;
*/
#include <vector>

TaskHandle_t LuaTaskHandle = NULL;

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}

  extern "C" int sd_file_exists(const char* filename) {
    // Hier befinden wir uns in C++ und dürfen 'SD.exists' ganz normal nutzen!
    if (SD.exists(filename)) {
      return 1; // Datei existiert
    }
    return 0;   // Datei existiert nicht
  }

  // Das Arbeitsverzeichnis standardmässig auf /lua/
  String currentWorkDir = "/lua/";

  // Dummy-Implementierungen für fehlende POSIX-Systemaufrufe (Newlib-Stubs)
  extern "C" {
    int _open(const char *path, int flags, ...) {
      return -1;
    }
    int _getpid(void) {
      return 1;
    }
    int _times(void *buf) {
      return -1;
    }
    int _unlink(const char *pathname) {
      return -1;
    }
    int _link(const char *oldpath, const char *newpath) {
      return -1;
    }
    int _kill(int pid, int sig) {
      return -1;
    }
    int system(const char *command) {
      return -1; // Gibt an den Lua-Interpreter zurück, dass kein System-OS existiert
    }
  }


  lua_State *L;



  // Hilfsfunktion: Macht aus "skript.lua" automatisch "/pfad/skript.lua"
  String resolve_lua_path(String filename) {
    if (filename.startsWith("/")) {
      return filename;                // Wenn es absolut mit / beginnt, so lassen
    }
    return currentWorkDir + filename; // Ansonsten das aktuelle Verzeichnis davorhängen
  }
  //--------------------------------------------- Unterrogramm - Farben setzen ----------------------------------------------------------------------

  void fbcolor(int fc, int bc)
  {
    /*
      if (!Frame_nr) {
      Frame_vcol[0] = fc;
      Frame_hcol[0] = bc;
      }
    */

    fcolor(fc);
    bcolor(bc);
  }

  void fcolor(int fc) {
    //GFX.setPenColor((bitRead(fc, 5) * 2 + bitRead(fc, 4)) * 64, (bitRead(fc, 3) * 2 + bitRead(fc, 2)) * 64, (bitRead(fc, 1) * 2 + bitRead(fc, 0)) * 64);
    GFX.setPenColor(((fc >> 4) & 0x03) * 85, ((fc >> 2) & 0x03) * 85, (fc & 0x03) * 85);
    //delay(2);
  }

  void bcolor(int bc) {
    //GFX.setBrushColor((bitRead(bc, 5) * 2 + bitRead(bc, 4)) * 64, (bitRead(bc, 3) * 2 + bitRead(bc, 2)) * 64, (bitRead(bc, 1) * 2 + bitRead(bc, 0)) * 64);
    GFX.setBrushColor(((bc >> 4) & 0x03) * 85, ((bc >> 2) & 0x03) * 85, (bc & 0x03) * 85);
    //delay(2);

  }



  //************************************* Lua-Print *************************************
  static int lua_custom_print(lua_State *L) {
    int n = lua_gettop(L);
    String outStr = "";
    for (int i = 1; i <= n; i++) {
      if (i > 1) outStr += "\t";
      if (lua_isstring(L, i)) outStr += lua_tostring(L, i);
      else if (lua_isboolean(L, i)) outStr += (lua_toboolean(L, i) ? "true" : "false");
      else outStr += lua_typename(L, lua_type(L, i));
    }
    outStr += "\n\r";
    Terminal.print(outStr.c_str());
    return 0;
  }

  //************************************* Lua-Write *************************************
  static int lua_custom_write(lua_State *L) {
    int n = lua_gettop(L);
    String outStr = "";
    for (int i = 1; i <= n; i++) {
      if (i > 1) outStr += "\t";
      if (lua_isstring(L, i)) outStr += lua_tostring(L, i);
      else if (lua_isboolean(L, i)) outStr += (lua_toboolean(L, i) ? "true" : "false");
      else outStr += lua_typename(L, lua_type(L, i));
    }
    //outStr += "\n\r";
    Terminal.print(outStr.c_str());
    return 0;
  }

  //************************************* Lua-Delay ***********************************************

  int lua_delay(lua_State *L) {
    delay(luaL_checkinteger(L, 1));
    return 0;
  }
  //************************************* Lua-Delay_us ********************************************

  int lua_delay_us(lua_State* L) {
    delayMicroseconds(luaL_checkinteger(L, 1));
    return 0;
  }

  //************************************* Lua-Inkey ***********************************************
  // Globale Lua-Funktion: inkey() - Gibt den gedrückten Tastencode zurück oder -1
  /*
    int lua_global_inkey(lua_State* L) {
    int taste = Terminal.read(5);
    lua_pushinteger(L, taste);
    return 1;
    }
  */
  int lua_global_inkey(lua_State* L) {
    if (!Terminal.available()) {
      lua_pushinteger(L, 0); // 0 signalisiert Lua: Keine Taste gedrückt
      return 1;
    }

    // 2. Es liegt mindestens ein Zeichen bereit -> auslesen
    char c = Terminal.read();

    // 3. Wenn es ein ESC (27) ist, prüfen wir blitzschnell auf eine Sequenz
    if (c == 27) {
      // 5 Millisekunden warten, ob Folgezeichen eintreffen
      uint32_t timeout = millis() + 5;
      while (!Terminal.available() && millis() < timeout) {
        vTaskDelay(pdMS_TO_TICKS(1));
      }

      // Wenn nach 5ms nichts nachkam, war es die echte ESC-Taste
      if (!Terminal.available()) {
        lua_pushinteger(L, KEY_ESC); // Ihre Konstante für ESC (z.B. -8)
        return 1;
      }

      // Nächstes Zeichen der Sequenz lesen
      char next1 = Terminal.read();

      if (next1 == '[') {
        while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
        char next2 = Terminal.read();

        // Cursortasten direkt decodieren
        if (next2 == 'A') {
          lua_pushinteger(L, KEY_UP);
          return 1;
        }
        if (next2 == 'B') {
          lua_pushinteger(L, KEY_DOWN);
          return 1;
        }
        if (next2 == 'C') {
          lua_pushinteger(L, KEY_RIGHT);
          return 1;
        }
        if (next2 == 'D') {
          lua_pushinteger(L, KEY_LEFT);
          return 1;
        }

        // FabGL HOME & END Tasten
        if (next2 == 'H') {
          lua_pushinteger(L, KEY_HOME);
          return 1;
        }
        if (next2 == 'F') {
          lua_pushinteger(L, KEY_END);
          return 1;
        }


        // Tasten mit abschließender Tilde (ENTF, PageUp/Down)
        if (next2 == '3' || next2 == '5' || next2 == '6') {
          while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
          char tilde = Terminal.read(); // '~' verwerfen
          if (next2 == '3') {lua_pushinteger(L, KEY_DELETE);return 1;}
          if (next2 == '5') {lua_pushinteger(L, KEY_PAGE_UP);return 1;}
          if (next2 == '6') {lua_pushinteger(L, KEY_PAGE_DOWN);return 1;}
        }
        
        if (next2 == '1' && Terminal.available()) {
          char next3 = Terminal.read();
          if (Terminal.read() == '~') { // Tilde verwerfen
            if (next3 == '5') {lua_pushinteger(L, KEY_F5);return 1;}
            if (next3 == '7') {lua_pushinteger(L, KEY_F6);return 1;}
            if (next3 == '8') {lua_pushinteger(L, KEY_F7);return 1;}
            if (next3 == '9') {lua_pushinteger(L, KEY_F8);return 1;}
          }
        }
        
        if (next2 == '2' && Terminal.available()) {
          char next3 = Terminal.read();
          if (Terminal.read() == '~') {
            if (next3 == '0') {lua_pushinteger(L, KEY_F9);return 1;}
            if (next3 == '1') {speichere_bildschirm_als_bmp(0, 0, 320, 240, "screen.bmp"); lua_pushinteger(L, KEY_F10);return 1;}  //Screenshot-Funktion
          }
        }

      }
      else if (next1 == 'O') {
        while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
        char next2 = Terminal.read();
        if (next2 == 'P') {lua_pushinteger(L, KEY_F1);return 1;}
        if (next2 == 'Q') {lua_pushinteger(L, KEY_F2);return 1;}
        if (next2 == 'R') {lua_pushinteger(L, KEY_F3);return 1;}
        if (next2 == 'S') {lua_pushinteger(L, KEY_F4);return 1;}
      }
      // Falls die Sequenz unbekannt oder korrupt war
      lua_pushinteger(L, 0);
      return 1;
    }
    // 4. Jedes normale ASCII-Zeichen direkt zurückgeben
    lua_pushinteger(L, c);
    return 1;
  }
  //************************************* Lua-waitkey *********************************************
  static uint16_t wait_key(bool modes) {
    if (modes) {
      Terminal.println();
      Terminal.println("SPACE<Continue>/CTR+C <Exit>");
    }
    return inchar();
  }

  int lua_global_waitkey(lua_State* L) {
    bool modes = false;                                                   // Parameter aus Lua auslesen (Standardmäßig false, wenn nichts übergeben wurde)
    if (lua_isboolean(L, 1)) {
      modes = lua_toboolean(L, 1);
    } else if (lua_isnumber(L, 1)) {
      modes = (lua_tointeger(L, 1) != 0);
    }
    uint16_t gedrueckteTaste = wait_key(modes);
    lua_pushinteger(L, gedrueckteTaste);
    return 1;
  }

  //************************************* Lua-run(datei) *********************************************
  // Lua-Befehl: run("name.lua")
  int lua_dofile(lua_State *L) {
    const char* filename = luaL_checkstring(L, 1);
    String sdPath = resolve_lua_path(filename);
    uint32_t runTextLen = 0;

    memset(textBuffer, 0, EDIT_BUFF_SIZE);

    if (SD.exists(sdPath.c_str())) {
      Terminal.printf("Lade %s von SD-Karte...\n\r", filename);
      File sdFile = SD.open(sdPath.c_str(), FILE_READ);

      if (sdFile) {
        while (sdFile.available() && runTextLen < (EDIT_BUFF_SIZE - 1)) {
          char c = sdFile.read();
          if (c == 0x0D) continue;
          textBuffer[runTextLen++] = c;
        }
        sdFile.close();
        textBuffer[runTextLen] = '\0';

        currentEditingFilename = filename;                    //Dateiname für eventuelles editieren (F2) speichern

        // Code ausführen
        int status = luaL_dostring(L, textBuffer);

        if (status != LUA_OK) {
          const char* roherFehler = lua_tostring(L, -1);
          Terminal.printf("LUA ERROR: %s\n\r", roherFehler);
          String errorMsg = String(roherFehler);
          lua_pop(L, 1);

          fehlerZeile = 1;
          int doppelpunktIdx = errorMsg.indexOf(':');

          if (doppelpunktIdx != -1) {
            // Nach dem ersten Doppelpunkt steht die Zeile (z.B. "game.lua:14:")
            String rest = errorMsg.substring(doppelpunktIdx + 1);
            int zweiterDoppelpunkt = rest.indexOf(':');
            if (zweiterDoppelpunkt != -1) {
              fehlerZeile = rest.substring(0, zweiterDoppelpunkt).toInt();
            }
          }
        }
      } else {
        Terminal.println("FEHLER: Konnte Datei nicht oeffnen!");
      }
    } else {
      Terminal.printf("Fehler: Datei '%s' existiert nicht!\n\r", filename);
    }

    return 0;
  }

  //************************************* Lua-info() *********************************************
  int lua_info(lua_State *L) {
    uint32_t freeHeap = ESP.getFreeHeap();
    int luaMemKb = lua_gc(L, LUA_GCCOUNT, 0);
    int luaMemBytesRemainder = lua_gc(L, LUA_GCCOUNTB, 0);
    uint32_t totalLuaBytes = (luaMemKb * 1024) + luaMemBytesRemainder;

    Terminal.println("--- SYSTEM SPEICHER ---");
    Terminal.printf(" Interner RAM (Heap) frei: %d Bytes (%d KB)\n\r", freeHeap, freeHeap / 1024);
   // Terminal.printf(" Intern.RAM v.Lua belegt : %d Bytes (%d KB)\n\r", luaCurrentMemoryUsage, freeHeap / 1024);
    Terminal.printf(" max. Lua PSRAM          : %d Bytes (%d KB)\n\r", LUA_MAX_PSRAM, LUA_MAX_PSRAM / 1024);
    Terminal.printf(" Lua-Engine belegt       : %d Bytes (%d KB)\n\r", totalLuaBytes, luaMemKb);
    Terminal.printf(" Lua PSRAM-Auslastung    : %.2f%% \n\r", ((float)luaCurrentMemoryUsage / LUA_MAX_PSRAM) * 100.0);
    Terminal.printf(" freier PSRAM gesamt     : %d Bytes\n\r", ESP.getFreePsram());
    Terminal.printf(" Editor Puffergroesse    : %d Bytes (%d KB)\n\r", textLen, EDIT_BUFF_SIZE / 1024);
    Terminal.println("-----------------------");
    lua_pushinteger(L, freeHeap);
    return 1;
  }

  //********************************************** Grafikfunktionen *************************************
  // ============================================================================
  // VGA GRAPHICS INTERFACE (Modul: vga)
  // ============================================================================

  // 1. vga.color(vordergrund, hintergrund)
  int lua_vga_color(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2)) {
      Terminal.print("FEHLER : vga.color(vordergrund, hintergrund) erwartet 2 Zahlen!");
      lua_pushboolean(L, false);
      return 1;
    }
    fColor = (int)lua_tonumber(L, 1);
    bColor = (int)lua_tonumber(L, 2);
    fbcolor(fColor, bColor);
    return 0;
  }

  // 2. vga.cls()
  int lua_vga_cls(lua_State* L) {
    int farbe = bColor; // Fallback auf das aktuelle globale bColor
    if (lua_gettop(L) >= 1 && lua_isnumber(L, 1)) {
      farbe = (int)lua_tonumber(L, 1);
    }
    bColor = farbe;
    bcolor(bColor);
    Terminal.enableCursor(false);
    GFX.clear();
    //Terminal.clear();
    tc.setCursorPos(1, 1);
    Terminal.enableCursor(Cursor);
    Terminal.println();
    return 0;
  }

  int lua_vga_cursor_onoff(lua_State* L) {
    //bool cur = true; // Fallback Cursor immer an
    if (lua_isboolean(L, 1)) {
      Cursor = lua_toboolean(L, 1);
    }
    Terminal.enableCursor(Cursor);
    lua_pushboolean(L, Cursor);
    return 1;
  }

  void drawing_text(int fnt, int x_text, int y_text, const char* tempstring)
  {
    switch (fnt) {
      case 0:
        GFX.drawText(&fabgl::FONT_8x8, x_text, y_text, tempstring);
        break;
      case 1:
        GFX.drawText(&fabgl::FONT_5x8, x_text, y_text, tempstring);
        break;
      case 2:
        GFX.drawText(&fabgl::FONT_6x8, x_text, y_text, tempstring);
        break;
      case 3:
        GFX.drawText(&fabgl::FONT_LCD_8x14, x_text, y_text, tempstring);
        break;
      case 4:
        GFX.drawText(&fabgl::FONT_10x20, x_text, y_text, tempstring);
        break;
      case 5:
        GFX.drawText(&fabgl::FONT_BLOCK_8x14, x_text, y_text, tempstring);
        break;
      case 6:
        GFX.drawText(&fabgl::FONT_BROADWAY_8x14, x_text, y_text, tempstring);
        break;
      case 7:
        GFX.drawText(&fabgl::FONT_OLDENGL_8x16, x_text, y_text, tempstring);
        break;
      case 8:
        GFX.drawText(&fabgl::FONT_BIGSERIF_8x16, x_text, y_text, tempstring);
        break;
      case 9:
        GFX.drawText(&fabgl::FONT_SANSERIF_8x14, x_text, y_text, tempstring);
        break;
      case 10:
        GFX.drawText(&fabgl::FONT_COURIER_8x14, x_text, y_text, tempstring);
        break;
      case 11:
        GFX.drawText(&fabgl::FONT_SLANT_8x14, x_text, y_text, tempstring);
        break;
      case 12:
        GFX.drawText(&fabgl::FONT_WIGGLY_8x16, x_text, y_text, tempstring);
        break;
      case 13:
        GFX.drawText(&fabgl::FONT_6x10, x_text, y_text, tempstring);
        break;
      case 14:
        GFX.drawText(&fabgl::FONT_BIGSERIF_8x14, x_text, y_text, tempstring);
        break;
      case 15:
        GFX.drawText(&fabgl::FONT_4x6, x_text, y_text, tempstring);
        break;
      case 16:
        GFX.drawText(&fabgl::FONT_6x12, x_text, y_text, tempstring);
        break;
      case 17:
        GFX.drawText(&fabgl::FONT_7x13, x_text, y_text, tempstring);
        break;
      case 18:
        GFX.drawText(&fabgl::FONT_7x14, x_text, y_text, tempstring);
        break;
      case 19:
        GFX.drawText(&fabgl::FONT_8x9, x_text, y_text, tempstring);
        break;
      case 20:
        GFX.drawText(&fabgl::FONT_COMPUTER_8x14, x_text, y_text, tempstring);
        break;
      case 21:
        GFX.drawText(&fabgl::FONT_SANSERIF_8x14, x_text, y_text, tempstring);
        break;
      case 22:
        GFX.drawText(&fabgl::FONT_6x10, x_text, y_text, tempstring);
        break;
      case 23:
        GFX.drawText(&fabgl::FONT_9x15, x_text, y_text, tempstring);
        break;
      case 24:
        GFX.drawText(&fabgl::FONT_8x16, x_text, y_text, tempstring);
        break;
      case 25:
        GFX.drawText(&fabgl::FONT_8x8_PET, x_text, y_text, tempstring);
        break;
      default:
        GFX.drawText(&fabgl::FONT_6x8, x_text, y_text, tempstring);
        break;
    }

  }
  // 3. vga.text([spalte, zeile,] "Text" [, fcolor, bcolor, font])
  int lua_vga_text(lua_State* L) {
    int argumente = lua_gettop(L);
    int spalte = 0;
    int zeile = 0;
    const char* txt = NULL;

    int txtFColor = fColor;
    int txtBColor = bColor;
    int fontsatz = current_Font; // Standardwert: Systemfont

    // FALL 1: Es wurden mindestens 3 Argumente uebergeben (spalte, zeile, "text" ...)
    if (argumente >= 3 && lua_isnumber(L, 1) && lua_isnumber(L, 2) && lua_isstring(L, 3)) {
      spalte = (int)lua_tonumber(L, 1);
      zeile = (int)lua_tonumber(L, 2);
      txt = lua_tostring(L, 3);

      // Optionale Farben auswerten (liegen bei 4 und 5)
      if (argumente >= 4 && lua_isnumber(L, 4)) txtFColor = (int)lua_tonumber(L, 4);
      if (argumente >= 5 && lua_isnumber(L, 5)) txtBColor = (int)lua_tonumber(L, 5);
      if (argumente >= 6 && lua_isnumber(L, 6)) fontsatz = (int)lua_tonumber(L, 6);

    }
    // FALL 2: Es wurde nur der Text uebergeben (Nutzt aktuelle Cursor-Position)
    else if (argumente >= 1 && lua_isstring(L, 1)) {
      txt = lua_tostring(L, 1);

      // Optionale Farben und Fontsatz auswerten
      if (argumente >= 2 && lua_isnumber(L, 2)) txtFColor = (int)lua_tonumber(L, 2);
      if (argumente >= 3 && lua_isnumber(L, 3)) txtBColor = (int)lua_tonumber(L, 3);
      if (argumente >= 4 && lua_isnumber(L, 6)) fontsatz = (int)lua_tonumber(L, 4);
    }
    else {
      Terminal.print("FEHLER: vga.text(x,y,text,[fcol,bcol,font])");
      lua_pushboolean(L, false);
      return 1;
    }

    // --- 1. Text direkt auf die VGA-Karte zeichnen ---
    fbcolor(txtFColor, txtBColor);
    drawing_text(fontsatz, spalte * x_char[fontsatz], zeile * y_char[fontsatz] , txt);                                 //Anpassung , nicht pixelgenau sondern spalten und zeilenbasiert
    fbcolor(fColor, bColor);
    lua_pushboolean(L, true);
    return 1;
  }




  // 4. Pixel zeichnen: vga.pset(x, y, farbe)
  int lua_vga_pset(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2) || !lua_isnumber(L, 3)) {
      Terminal.print("FEHLER: vga.pset(x, y, farbe) erwartet 3 Zahlen!");
      lua_pushboolean(L, false);
      return 1;
    }
    int x = (int)lua_tonumber(L, 1);
    int y = (int)lua_tonumber(L, 2);
    int farbe = (int)lua_tonumber(L, 3);

    fcolor(farbe);
    GFX.setPixel(x, y);
    fcolor(fColor);
    return 0;
  }

  // 5. Rechteck zeichnen: vga.box(x, y, w, h, farbe)
  int lua_vga_box(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2) || !lua_isnumber(L, 3) || !lua_isnumber(L, 4)) {
      Terminal.print("FEHLER: vga.box(x1, y1, w, h [, farbe]) erwartet mindestens 4 Zahlen!");
      lua_pushboolean(L, false);
      return 1;
    }
    int x1 = (int)lua_tonumber(L, 1);
    int y1 = (int)lua_tonumber(L, 2);
    int w2 = (int)lua_tonumber(L, 3);
    int h2 = (int)lua_tonumber(L, 4);

    int rColor = bColor;
    if (lua_gettop(L) >= 5 && lua_isnumber(L, 5)) rColor = (int)lua_tonumber(L, 5);
    bcolor(rColor);
    GFX.fillRectangle(x1, y1, x1 + w2, y1 + h2);
    bcolor(bColor);
    return 0;
  }

  // 6. LEERES RECHTECK (vga.rect): 4-Linien-Methode
  int lua_vga_rect(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2) || !lua_isnumber(L, 3) || !lua_isnumber(L, 4)) {
      Terminal.print("FEHLER: vga.rect(x1, y1, w2, h2 [, farbe]) erwartet mindestens 4 Zahlen!");
      lua_pushboolean(L, false);
      return 1;
    }
    int x1 = (int)lua_tonumber(L, 1);
    int y1 = (int)lua_tonumber(L, 2);
    int w2 = (int)lua_tonumber(L, 3);
    int h2 = (int)lua_tonumber(L, 4);

    // Standardwert aus globaler Variable laden
    int rColor = fColor;
    if (lua_gettop(L) >= 5 && lua_isnumber(L, 5)) rColor = (int)lua_tonumber(L, 5);
    fcolor(rColor);
    GFX.drawRectangle(x1, y1, x1 + w2, y1 + h2);
    fcolor(fColor);
    return 0;
  }

  // 7. Gefuellte Ellipse: vga.filledellipse(x, y, w, h [bcolor])
  int lua_vga_filledellipse(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2) || !lua_isnumber(L, 3) || !lua_isnumber(L, 4)) {
      Terminal.print("FEHLER: vga.fillellipse(x, y, w, h [, bcolor])");
      lua_pushboolean(L, false);
      return 1;
    }
    int x = (int)lua_tonumber(L, 1);
    int y = (int)lua_tonumber(L, 2);
    int w = (int)lua_tonumber(L, 3);
    int h = (int)lua_tonumber(L, 4);

    // Standardwerte aus globalen Variablen laden
    int ellBColor = bColor;

    // Optionale Farben überschreiben, falls vom Benutzer in Lua übergeben
    if (lua_gettop(L) >= 5 && lua_isnumber(L, 5)) ellBColor = (int)lua_tonumber(L, 5);
    bcolor(ellBColor);
    GFX.fillEllipse(x, y, w, h);
    bcolor(bColor);
    return 0;
  }

  // 8. Leere Ellipse: vga.ellipse(x, y, w, h [, fcolor])
  int lua_vga_ellipse(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2) || !lua_isnumber(L, 3) || !lua_isnumber(L, 4)) {
      Terminal.print("FEHLER: vga.ellipse(x, y, w, h [fcolor]) ");
      lua_pushboolean(L, false);
      return 1;
    }
    int x = (int)lua_tonumber(L, 1);
    int y = (int)lua_tonumber(L, 2);
    int w = (int)lua_tonumber(L, 3);
    int h = (int)lua_tonumber(L, 4);
    int ellFColor = fColor;

    if (lua_gettop(L) >= 5 && lua_isnumber(L, 5)) ellFColor = (int)lua_tonumber(L, 5);
    fcolor(ellFColor);
    GFX.drawEllipse(x, y, w, h);
    fcolor(fColor);
    return 0;
  }

  // 9. EINE EINZELNE LINIE (vga.line(x1, y1, x2, y2 [, farbe])
  int lua_vga_line(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2) || !lua_isnumber(L, 3) || !lua_isnumber(L, 4)) {
      Terminal.print("FEHLER: vga.line(x1, y1, x2, y2 [, farbe]) erwartet mindestens 4 Zahlen!");
      lua_pushboolean(L, false);
      return 1;
    }
    int x1 = (int)lua_tonumber(L, 1);
    int y1 = (int)lua_tonumber(L, 2);
    int x2 = (int)lua_tonumber(L, 3);
    int y2 = (int)lua_tonumber(L, 4);

    int lColor = fColor;
    if (lua_gettop(L) >= 5 && lua_isnumber(L, 5)) lColor = (int)lua_tonumber(L, 5);
    fcolor(lColor);
    GFX.drawLine(x1, y1, x2, y2);                          //Line line x,y,xx,yy
    fcolor(fColor);
    return 0;
  }

  //10. vga.pos(spalte, zeile) zum Setzen der Cursor-Position auf der Konsole
  int lua_vga_pos(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2)) {
      Terminal.print("FEHLER: vga.pos(spalte, zeile)");
      lua_pushboolean(L, false);
      return 1;
    }

    int spalte = (int)lua_tonumber(L, 1);
    int zeile = (int)lua_tonumber(L, 2);

    // Grenzen absichern, damit der Cursor nicht außerhalb des Bildschirms landet
    if (spalte < 0) spalte = 0;
    if (spalte >= MAX_C) spalte = MAX_C - 1;
    if (zeile < 0) zeile = 0;
    if (zeile >= MAX_R) zeile = MAX_R - 1;

    //cursorX = spalte;
    //cursorY = zeile;
    tc.setCursorPos(spalte, zeile);
    return 0;
  }

  int lua_vga_get_colors(lua_State* L) {
    // Die Werte auf den Lua-Stack legen
    lua_pushinteger(L, fColor); // Erster Rückgabewert (fColor)
    lua_pushinteger(L, bColor); // Zweiter Rückgabewert (bColor)
    return 2; //2 Werte zurückgeben
  }

  // Lua Funktion vga.waitsync()
  int lua_vga_wait_vsync(lua_State* L) {
    GFX.waitCompletion(false);
    return 0;
  }


  void saveScreenRegion(Rect rect) {
    // Falls noch ein altes Backup existiert (Sicherheitshalber), freigeben
    if (globalScreenBackup != nullptr) {
      free(globalScreenBackup);
      globalScreenBackup = nullptr;
    }
    globalBackupRect = rect;
    uint32_t totalPixels = rect.width() * rect.height();
    globalScreenBackup = (RGB222*)ps_malloc(totalPixels * sizeof(RGB222));
    Terminal.enableCursor(false); // Cursor kurz aus
    VGAController.readScreen(rect, globalScreenBackup);
    Terminal.enableCursor(Cursor);
  }

  // Stellt den Bereich mittels writeScreen und Versatz wieder her
  void restoreScreenRegion(int x, int y) {
    if (globalScreenBackup != nullptr) {
      Terminal.enableCursor(false);
      VGAController.writeScreen(globalBackupRect.translate(x, y), globalScreenBackup);
      free(globalScreenBackup);
      globalScreenBackup = nullptr;
      Terminal.enableCursor(Cursor);
    }
  }



  // 1. Fenster öffnen und exakt den Bereich DARUNTER im Slot-Puffer sichern
  int lua_vga_open_window(lua_State* L) {
    int idx = luaL_checkinteger(L, 1);
    if (idx < 0 || idx > 7) return 0;

    // Slot-Daten belegen
    windowManager[idx].x = luaL_checkinteger(L, 2);
    windowManager[idx].y = luaL_checkinteger(L, 3);
    windowManager[idx].w = luaL_checkinteger(L, 4);
    windowManager[idx].h = luaL_checkinteger(L, 5);
    windowManager[idx].fc = luaL_checkinteger(L, 6);
    windowManager[idx].bc = luaL_checkinteger(L, 7);
    windowManager[idx].titel = String(luaL_checkstring(L, 8));
    windowManager[idx].inhalt = String(luaL_checkstring(L, 9));
    windowManager[idx].titelFarbe = luaL_checkinteger(L, 10);
    windowManager[idx].aktiv = true;
    Window_aktiv = true;

    // ================= NEU: NUR DEN BEREICH DIESES FENSTERS SICHERN =================
    // Falls der Slot (z.B. durch ein altes Skript) noch belegt war, alten Speicher freigeben
    if (windowManager[idx].screenBackup != nullptr) {
      free(windowManager[idx].screenBackup);
    }

    // Wir definieren das exakte Rechteck, das dieses Fenster belegen wird
    windowManager[idx].savedRect = Rect(windowManager[idx].x, windowManager[idx].y,
                                        windowManager[idx].x + windowManager[idx].w,
                                        windowManager[idx].y + windowManager[idx].h);

    uint32_t totalPixels = windowManager[idx].savedRect.width() * windowManager[idx].savedRect.height();

    // Speicher passgenau im PSRAM allokieren
    windowManager[idx].screenBackup = (RGB222*)ps_malloc(totalPixels * sizeof(RGB222));

    if (windowManager[idx].screenBackup != nullptr) {
      Terminal.enableCursor(false);
      // Wir fotografieren NUR die Pixel, die JETZT an dieser Stelle stehen!
      VGAController.readScreen(windowManager[idx].savedRect, windowManager[idx].screenBackup);
      Terminal.enableCursor(Cursor);
    }
    // =================================================================================


    // Fenster physisch zeichnen
    renderWindow(windowManager[idx].x, windowManager[idx].y, windowManager[idx].w, windowManager[idx].h,
                 windowManager[idx].fc, windowManager[idx].bc, windowManager[idx].titel.c_str(),
                 windowManager[idx].inhalt.c_str(), windowManager[idx].titelFarbe);
    return 0;
  }

  // 2. Fenster-Inhalt aktualisieren mittels lokalem Slot-Buffer
  int lua_vga_update_window(lua_State* L) {
    int idx = luaL_checkinteger(L, 1);
    if (idx < 0 || idx > 7 || !windowManager[idx].aktiv) return 0;

    const char* neuerInhalt = luaL_checkstring(L, 2);
    windowManager[idx].inhalt = String(neuerInhalt);

    // ================= INDIVIDUELLE RESTAURIERUNG =================
    if (windowManager[idx].screenBackup != nullptr) {
      Terminal.enableCursor(false);
      // Wir stellen exakt den Zustand vor dem Öffnen dieses EINEN Fensters wieder her
      VGAController.writeScreen(windowManager[idx].savedRect, windowManager[idx].screenBackup);
      Terminal.enableCursor(Cursor);
    }

    // neuen Inhalt zeichnen
    renderWindow(windowManager[idx].x, windowManager[idx].y, windowManager[idx].w, windowManager[idx].h,
                 windowManager[idx].fc, windowManager[idx].bc, windowManager[idx].titel.c_str(),
                 windowManager[idx].inhalt.c_str(), windowManager[idx].titelFarbe);

    return 0;
  }

  // 3. Nur das ausgewählte Fenster schließen und seinen Hintergrund reparieren
  int lua_vga_close_window(lua_State* L) {
    int idx = luaL_checkinteger(L, 1);
    if (idx < 0 || idx > 7 || !windowManager[idx].aktiv) return 0;

    // ================= LOKALEN SPEICHERBEREICH RESTAURIEREN =================
    if (windowManager[idx].screenBackup != nullptr) {
      Terminal.enableCursor(false);
      // Hintergrund pixelgenau zurückschreiben
      VGAController.writeScreen(windowManager[idx].savedRect, windowManager[idx].screenBackup);
      Terminal.enableCursor(Cursor);

      // PSRAM für diesen Slot sofort wieder freigeben!
      free(windowManager[idx].screenBackup);
      windowManager[idx].screenBackup = nullptr;
    }

    windowManager[idx].aktiv = false;

    // Prüfen, ob überhaupt noch irgendein Fenster aktiv ist
    bool einsNochAktiv = false;
    for (int i = 0; i < 8; i++) {
      if (windowManager[i].aktiv) einsNochAktiv = true;
    }
    if (!einsNochAktiv) Window_aktiv = false;

    return 0;
  }

  // 4. Automatische Reinigung (wichtig bei Skript-Abbruch von Lua)
  void cleanupWindows() {
    // Wir laufen rückwärts (von Slot 7 zu 0) durch, um überlappende Fenster
    // in der korrekten Reihenfolge von oben nach unten abzubauen!
    for (int idx = 7; idx >= 0; idx--) {
      if (windowManager[idx].aktiv) {
        if (windowManager[idx].screenBackup != nullptr) {
          Terminal.enableCursor(false);
          VGAController.writeScreen(windowManager[idx].savedRect, windowManager[idx].screenBackup);
          Terminal.enableCursor(Cursor);

          free(windowManager[idx].screenBackup);
          windowManager[idx].screenBackup = nullptr;
        }
        windowManager[idx].aktiv = false;
      }
    }
    Window_aktiv = false;
  }



  // Unterfunktion Window zeichnen
  // Universelle C++ Funktion zum Zeichnen eines Fensters mit automatischem Textumbruch
  void renderWindow(int x, int y, int w, int h, int fc, int bc, const char* titel, const char* inhalt, uint16_t titelFarbe) {
    fbcolor(fc, bc);
    GFX.fillRectangle(x, y, x + w, y + h);
    GFX.drawRectangle(x, y, x + w, y + h);
    fbcolor(fc, titelFarbe);
    delay(1);
    GFX.fillRectangle(x + 1, y + 1, x + w - 1, y + 14);
    GFX.drawText(&fabgl::FONT_6x8, x + 10, y + 5, titel, false);

    int textStartX = x + 10;
    int textStartY = y + 25;
    int aktuelleX = textStartX;
    int aktuelleY = textStartY;

    int zeichenBreite = x_char[current_Font];
    int zeilenHoehe = y_char[current_Font];
    int maxTextBreite = w - 25;
    String textKopie = String(inhalt);
    char* textPtr = const_cast<char*>(textKopie.c_str());
    char* wort = strtok(textPtr, " \t\n\r");
    fbcolor(fc, bc);
    while (wort != NULL) {
      int wortLaenge = strlen(wort);
      int wortBreitePixel = wortLaenge * zeichenBreite;

      if (aktuelleX + wortBreitePixel > textStartX + maxTextBreite && aktuelleX > textStartX) {
        aktuelleX = textStartX;
        aktuelleY += zeilenHoehe;
      }

      if (aktuelleY + zeilenHoehe > y + h - 5) {
        GFX.drawText(&fabgl::FONT_6x8, aktuelleX, aktuelleY, "...", false);
        break;
      }
      GFX.drawText(&fabgl::FONT_6x8, aktuelleX, aktuelleY, wort, false);
      aktuelleX += wortBreitePixel + zeichenBreite;
      wort = strtok(NULL, " \t\n\r");
    }
    GFX.waitCompletion(false);
  }

  //------------------------------ vga.bmpLoad(x,y,datei,skal) ---------------------------------
  // Lua-Befehl vga.bmpload(dateiname)
  int lua_vga_bmpload(lua_State* L) {
    // 1. Parameter aus Lua holen
    int x_offset = luaL_checkinteger(L, 1);
    int y_offset = luaL_checkinteger(L, 2);
    const char* dateiname = luaL_checkstring(L, 3);
    float sc = (float)luaL_optnumber(L, 4, 1.0f);

    String fullPath = resolve_lua_path(dateiname);

    if (!SD.exists(fullPath.c_str())) {
      Terminal.print("DATEI FEHLER");
      lua_pushboolean(L, false);
      return 1;
    }

    File fp = SD.open(fullPath.c_str(), FILE_READ);
    if (!fp) {
      lua_pushboolean(L, false);
      return 1;
    }

    uint8_t bmp_header[54];
    if (fp.read(bmp_header, 54) != 54 || bmp_header[0] != 0x42 || bmp_header[1] != 0x4D) {
      Terminal.print("Ungueltiges BMP-Format.");
      fp.close();
      lua_pushboolean(L, false);
      return 1;
    }

    int vh = 320;
    int vv = 240;

    // Header-Bytes fehlerfrei extrahieren
    uint32_t xx = bmp_header[18] | ((uint32_t)bmp_header[19] << 8) | ((uint32_t)bmp_header[20] << 16) | ((uint32_t)bmp_header[21] << 24);
    uint32_t yy = bmp_header[22] | ((uint32_t)bmp_header[23] << 8) | ((uint32_t)bmp_header[24] << 16) | ((uint32_t)bmp_header[25] << 24);
    uint32_t bmpImageoffset = bmp_header[10] | ((uint32_t)bmp_header[11] << 8) | ((uint32_t)bmp_header[12] << 16) | ((uint32_t)bmp_header[13] << 24);

    uint32_t rowSize = (xx * 3 + 3) & ~3;

    // --- ANPASSUNG FÜR DIE KORREKTE LUA-SKALIERUNG ---
    // Wir nutzen den übergebenen Skalierungsfaktor sc direkt.
    // Ein Faktor von 0.25 verkleinert das Bild auf 1/4 der Größe.
    if (sc <= 0.0f) sc = 1.0f; // Sicherheits-Fallback

    // Berechnen der Schrittweiten im Originalbild
    float xtmp = 1.0f / sc;
    float ytmp = 1.0f / sc;

    // Zielgrößen auf dem VGA-Bildschirm ermitteln
    int targetWidth  = (int)((float)xx * sc);
    int targetHeight = (int)((float)yy * sc);

    // Verhindern, dass über den physikalischen Bildschirmrand gezeichnet wird
    if (targetWidth > vh) targetWidth = vh;
    if (targetHeight > vv) targetHeight = vv;
    // --------------------------------------------------

    // OPTIMIERUNG 1: Zeilenpuffer auf dem Ultraschnellen Stack anlegen
    uint8_t* rowBuffer = (uint8_t*)alloca(rowSize);

    // OPTIMIERUNG 2: Fixed-Point Arithmetik (16.16) für die X-Schleife
    uint32_t fp_xtmp = (uint32_t)(xtmp * 65536.0f);

    for (int row = 0; row < targetHeight; row++) {
      // Schrittweite ytmp wird auf die Zeile angewendet, um die Y-Position im Originalbild zu finden
      int sourceY = (int)yy - 1 - (int)((float)row * ytmp);
      if (sourceY < 0) break;
      if (sourceY >= (int)yy) continue; // Sicherheitsprüfung

      // OPTIMIERUNG 3: Nur EIN EINZIGER Seek pro Zeile!
      uint32_t rowStartPos = bmpImageoffset + (sourceY * rowSize);
      fp.seek(rowStartPos);
      fp.read(rowBuffer, rowSize); // Gesamte Zeile am Stück streamen

      int sy = row + y_offset;
      if (sy < 0 || sy >= vv) continue; // Außerhalb des vertikalen Bildschirms? Überspringen.

      uint32_t fp_sourceX = 0; // Fixed-Point Zähler für X

      for (int col = 0; col < targetWidth; col++) {
        uint32_t sourceX = fp_sourceX >> 16; // Zurück in echten Integer wandeln
        if (sourceX >= xx) break;

        int sx = col + x_offset;
        if (sx >= 0 && sx < vh) {
          // Pixel-Adresse im Zeilenpuffer direkt berechnen (3 Bytes pro Pixel: B, G, R)
          uint32_t bufIdx = sourceX * 3;
          uint8_t farbNummer = ((rowBuffer[bufIdx + 2] & 0xC0) >> 2) |  // Rot:   Die obersten 2 Bits -> Bits 4 und 5
                               ((rowBuffer[bufIdx + 1] & 0xC0) >> 4) |  // Grün:  Die obersten 2 Bits -> Bits 2 und 3
                               ((rowBuffer[bufIdx]     & 0xC0) >> 6);   // Blau:  Die obersten 2 Bits -> Bits 0 und 1
          /*
            // Bit-Schieben und Maskieren direkt aus dem RAM-Puffer
            uint8_t farbNummer = (rowBuffer[bufIdx + 2] & 0xE0) |
                               ((rowBuffer[bufIdx + 1] & 0xE0) >> 3) |
                               (rowBuffer[bufIdx] >> 6);
          */
          fcolor(farbNummer);
          GFX.setPixel(sx, sy);
          fcolor(fColor);
          //GFX.drawPixel(sx, sy, farbNummer);
        }

        fp_sourceX += fp_xtmp; // In 16.16 Schritten weiterzählen
      }
    }

    fp.close();
    lua_pushboolean(L, true);
    return 1;
  }


  //---------------------- Lua-Befehl vga.bmpSave(x,y,w,h,Dateiname) ----------------------------------------

  // universelle Screenshot-Funktion für Lua und internes Programm
  bool speichere_bildschirm_als_bmp(int x_start, int y_start, int w, int h, const char* dateiname) {
    if (w <= 0 || h <= 0) return false;

    // 1. Basis-Dateinamen und Endung trennen (z.B. "screenshot.bmp" -> "screenshot" und ".bmp")
    char baseName[64] = {0};
    char extension[16] = {".bmp"};

    String origName = String(dateiname);
    int dotIndex = origName.lastIndexOf('.');

    if (dotIndex != -1) {
      snprintf(baseName, sizeof(baseName), "%s", origName.substring(0, dotIndex).c_str());
      snprintf(extension, sizeof(extension), "%s", origName.substring(dotIndex).c_str());
    } else {
      snprintf(baseName, sizeof(baseName), "%s", dateiname);
    }

    // 2. Freie fortlaufende Nummer auf der SD-Karte suchen
    String finalPath;
    char nummerierteDatei[128];
    int counter = 0;
    bool dateiGefunden = false;

    while (!dateiGefunden) {
      if (counter == 0) {

        snprintf(nummerierteDatei, sizeof(nummerierteDatei), "%s%s", baseName, extension);                // erster Versuch test Originalnamen ohne Nummer
      } else {

        snprintf(nummerierteDatei, sizeof(nummerierteDatei), "%s_%02d%s", baseName, counter, extension);  // zweistellige Nummer anhängen (z.B. _01, _02)
      }
      finalPath = resolve_lua_path(nummerierteDatei);                                                     // Pfad mit Resolver vervollständigen

      if (!SD.exists(finalPath.c_str())) {                                                                // Wenn die Datei noch NICHT existiert, freie Nummer gefunden!
        dateiGefunden = true;
      } else {
        counter++;                                                                                        // Weiterzählen und nächste Nummer prüfen

        if (counter > 99) {                                                                               // maximal 99 Einträge
          Terminal.println("FEHLER:Max.Anzahl 99");
          return false;
        }
      }
    }
    // 3. Datei im Schreibmodus öffnen
    File fp = SD.open(finalPath.c_str(), FILE_WRITE);
    if (!fp) {
      Terminal.println("FEHLER:Dateifehler");
      return false;
    }

    // 4. Windows-BMP Header berechnen (4-Byte-Padding)
    uint32_t rowSize = (w * 3 + 3) & ~3;
    uint32_t paddingBytes = rowSize - (w * 3);
    uint32_t fileSize = 54 + (rowSize * h);

    uint8_t bmp_header[54] = {
      0x42, 0x4D,             // 'B' 'M'
      (uint8_t)(fileSize), (uint8_t)(fileSize >> 8), (uint8_t)(fileSize >> 16), (uint8_t)(fileSize >> 24),
      0x00, 0x00, 0x00, 0x00,
      54, 0x00, 0x00, 0x00,
      40, 0x00, 0x00, 0x00,
      (uint8_t)(w), (uint8_t)(w >> 8), (uint8_t)(w >> 16), (uint8_t)(w >> 24),
      (uint8_t)(h), (uint8_t)(h >> 8), (uint8_t)(h >> 16), (uint8_t)(h >> 24),
      0x01, 0x00,
      24, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x13, 0x0B, 0x00, 0x00,
      0x13, 0x0B, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00
    };

    fp.write(bmp_header, 54);

    uint8_t pixelBuf[3];
    uint8_t padBuf[3] = {0x00, 0x00, 0x00};

    // Pixel auslesen und von unten nach oben in die Datei schreiben
    for (int row = h - 1; row >= 0; row--) {
      int currentY = y_start + row;

      for (int col = 0; col < w; col++) {
        int currentX = x_start + col;

        uint8_t farbNummer = 0;
        if (currentX >= 0 && currentX < (MAX_C * x_char[current_Font]) && currentY >= 0 && currentY < (MAX_R * y_char[current_Font])) {
          pixelBuf[2] = GFX.getPixel(currentX, currentY).R;
          pixelBuf[1] = GFX.getPixel(currentX, currentY).G;
          pixelBuf[0] = GFX.getPixel(currentX, currentY).B;
        }

        // 6-Bit RRGGBB (64 Farben) zurück in 24-Bit BGR übersetzen
        //pixelBuf[2] = (farbNummer & 0x30) << 2;  // R:
        //pixelBuf[1] = (farbNummer & 0x0C) << 4;  // G:
        //pixelBuf[0] = (farbNummer & 0x03) << 6;  // B:

        // 8-Bit RRRGGGBB zurück in 24-Bit BGR übersetzen
        //pixelBuf[2] = (farbNummer & 0xE0);          // R
        //pixelBuf[1] = (farbNummer & 0x1C) << 3;     // G
        //pixelBuf[0] = (farbNummer & 0x03) << 6;     // B

        fp.write(pixelBuf, 3);
      }

      if (paddingBytes > 0) {
        fp.write(padBuf, paddingBytes);
      }
    }

    fp.flush();
    fp.close();

    return true;
  }

  // Lua-Befehl vga.bmpSave(x,y,w,h,Dateiname)
  int lua_vga_bmpsave(lua_State* L) {
    int x_start = luaL_checkinteger(L, 1);
    int y_start = luaL_checkinteger(L, 2);
    int w = luaL_checkinteger(L, 3);
    int h = luaL_checkinteger(L, 4);
    const char* dateiname = luaL_checkstring(L, 5);

    bool erfolg = speichere_bildschirm_als_bmp(x_start, y_start, w, h, dateiname);
    lua_pushboolean(L, erfolg);
    return 1;
  }

  // ============================================================================
  // LUA - FULLSCREEN-EDITOR
  // ============================================================================
  // Hilfsfunktion: Zeichnet den gesamten RAM-Puffer auf das FabGL VGA-Terminal
  // Hilfsfunktion: Aktualisiert NUR die Statuszeile, ohne das Bild neu zu zeichnen
  void updateStatusLine(uint32_t currentPos) {
    uint32_t line = 1;
    uint32_t col = 1;
    int x_pos = tc.getCursorCol();
    int y_pos = tc.getCursorRow();
    Terminal.enableCursor(false);

    // Berechne Zeile und Spalte anhand der übergebenen Position direkt aus dem RAM
    for (uint32_t i = 0; i < currentPos; i++) {
      if (textBuffer[i] == '\n') { // ZURÜCK AUF RAM
        line++;
        col = 1;
      } else {
        col++;
      }
    }
    tc.setCursorPos(1, MAX_R);
    fbcolor(0, 15); // Blauer/Schwarzer Text auf Cyan-Grund

    Terminal.write("\x1b[K"); // Komplette Zeile mit Hintergrundfarbe füllen
    Terminal.printf(" Zeile: %d Spalte: %d | Speicher: %d Bytes ", line, col, textLen);
    GFX.waitCompletion(false);

    fbcolor(63, 1); // Zurück zu Ihrem Farbschema für den Schreibbereich
    tc.setCursorPos(x_pos, y_pos);
    Terminal.enableCursor(Cursor);
  }
  void drawTitleBar(char* titletext) {
    fbcolor(0, 15);

    tc.setCursorPos(1, 1);
    Terminal.write("\x1b[K");                                              //komplette Zeile mit weissem Hintergrund
    Terminal.print(titletext);
    GFX.waitCompletion(false);
    fbcolor(63, 1);
  }

  void drawStatusBar(char* statusb) {
    fbcolor(0, 15);

    int ypix = (MAX_R - 1) * 8;
    tc.setCursorPos(0, MAX_R);
    Terminal.write("\x1b[K");                                              //komplette Zeile mit weissem Hintergrund
    Terminal.print(statusb);
    GFX.waitCompletion(false);
    fbcolor(63, 1);
  }


  void drawTitleLine() {
    Terminal.enableCursor(false);
    tc.setCursorPos(1, 1);
    fbcolor(0, 15);
    delay(2);
    tc.setCursorPos(1, 1);
    Terminal.write("\x1b[K");                                              //komplette Zeile mit weissem Hintergrund
    Terminal.printf("ESC=Menu F2:Copy F3:Paste Datei:%s" , currentEditingFilename);
    GFX.waitCompletion(false);
    fbcolor(63, 1);
    tc.setCursorPos(1, 2);
    Terminal.enableCursor(Cursor);
  }

  // Hauptfenster - TitelBar zeichnen
  int lua_vga_set_title(lua_State* L) {
    const char* neuerTitel = luaL_checkstring(L, 1);
    drawTitleBar((char*)neuerTitel);
    return 0;
  }

  // Hauptfenster - TitelBar zeichnen
  int lua_vga_set_status(lua_State* L) {
    const char* neuerTitel = luaL_checkstring(L, 1);
    drawStatusBar((char*)neuerTitel);
    return 0;
  }



  void redrawScreen() {
    int x_pos = tc.getCursorCol();
    int y_pos = tc.getCursorRow();
    Terminal.enableCursor(false);
    //drawTitleLine();
    //fbcolor(63, 1);
    GFX.fillRectangle(0, 8, MAX_C * 6, (MAX_R * 8) - 8); // Editor-Bereich löschen
    tc.setCursorPos(1, 2);

    uint32_t i = topIndex;
    int vgaZeile = 2;

    // Wir laufen zeilenweise durch das Dokument, bis der Bildschirm voll oder das Dokument zu Ende ist
    while (i < textLen && vgaZeile <= (MAX_R - 1) ) {
      // 1. Das Ende der aktuellen Zeile im PSRAM suchen
      uint32_t lineEnd = i;
      while (lineEnd < textLen && textBuffer[lineEnd] != '\n' && textBuffer[lineEnd] != '\r') {
        lineEnd++;
      }
      uint32_t lineLen = lineEnd - i; // Gesamtlänge der ungeschnittenen Zeile
      if (lineLen >= leftColumn) {
        uint32_t visibleStart = i + (leftColumn - 1); // Startpunkt im PSRAM verschieben
        uint32_t visibleLen = lineLen - (leftColumn - 1);
        if (visibleLen > MAX_C) visibleLen = MAX_C;        // Abschneiden am rechten Bildschirmrand
        Terminal.write(&textBuffer[visibleStart], visibleLen);
      }
      Terminal.println();
      vgaZeile++;

      // Zeiger im PSRAM über den Zeilenumbruch hinwegbewegen
      i = lineEnd;
      if (i < textLen && textBuffer[i] == '\r') i++;
      if (i < textLen && textBuffer[i] == '\n') i++;
    }
    updateStatusLine(textLen);
    tc.setCursorPos(x_pos, y_pos);
    Terminal.enableCursor(Cursor);
  }


  void EditorMenue() {
    int x_pos = tc.getCursorCol();
    int y_pos = tc.getCursorRow();
    Terminal.enableCursor(false);
    tc.setCursorPos(1, 2);
    fbcolor(0, 15);

    GFX.fillRectangle(0, 8, 110, 55);
    GFX.drawRectangle(1, 9, 109, 54);
    GFX.drawText(&fabgl::FONT_5x8, 5, 15, "ESC-Zurueck");
    GFX.drawLine(5, 25, 105, 25);
    GFX.drawText(&fabgl::FONT_5x8, 5, 30, "S-Speichern & Ende");
    GFX.drawText(&fabgl::FONT_5x8, 5, 40, "Q-Beenden");

    fbcolor(63, 1);
    tc.setCursorPos(x_pos, y_pos);
  }

  int lua_cmd_edit(lua_State *L) {
    bool speichern = false;
    if (lua_gettop(L) >= 1 && lua_isstring(L, 1)) {
      const char* filename = lua_tostring(L, 1);

      if (filename != nullptr && filename[0] != '\0') {

        String sdPath = currentWorkDir + String(filename);
        textLen = 0;
        memset(textBuffer, 0, EDIT_BUFF_SIZE);

        if (SD.exists(sdPath.c_str())) {
          Terminal.printf("Lade %s von SD-Karte...\n\r", filename);
          File sdFile = SD.open(sdPath.c_str(), FILE_READ);

          if (sdFile) {
            while (sdFile.available() && textLen < (EDIT_BUFF_SIZE - 1)) {
              char c = sdFile.read();
              if (c == 0x0D) continue; // Carriage Return überspringen
              textBuffer[textLen++] = c;
            }
            sdFile.close();
          }
        } else {
          // Datei existiert nicht -> neu anlegen
          Terminal.printf("Erstelle neue Datei: %s\n\r", filename);
          vTaskDelay(pdMS_TO_TICKS(500)); // Kurze Anzeige für den Benutzer
        }
        currentEditingFilename = '\0';                                              // alten Dateinamen löschen
        currentEditingFilename = filename;                                        // Dateiname merken für Titelzeile

        speichern = runFullscreenEditor(filename, fehlerZeile);

        if (speichern) {
          File sdFileWrite = SD.open(sdPath.c_str(), FILE_WRITE);
          if (sdFileWrite) {
            // Den gesamten Puffer im RAM in einem einzigen Rutsch hocheffizient schreiben
            sdFileWrite.write((uint8_t*)textBuffer, textLen);
            sdFileWrite.flush();
            sdFileWrite.close();
            Terminal.println("Erfolgreich gespeichert!");

            // ================= AUTOMATISCHE LUA-AUSFÜHRUNG ==========================
            Terminal.println("Starte Programm...");
            vTaskDelay(pdMS_TO_TICKS(300));
            char backupChar = textBuffer[textLen];

            textBuffer[textLen] = '\0';
            int status = luaL_dostring(L, textBuffer);

            fehlerZeile = 1;

            if (status != LUA_OK) {
              const char* roherFehler = lua_tostring(L, -1);
              Terminal.printf("LUA ERROR: %s\n\r", roherFehler);
              String errorMsg = String(roherFehler);
              lua_pop(L, 1);


              int doppelpunktIdx = errorMsg.indexOf(':');

              if (doppelpunktIdx != -1) {
                // Nach dem ersten Doppelpunkt steht die Zeile (z.B. "game.lua:14:")
                String rest = errorMsg.substring(doppelpunktIdx + 1);
                int zweiterDoppelpunkt = rest.indexOf(':');
                if (zweiterDoppelpunkt != -1) {
                  fehlerZeile = rest.substring(0, zweiterDoppelpunkt).toInt();
                }
              }
            }
            textBuffer[textLen] = backupChar;
            // =========================================================================

          } else {
            Terminal.println("FEHLER: Schreibfehler auf SD-Karte!");
          }
        }
      } else {
        Terminal.println("Fehler: fehlender Dateiname!");
      }
    } else {
      Terminal.println("Fehler: fehlender Dateiname!");
    }
    return 0;
  }


  bool runFullscreenEditor(const char* filename, int zielZeile) {
    bool st = false;

    fbcolor(15, 4);
    GFX.clear();
    drawTitleLine();
    tc.setCursorPos(1, 2);
    String sdPath = currentWorkDir + String(filename);
    Terminal.enableCursor(false);
    // ==========================================
    topIndex = zielZeile;
    uint32_t cursorPos = 0;
    int aktuelleZeile = 1;

    // Wenn wir in eine höhere Zeile springen wollen, spulen wir den Puffer vor
    if (zielZeile > 1) {
      while (cursorPos < textLen && aktuelleZeile < zielZeile) {
        if (textBuffer[cursorPos] == '\n') {
          aktuelleZeile++;
        }
        cursorPos++; // cursorPos am Anfang der korrekten Zeile
      }
      // Damit die Zeile nicht am oberen Rand klebt, setzen wir topIndex
      // ein paar Zeilen weiter nach oben (falls möglich) für besseres visuelles Feedback
      int scrollBack = cursorPos;
      int zeilenGefunden = 0;
      while (scrollBack > 0 && zeilenGefunden < 5) { // 5 Zeilen Kontext oben frei lassen
        scrollBack--;
        if (textBuffer[scrollBack] == '\n') {
          zeilenGefunden++;
        }
      }
      topIndex = (scrollBack == 0) ? 0 : (scrollBack + 1);
    } else {
      topIndex = 0;
    }
    int cursorX = 1;
    int cursorY = (zielZeile - aktuelleZeile) + 2;

    // Falls das Zurückscrollen (scrollBack) den topIndex verschoben hat, berechnen wir das exakt:
    if (zielZeile > 1) {
      // ermitteln, in welcher Zeile im sichtbaren Fenster der Cursor stehen muss
      int sichtbareZeile = 1;
      int checkPos = topIndex;
      while (checkPos < cursorPos) {
        if (textBuffer[checkPos] == '\n') sichtbareZeile++;
        checkPos++;
      }
      cursorY = sichtbareZeile + 1; // +1 wegen der Titelzeile ganz oben (Zeile 2)
    }

    // Dem FabGL-Terminal sagen, wo der Cursor blinken soll
    tc.setCursorPos(cursorX, cursorY);
    // ==========================================
    bool editing = true;

    fbcolor(63, 1);
    redrawScreen();
    //tc.setCursorPos(1, 2);

    Cursor = true;
    Terminal.enableCursor(Cursor);                     //vor dem eigentlichen Edit-Vorgang immer Cursor einschalten

    // 2. Tastatur-Hauptschleife
    while (editing) {
      int c = inchar();

      // ESCAPE-Taste (ASCII 27): Menü ODER Pfeiltaste
      if (c == KEY_ESC) {
        EditorMenue();
        while (true) {
          int menuChoice = inchar();
          if (menuChoice == 's' || menuChoice == 'S') {
            File sdFileWrite = SD.open(sdPath.c_str(), FILE_WRITE);
            if (sdFileWrite) {
              sdFileWrite.write((uint8_t*)textBuffer, textLen);
              sdFileWrite.flush();
              sdFileWrite.close();
            }
            st = true;                                            // bei true wird gespeichert
            editing = false;
            break;
          }
          else if (menuChoice == 'q' || menuChoice == 'Q') {
            st = false;
            editing = false;
            break;
          }
          else if (menuChoice == KEY_ESC) {
            drawTitleLine();
            redrawScreen();
            break;
          }

          vTaskDelay(pdMS_TO_TICKS(10));
        }
        if (!editing) break;
      }

      // ================= F2-TASTE: MULTI-ZEILEN BLOCK KOPIEREN =================
      else if (c == KEY_F2) {
        // FALL A: Der Auswahlmodus ist noch NICHT aktiv -> Startpunkt setzen
        if (!selectionModeActive) {
          // Wir messen zum Anfang der aktuellen Zeile zurück, damit wir sauber zeilenweise markieren
          uint32_t lineStart = cursorPos;
          while (lineStart > 0 && textBuffer[lineStart - 1] != '\n') {
            lineStart--;
          }

          blockStartPos = lineStart;
          selectionModeActive = true;

          // Optische Info in der Statuszeile
          tc.setCursorPos(1, MAX_R);
          fbcolor(0, 15); // Cyan
          Terminal.write("\x1b[K  [Block] Start gesetzt.");
          GFX.waitCompletion(false);
          fbcolor(63, 1); // Cyan
          vTaskDelay(pdMS_TO_TICKS(500));
          redrawScreen();
        }
        // FALL B: Der Startpunkt existiert bereits -> Jetzt den gesamten Block kopieren!
        else {
          // Das Ende der aktuellen Zeile suchen, in der der Cursor gerade steht
          uint32_t lineEnd = cursorPos;
          while (lineEnd < textLen && textBuffer[lineEnd] != '\n' && textBuffer[lineEnd] != '\r') {
            lineEnd++;
          }
          if (lineEnd < textLen && textBuffer[lineEnd] == '\n') {
            lineEnd++;  // Das '\n' einschließen
          }

          uint32_t start = blockStartPos;
          uint32_t ende = lineEnd;

          // Falls der Nutzer von unten nach oben markiert hat, drehen wir die Werte um
          if (start > ende) {
            uint32_t temp = start;
            start = ende;
            ende = temp;
          }

          uint32_t blockLen = ende - start;

          // Prüfen, ob der Block in das Clipboard passt
          if (blockLen > 0 && blockLen < (CLIPBOARD_SIZE - 1)) {
            memcpy(clipboardBuffer, &textBuffer[start], blockLen);
            clipboardBuffer[blockLen] = '\0';
            clipboardLen = blockLen;

            // Block-Start-Information für ein eventuelles DEL abspeichern
            blockStartPos = start;

            tc.setCursorPos(1, MAX_R);
            fbcolor(0, 15);
            Terminal.printf("\x1b[K Block (%d Bytes) kopiert! ", clipboardLen);
            GFX.waitCompletion(false);
            vTaskDelay(pdMS_TO_TICKS(500));
            fbcolor(63, 1);
          }

          selectionModeActive = false; // Auswahlmodus beenden
          redrawScreen();
        }
      }

      // ================= F3-TASTE: ZEILE EINFÜGEN (PASTE) =================
      else if (c == KEY_F3) {
        if (clipboardLen > 0 && (textLen + clipboardLen + 1) < (EDIT_BUFF_SIZE - 1)) {
          // 1. Platz im textBuffer schaffen (Kopierter Text + Zeilenumbruch)
          uint32_t insertLen = clipboardLen + 1; // +1 für das '\n'
          memmove(&textBuffer[cursorPos + insertLen], &textBuffer[cursorPos], textLen - cursorPos);
          // 2. Den Text aus dem Clipboard in die Lücke schreiben
          memcpy(&textBuffer[cursorPos], clipboardBuffer, clipboardLen);
          cursorPos += clipboardLen;
          // 3. Den Zeilenumbruch einfügen, damit der nachfolgende Text in die nächste Zeile rutscht
          textBuffer[cursorPos++] = 0x0A;
          textLen += insertLen;
          redrawScreen();
        }
      }
      
      // ================= F10-TASTE: Bildschirm speichern =================
      /*
      else if (c == KEY_F10){
        tc.setCursorPos(1, MAX_R);
        fbcolor(0, 15);
        Terminal.print("speichere Bildschirm");
        GFX.waitCompletion(false);
        speichere_bildschirm_als_bmp(0, 0, 320, 240, "screen.bmp");
        vTaskDelay(pdMS_TO_TICKS(500));
        fbcolor(63, 1);
        redrawScreen();
      }*/
      
      // ================= PFEIL NACH OBEN ('A') =================
      if (c == KEY_UP) {
        if (cursorPos > 0) {
          uint32_t currentX = 0;
          uint32_t p = cursorPos;
          // 1. Horizontale Spalte (currentX) der aktuellen Zeile ausmessen
          while (p > 0 && textBuffer[p - 1] != '\n') {
            p--;
            currentX++;
          }
          if (p > 0) {
            p--;
            uint32_t lineStart = p;
            while (lineStart > 0 && textBuffer[lineStart - 1] != '\n') {
              lineStart--;
            }
            uint32_t lineLen = p - lineStart;
            // 2. Cursor-Zielposition in der oberen Zeile berechnen (Nutzt currentX!)
            if (currentX > lineLen) {
              cursorPos = lineStart + lineLen;
            }
            else {
              cursorPos = lineStart + currentX;
            }
            // ================= DER SCROLL-CHECK ===========================
            if (cursorPos < topIndex) {
              topIndex = lineStart; // Verschiebe die Ansicht um eine Zeile nach oben
              redrawScreen();
            }
            // ==============================================================
          }
        }
      }
      // ================= PFEIL NACH UNTEN ('B') =================
      if (c == KEY_DOWN) {
        uint32_t currentX = 0;
        uint32_t p = cursorPos;
        while (p > 0 && textBuffer[p - 1] != '\n') {
          p--;
          currentX++;
        }
        p = cursorPos;
        while (p < textLen && textBuffer[p] != '\n') {
          p++;
        }
        if (p < textLen) {
          p++;
          uint32_t nextLineStart = p;
          while (p < textLen && textBuffer[p] != '\n') {
            p++;
          }
          uint32_t nextLineLen = p - nextLineStart;

          if (currentX > nextLineLen) {
            cursorPos = nextLineStart + nextLineLen;
          } else {
            cursorPos = nextLineStart + currentX;
          }
          // ================= HIER DER SCROLL-CHECK NACH UNTEN =================
          uint32_t checkLines = 2;
          for (uint32_t i = topIndex; i < cursorPos; i++) {
            if (textBuffer[i] == '\n') {
              checkLines++;
            }
          }
          if (checkLines > (MAX_R - 1)) {
            uint32_t t = topIndex;
            while (t < textLen && textBuffer[t] != '\n') {
              t++;
            }
            if (t < textLen) {
              topIndex = t + 1;
              redrawScreen();
            }
          }
          // ====================================================================
        }
      }
      // ================= PFEIL NACH RECHTS ('C') =================
      else if (c == KEY_RIGHT) {
        if (cursorPos < textLen) {
          cursorPos++;
        }
      }
      // ================= PFEIL NACH LINKS ('D') =================
      else if (c == KEY_LEFT) {
        if (cursorPos > 0) {
          cursorPos--;
        }
      }

      // ================= ENTF-TASTE (KEY_DELETE) =================
      else if (c == KEY_DELETE) {
        if (cursorPos < textLen) {

          // 1. SCHRITT: MULTI-ZEILEN BLOCK LÖSCHEN (Cut)
          // Wir prüfen, ob der Text an der gemerkten blockStartPos exakt dem Clipboard entspricht
          if (clipboardLen > 0 && blockStartPos + clipboardLen <= textLen &&
              memcmp(&textBuffer[blockStartPos], clipboardBuffer, clipboardLen) == 0) {

            // Den gesamten Textblock im PSRAM nach vorne ziehen
            memmove(&textBuffer[blockStartPos], &textBuffer[blockStartPos + clipboardLen], textLen - (blockStartPos + clipboardLen));
            textLen -= clipboardLen;
            textBuffer[textLen] = 0; // Pufferende abnullen
            cursorPos = blockStartPos;

            tc.setCursorPos(1, MAX_R);
            fbcolor(0, 15); // Cyan
            Terminal.write("\x1b[K  Block geloescht! ");
            vTaskDelay(pdMS_TO_TICKS(400));
            clipboardLen = 0;
            GFX.waitCompletion(false);
            fbcolor(63, 1);
            redrawScreen();
          }

          // 2. SCHRITT: STANDARDFALL (Einzelnes Zeichen löschen)
          else {
            memmove(&textBuffer[cursorPos], &textBuffer[cursorPos + 1], textLen - cursorPos);
            textLen--;
            textBuffer[textLen] = 0;
            redrawScreen();
          }
        }
      }

      // ================= PAGE UP ('5') =================
      if (c == KEY_PAGE_UP) {

        int linesToMove = 20;
        while (linesToMove > 0 && topIndex > 0) {
          uint32_t t = topIndex;
          if (t > 0) t--;
          while (t > 0 && textBuffer[t - 1] != '\n') {
            t--;
          }
          topIndex = t;
          linesToMove--;
        }
        cursorPos = topIndex;
        redrawScreen();
      }

      // ================= PAGE DOWN ('6') =================
      else if (c == KEY_PAGE_DOWN) {

        int linesToMove = 20;
        while (linesToMove > 0 && topIndex < textLen) {
          uint32_t t = topIndex;

          while (t < textLen && textBuffer[t] != '\n') {
            t++;
          }
          if (t < textLen) {
            topIndex = t + 1;
          } else {
            break;
          }
          linesToMove--;
        }
        cursorPos = topIndex;
        redrawScreen();
      }

      // ================= OPTISCHE 2D-CURSOR-SYNCHRONISATION =================
      uint32_t textX = 1;
      uint32_t pX = cursorPos;
      while (pX > 0 && textBuffer[pX - 1] != '\n') {
        pX--;
        textX++;
      }

      uint32_t vgaY = 2;
      for (uint32_t i = topIndex; i < cursorPos; i++) {
        if (textBuffer[i] == '\n') vgaY++;
      }

      bool horizontalScrollChanged = false;
      if (textX >= (leftColumn + MAX_C)) {
        leftColumn = textX - (MAX_C - 1);
        horizontalScrollChanged = true;
      }
      else if (textX < leftColumn) {
        leftColumn = textX;
        horizontalScrollChanged = true;
      }

      if (horizontalScrollChanged) redrawScreen();

      uint32_t vgaX = textX - leftColumn + 1;
      updateStatusLine(cursorPos);
      tc.setCursorPos(vgaX, vgaY);
      // =======================================================================

      // ================= ENTER-TASTE (ASCII 13) =================
      if (c == 13) {
        if (textLen < (EDIT_BUFF_SIZE - 1)) {
          // Verschiebt den Text hinter dem Cursor um 1 Position nach hinten
          memmove(&textBuffer[cursorPos + 1], &textBuffer[cursorPos], textLen - cursorPos);
          textBuffer[cursorPos++] = 0x0A;
          textLen++;

          // Kompakter Scroll-Check nach unten
          uint32_t checkLines = 2;
          for (uint32_t i = topIndex; i < cursorPos; i++) {
            if (textBuffer[i] == '\n') checkLines++;
          }
          if (checkLines > (MAX_R - 2)) {
            uint32_t t = topIndex;
            while (t < textLen && textBuffer[t] != '\n') t++;
            if (t < textLen) topIndex = t + 1;
          }
          leftColumn = 1; redrawScreen();
        }
      }

      // ================= BACKSPACE (ASCII 8 ODER 127) =================
      else if (c == 8 || c == 127) {
        if (cursorPos > 0) {
          // Zieht den nachfolgenden Text um 1 Position nach vorne über das gelöschte Zeichen
          memmove(&textBuffer[cursorPos - 1], &textBuffer[cursorPos], textLen - cursorPos);
          cursorPos--; textLen--;
          textBuffer[textLen] = 0;
          Terminal.write("\b\e[K"); redrawScreen();
        }
      }

      // ================= NORMALES ZEICHEN (DRUCKBARES ASCII) =================
      else if (c >= 32 && c <= 126) {
        if (textLen < (EDIT_BUFF_SIZE - 1)) {
          // Macht Platz im PSRAM für genau ein neues Zeichen
          memmove(&textBuffer[cursorPos + 1], &textBuffer[cursorPos], textLen - cursorPos);
          textBuffer[cursorPos++] = (char)c;
          textLen++;

          if (cursorPos == textLen) {
            uint32_t textX = 1, pX = cursorPos;
            while (pX > 0 && textBuffer[pX - 1] != '\n') {
              pX--;
              textX++;
            }
            if (textX >= (leftColumn + MAX_C)) {
              leftColumn = textX - (MAX_C - 1);
              redrawScreen();
            }
            else {
              Terminal.write(c);
            }
          } else {
            redrawScreen();
          }
        }
      }

      // ================= OPTISCHE 2D-CURSOR-SYNCHRONISATION =================
      // 1. Echte X-Textspalte (1-basiert) für die AKTUELLE Zeile berechnen (Rückwärtsmessung)
      textX = 1;
      pX = cursorPos;
      while (pX > 0 && textBuffer[pX - 1] != '\n') { // ZURÜCK AUF RAM
        pX--;
        textX++;
      }

      // 2. Echte Y-Zeile relativ zum aktuellen topIndex auf dem Bildschirm berechnen
      vgaY = 2; // Start bei Zeile 2 wegen der Titelzeile
      for (uint32_t i = topIndex; i < cursorPos; i++) {
        if (textBuffer[i] == '\n') { // ZURÜCK AUF RAM
          vgaY++;
        }
      }

      horizontalScrollChanged = false;

      // SCROLL-CHECK NACH RECHTS: Wenn der Cursor den rechten Rand (Spalte 53) überschreitet
      if (textX >= (leftColumn + MAX_C)) {
        leftColumn = textX - (MAX_C - 1);
        horizontalScrollChanged = true;
      }
      // SCROLL-CHECK NACH LINKS: Sobald der Cursor sich links aus dem sichtbaren Fenster bewegt
      else if (textX < leftColumn) {
        leftColumn = textX;
        horizontalScrollChanged = true;
      }

      // Falls sich der horizontale Fensterausschnitt geändert hat, Bildschirm neu aufbauen
      if (horizontalScrollChanged) {
        redrawScreen();
      }

      // Die physische X-Koordinate für das FabGL Terminal berechnen (Relativ zur leftColumn)
      vgaX = textX - leftColumn + 1;

      // Live-Update der Statuszeile ganz unten
      updateStatusLine(cursorPos);

      // Den blinkenden Hardware-VGA-Cursor flimmerfrei platzieren
      tc.setCursorPos(vgaX, vgaY);
      // =======================================================================

      vTaskDelay(pdMS_TO_TICKS(5));
    }

    // Zurücksetzen für die Shell beim Verlassen des Editors
    fbcolor(63, 1); // Zurück zu Weiß auf Blau für die Standard-Shell
    delay(1);
    GFX.clear();
    tc.setCursorPos(1, 1);
    Terminal.enableCursor(Cursor);
    return st;
  }


  // ============================================================================
  // SD-KARTEN INTERFACE (Modul: sd)
  // ============================================================================
  // ============================================================================
  // WILDCARD HILFSFUNKTION (Für sd.ls-Filterung)
  // ============================================================================

  bool wildcard_match(const char* pattern, const char* str) {
    while (*pattern) {
      if (*pattern == '*') {
        if (!*(++pattern)) return true;                                                 // Ein Stern am Ende passt auf alles restliche
        while (*str) {
          if (wildcard_match(pattern, str)) return true;
          str++;
        }
        return false;
      } else if (*pattern == '?') {
        if (!*str) return false;
        pattern++; str++;
      } else {
        if (tolower((unsigned char)*pattern) != tolower((unsigned char)*str)) return false;
        pattern++; str++;
      }
    }
    return !*pattern && !*str;
  }

  //---------------------------------------------- sd.ls(*lua) ----------------------------------------------------------
  // 1. Datei mit Wildcard suchen sd.ls("*lua")
  int lua_sd_ls(lua_State* L) {
    String searchPattern = "*";                                                         // Standardmäßig alles anzeigen
    String path = currentWorkDir;

    if (lua_gettop(L) >= 1 && lua_isstring(L, 1)) {                                      // Parameter auswerten
      String parg = lua_tostring(L, 1);

      if (parg.indexOf('*') != -1 || parg.indexOf('?') != -1) {                             // Prüfen, ob ein Wildcard (* oder ?) benutzt
        int lastSlash = parg.lastIndexOf('/');
        if (lastSlash != -1) {
          path = parg.substring(0, lastSlash + 1);
          searchPattern = parg.substring(lastSlash + 1);
        } else {
          path = currentWorkDir;
          searchPattern = parg;
        }
      } else {

        path = resolve_lua_path(parg);                                                     // Ordnerpfad ohne Wildcard, mit Pfad-Resolver prüfen
        if (!path.endsWith("/")) path += "/";
      }
    }


    String cleanPath = path;

    if (cleanPath.length() > 1 && cleanPath.endsWith("/")) {                              // Wenn der Pfad mit "/" endet, abschneiden
      cleanPath = cleanPath.substring(0, cleanPath.length() - 1);
    }

    File dir = SD.open(cleanPath.c_str());
    if (!dir || !dir.isDirectory()) {
      lua_pushboolean(L, false);
      return 1;
    }
    dir.seek(0);                                                                          //an den Verzeichnisanfang springen

    Terminal.print("--- Verzeichnis: ");                                                  // Header ausgeben (mit aktiven Filter)
    Terminal.print(cleanPath.c_str());
    if (searchPattern != "*") {
      Terminal.print(" [Filter: ");
      Terminal.print(searchPattern.c_str());
      Terminal.print("]");
    }
    Terminal.print(" ---\n\r");

    Terminal.print("Name                     Typ      Groesse\n\r");
    Terminal.print("-----------------------------------------------\n\r");

    int zeilenZaehler = 3;

    while (true) {
      File entry = dir.openNextFile();
      if (!entry) break;

      const char* rawName = entry.name();
      const char* fileName = strrchr(rawName, '/');                               // Sucht nach dem letzten Schrägstrich im Pfad

      if (fileName != NULL) {
        fileName++;                                                               // Springt hinter das '/' zum eigentlichen Dateinamen
      } else {
        fileName = rawName;                                                       // Kein '/' , ganzer String ist der Dateiname
      }

      if (fileName[0] == '.' ||                                                   // Unsichtbare Dateien / AppleDouble (._)
          strcasecmp(fileName, "System Volume Information") == 0 ||
          strcasecmp(fileName, "FOUND.000") == 0 ||
          strncasecmp(fileName, "._", 2) == 0) {                                  // "._" Abfrage auf 2 Zeichen verkürzt
        entry.close();
        continue;
      }

      if (!entry.isDirectory() && !wildcard_match(searchPattern.c_str(), fileName)) {        // Wildcard-Filter ausser bei Ordnern
        entry.close();
        continue;                                                                           // Passt nicht zum Filter -> Überspringen
      }

      char displayName[25];                                                                 // Dateinamen formatieren und bei Bedarf kürzen
      size_t nameLen = strlen(fileName);

      if (nameLen > 20) {
        strncpy(displayName, fileName, 18);
        displayName[18] = '.';
        displayName[19] = '.';
        displayName[20] = '\0';
      } else {
        strcpy(displayName, fileName);
      }

      char spaltenBuf[80];                                                                  // Zeilenpuffer für Spaltenlayout
      if (entry.isDirectory()) {
        snprintf(spaltenBuf, sizeof(spaltenBuf), "%-24s <DIR>    ---", displayName);
      } else {
        char groesseStr[20];
        snprintf(groesseStr, sizeof(groesseStr), "%lu Bytes", (unsigned long)entry.size());
        snprintf(spaltenBuf, sizeof(spaltenBuf), "%-24s FILE     %s", displayName, groesseStr);
      }

      Terminal.print(spaltenBuf);
      Terminal.print("\n\r");
      entry.close();

      zeilenZaehler++;

      if (zeilenZaehler >= MAX_R - 4) {                                                       // Seitenumbruch-Logik (MAX_R - 4)
        Terminal.print("-- WEITER MIT TASTE | ESC ZUM ABBRECHEN --\r");
        int taste = wait_key(1);
        delay(150);
        Terminal.print("                                          \r");

        if (taste == 27) {                                                                    // ESC gedrückt
          dir.close();
          lua_pushboolean(L, true);
          return 1;
        }
        zeilenZaehler = 0;
      }
    }

    dir.close();
    Terminal.print("-----------------------------------------------\n\r");

    lua_pushboolean(L, true);
    return 1;
  }

  //---------------------------------------------- sd.cd("pfadname") ----------------------------------------------------------
  // 2. sd.cd("pfad") in Lua
  int lua_sd_cd(lua_State* L) {
    if (!lua_isstring(L, 1)) {
      Terminal.print("FEHLER: Pfad (String) erwartet!\n\r");
      lua_pushboolean(L, false);
      return 1;
    }

    String eingabePfad = lua_tostring(L, 1);
    eingabePfad.trim();

    // Wir starten mit dem aktuellen Pfad als Basis
    String zielPfad = currentWorkDir;

    // ====================================================================
    // SCENARIO 1: EBENE NACH OBEN SPRINGEN ("..")
    // ====================================================================
    if (eingabePfad == "..") {
      if (zielPfad != "/") {
        if (zielPfad.endsWith("/") && zielPfad.length() > 1) {
          zielPfad.remove(zielPfad.length() - 1); // Abschließenden Slash entfernen
        }

        int letzterSlash = zielPfad.lastIndexOf('/');
        if (letzterSlash > 0) {
          zielPfad = zielPfad.substring(0, letzterSlash);
        } else {
          zielPfad = "/";
        }
      }
    }
    // ====================================================================
    // SCENARIO 2: ABSOLUTER PFADWECHSEL (Eingabe startet mit '/')
    // ====================================================================
    else if (eingabePfad.startsWith("/")) {
      zielPfad = eingabePfad;
    }
    // ====================================================================
    // SCENARIO 3: RELATIVER PFADWECHSEL (In einen Unterordner wechseln)
    // ====================================================================
    else {
      // Falls das aktuelle Verzeichnis nicht auf '/' endet, Slash hinzufügen
      if (!zielPfad.endsWith("/")) zielPfad += "/";
      // Jetzt den neuen Ordnernamen anhängen
      zielPfad += eingabePfad;
    }

    // ====================================================================
    // PFAD-BEREINIGUNG (Doppelte Slashes entfernen)
    // ====================================================================
    while (zielPfad.indexOf("//") != -1) {
      zielPfad.replace("//", "/");
    }

    // ====================================================================
    // HARDWARE-CHECK UND SPEICHERUNG (Korrektur für ESP32)
    // ====================================================================
    String checkPath = zielPfad;
    // Für SD.exists() MUSS der abschließende Slash zwingend entfernt werden
    if (checkPath.length() > 1 && checkPath.endsWith("/")) {
      checkPath = checkPath.substring(0, checkPath.length() - 1);
    }

    // Wenn wir ins Hauptverzeichnis "/" wechseln, existiert das immer (wird nicht extra geprüft)
    if (zielPfad == "/" || SD.exists(checkPath.c_str())) {
      currentWorkDir = zielPfad; // Pfad umschalten

      // Für Ihre anderen Funktionen stellen wir sicher, dass currentWorkDir immer mit '/' endet
      if (!currentWorkDir.endsWith("/")) currentWorkDir += "/";

      lua_pushboolean(L, true);
    } else {
      Terminal.printf("FEHLER: Verzeichnis '%s' existiert nicht!\n\r", checkPath.c_str());
      lua_pushboolean(L, false);
    }

    return 1;
  }

  //---------------------------------------------- sd.remove(dateiname) ----------------------------------------------------------

  // 3. Datei löschen: sd.remove("datei.lua")
  int lua_sd_remove(lua_State * L) {
    if (!lua_isstring(L, 1)) {
      Terminal.print("FEHLER: fehlender Dateiname (String)!");
      lua_pushboolean(L, false);
      return 1;
    }
    String filename = resolve_lua_path(lua_tostring(L, 1));
    bool success = SD.remove(filename.c_str());
    lua_pushboolean(L, success);
    return 1;
  }

  //---------------------------------------------- sd.mkdir(Ordnername) ----------------------------------------------------------

  // 4. Ordner erstellen: sd.mkdir("ordnername")
  int lua_sd_mkdir(lua_State * L) {
    if (!lua_isstring(L, 1)) {
      Terminal.print("FEHLER: fehlender Ordnername (String)!");
      lua_pushboolean(L, false);
      return 1;
    }
    String dirname = resolve_lua_path(lua_tostring(L, 1));
    bool success = SD.mkdir(dirname.c_str());

    lua_pushboolean(L, success);
    return 1;
  }
  //---------------------------------------------- sd.rmdir(Ordnername) ----------------------------------------------------------

  // 5. Ordner löschen: sd.rmdir("ordnername")
  int lua_sd_rmdir(lua_State * L) {
    if (!lua_isstring(L, 1)) {
      Terminal.print("FEHLER: fehlender Ordnername (String)!");
      lua_pushboolean(L, false);
      return 1;
    }
    String dirname = resolve_lua_path(lua_tostring(L, 1));
    bool success = SD.rmdir(dirname.c_str());

    lua_pushboolean(L, success);
    return 1;
  }
  //---------------------------------------------- sd.copy(Datei1,Datei2) ---------------------------------------------------------

  // 6. sd.copy("quelle.lua", "ziel.lua") - Kopiert eine Datei im aktuellen Arbeitsverzeichnis
  int lua_sd_copy(lua_State* L) {
    if (!lua_isstring(L, 1) || !lua_isstring(L, 2)) {
      Terminal.print("FEHLER: Zwei Dateinamen (Strings) erwartet!");
      lua_pushboolean(L, false);
      return 1;
    }

    String vonPfad = resolve_lua_path(lua_tostring(L, 1));    // Pfade, Arbeitsverzeichnis automatisch ergänzen
    String nachPfad = resolve_lua_path(lua_tostring(L, 2));

    if (!SD.exists(vonPfad.c_str())) {              // Quelldatei vorhanden?
      Terminal.print("FEHLER: Quelldatei existiert nicht!\n\r");
      lua_pushboolean(L, false);
      return 1;
    }

    // 3. Kopier-Vorgang starten
    File sourceFile = SD.open(vonPfad.c_str(), FILE_READ);
    if (!sourceFile) {
      Terminal.print("FEHLER: Konnte Quelldatei nicht oeffnen!\n\r");
      lua_pushboolean(L, false);
      return 1;
    }

    if (SD.exists(nachPfad.c_str())) {              // Falls die Zieldatei existiert,ueberschreiben
      SD.remove(nachPfad.c_str());
    }

    File destFile = SD.open(nachPfad.c_str(), FILE_WRITE);
    if (!destFile) {
      Terminal.print("FEHLER: Konnte Zieldatei nicht erstellen!\n\r");
      sourceFile.close();
      lua_pushboolean(L, false);
      return 1;
    }

    const size_t bufferSize = 512;                  // Blockweise kopieren
    uint8_t buffer[bufferSize];

    while (sourceFile.available() > 0) {
      size_t bytesRead = sourceFile.read(buffer, bufferSize);
      destFile.write(buffer, bytesRead);
    }
    destFile.close();
    sourceFile.close();

    Terminal.print("Datei erfolgreich kopiert.\n\r");
    lua_pushboolean(L, true);
    return 1;
  }
  //---------------------------------------------- sd.rename(alt,neu) ------------------------------------------------------------

  // 7. sd.rename("name.alt",name.neu") - Datei umbenennen
  int lua_sd_rename(lua_State* L) {
    if (!lua_isstring(L, 1) || !lua_isstring(L, 2)) {
      Terminal.print("FEHLER: Zwei Dateinamen (Strings) erwartet!");
      lua_pushboolean(L, false);
      return 1;
    }
    String vonPfad = resolve_lua_path(lua_tostring(L, 1));    // Pfade, Arbeitsverzeichnis automatisch ergänzen
    String nachPfad = resolve_lua_path(lua_tostring(L, 2));

    bool erfolg = SD.rename(vonPfad.c_str(), nachPfad.c_str());
    lua_pushboolean(L, erfolg);                               // Ergebnis (true/false) zurück an Lua geben

    return 1;
  }
  //---------------------------------------------- sd.unmount() ------------------------------------------------------------

  // 12. Funktion für sd.unmount() -> SD-Karte abmelden
  int lua_sd_unmount(lua_State* L) {
    // 1. Alle offenen Datei-Handles schließen und Puffer leeren
    SD.end();
    fcolor(60);
    Terminal.println("SD-Card abgemeldet.");
    GFX.waitCompletion(false);
    fcolor(63);
    lua_pushboolean(L, true);
    return 1;
  }

  //---------------------------------------------- sd.unmount() ------------------------------------------------------------
  // 13. Funktion für sd.mount() -> SD-Karte anmelden
  int lua_sd_mount(lua_State* L) {
    int tmp_fcolor = fColor;
    if (SD.begin( kSD_CS, spiSD)) {
      fcolor(12);
      Terminal.println("SD-Karte erfolgreich angemeldet.");
      GFX.waitCompletion(false);
      lua_pushboolean(L, true);
    } else {
      fcolor(48);
      Terminal.println("FEHLER: Keine SD-Karte gefunden.");
      GFX.waitCompletion(false);
      lua_pushboolean(L, false);
    }
    fcolor(63);
    return 1;
  }

  //---------------------------------------------- sd.exist(Dateiname) ------------------------------------------------------------

  // 8. sd.exist("dateiname") - prüft,ob eine Datei existiert
  int lua_sd_exists(lua_State* L) {
    String Pfad = resolve_lua_path(lua_tostring(L, 1));
    bool existiert = SD.exists(Pfad.c_str());
    lua_pushboolean(L, existiert);                            // Ergebnis (true/false) an Lua übergeben
    return 1;
  }
  //---------------------------------------------- sd.cat(Dateiname) ------------------------------------------------------------

  // 14. Funktion für sd.cat("dateiname.txt")
  int lua_sd_cat(lua_State* L) {
    const char* dateiname = luaL_checkstring(L, 1);
    String Pfad = resolve_lua_path(dateiname);

    File datei = SD.open(Pfad.c_str(), FILE_READ);
    if (!datei) {
      Terminal.print("FEHLER: Datei konnte nicht geoeffnet werden.\n");
      lua_pushboolean(L, false);
      return 1;
    }
    int zeilen = 0;
    char puffer[256];
    while (datei.available() > 0) {
      int geleseneBytes = datei.readBytesUntil('\n', puffer, sizeof(puffer) - 1);
      puffer[geleseneBytes] = '\0';
      zeilen++;
      if (zeilen > 20) {
        if (wait_key(1) == 27) break;
        zeilen = 0;
      }
      Terminal.println(puffer);
    }
    datei.close();
    lua_pushboolean(L, true);
    return 1;
  }

  //---------------------------------------------- sd.listfile() ------------------------------------------------------------

  // 15. erstellt eine Tabelle der Dateien auf der SD-Karte (REINER DATEINAME)
  int lua_sd_get_file_list(lua_State* L) {
    // 1. Eine große Haupt-Tabelle auf dem Lua-Stack erstellen
    lua_newtable(L);
    String cleanPath = currentWorkDir;
    if (cleanPath.length() > 1 && cleanPath.endsWith("/")) { // Wenn der Pfad mit "/" endet, abschneiden
      cleanPath = cleanPath.substring(0, cleanPath.length() - 1);
    }

    File root = SD.open(cleanPath.c_str());
    if (!root || !root.isDirectory()) {
      return 1;
    }

    int eintragIndex = 1; // Lua-Indizes beginnen immer bei 1!

    while (true) {
      File file = root.openNextFile();
      if (!file) {
        break; // Keine Dateien mehr vorhanden
      }

      // ================== 1. PFADABSCHNEIDUNG (Zuerst ausführen!) ==================
      String roherName = String(file.name());
      String reinerName = roherName;

      int letzterSlash = roherName.lastIndexOf('/');
      if (letzterSlash != -1) {
        reinerName = roherName.substring(letzterSlash + 1);
      }
      // =============================================================================

      // ================== 2. SYSTEM-FILTER (Jetzt absolut wasserdicht) =============
      // Da wir jetzt 'reinerName.c_str()' nutzen, wird garantiert nur der Name verglichen!
      char ersterBuchstabe = reinerName.length() > 0 ? reinerName[0] : '\0';
      if (ersterBuchstabe == '.' || ersterBuchstabe == 'S' || ersterBuchstabe == 's' || ersterBuchstabe == 'F' || ersterBuchstabe == 'f') {
        if (strcasecmp(reinerName.c_str(), "System Volume Information") == 0 ||
            strcasecmp(reinerName.c_str(), "FOUND.000") == 0 ||
            strncasecmp(reinerName.c_str(), "._", 2) == 0) {
          file.close();
          continue; // Datei überspringen und ausblenden
        }
      }
      // ============================================================

      // 2. Für JEDE Datei eine eigene kleine Unter-Tabelle (Zeile) erstellen
      lua_newtable(L);

      //Serial.println(reinerName); // Debug-Ausgabe auf dem PC zeigt jetzt den reinen Namen

      // Spalte 1: REINEN Dateiname hinzufügen (jetzt ohne Pfad!)
      lua_pushstring(L, reinerName.c_str());
      lua_rawseti(L, -2, 1); // Setzt den reinen Namen an Index 1 der Unter-Tabelle

      // Spalte 2: Dateigröße formatieren und hinzufügen
      if (file.isDirectory()) {
        lua_pushstring(L, "---"); // Ordner haben keine klassische Dateigröße
        lua_rawseti(L, -2, 2);    // Index 2

        lua_pushstring(L, "ORDNER"); // Spalte 3: Typ
        lua_rawseti(L, -2, 3);    // Index 3
      } else {
        // Größe lesbar in KB umrechnen
        char sizeBuf[16];
        snprintf(sizeBuf, sizeof(sizeBuf), "%.1f KB", (float)file.size() / 1024.0f);
        lua_pushstring(L, sizeBuf);
        lua_rawseti(L, -2, 2);    // Index 2

        lua_pushstring(L, "DATEI");  // Spalte 3: Typ
        lua_rawseti(L, -2, 3);    // Index 3
      }

      // 3. Die fertige Unter-Tabelle (Zeile) in unsere Haupt-Tabelle einfügen
      lua_rawseti(L, -2, eintragIndex);
      eintragIndex++;
      file.close();
    }
    root.close();
    return 1;
  }


  //---------------------------------------------- sd.pwd() ------------------------------------------------------------
  // 16. liest den aktuellen Pfad
  int lua_sd_pwd(lua_State* L) {
    String cleanPath = currentWorkDir;
    if (cleanPath.length() > 1 && cleanPath.endsWith("/")) {                              // Wenn der Pfad mit "/" endet, abschneiden
      cleanPath = cleanPath.substring(0, cleanPath.length() - 1);
    }

    lua_pushstring(L, cleanPath.c_str());
    return 1;
  }


  //********************************************** System-Funktionen *****************
  // ============================================================================
  // SYSTEM INTERFACE (Modul: sys)
  // ============================================================================

  // C++ Funktion für system.millis()
  int lua_sys_timer(lua_State* L) {
    lua_pushinteger(L, millis());
    return 1; // 1 Rückgabewert an Lua geliefert
  }

  // C++ Brücke: Lädt ein Lua-Skript von der SD-Karte direkt in den Interpreter
  int lua_sys_load(lua_State* L) {
    if (!lua_isstring(L, 1)) {
      lua_pushnil(L);
      lua_pushstring(L, "Dateiname fehlt!");
      return 2;
    }

    String filename = lua_tostring(L, 1);

    if (!filename.startsWith("/")) {
      filename = "/" + filename;
    }

    if (SD.exists(filename.c_str())) {                                                  // Datei auf SD-Karte prüfen
      File file = SD.open(filename.c_str(), FILE_READ);
      if (file) {
        size_t fileSize = file.size();

        char* buffer = (char*)malloc(fileSize + 1);                                     // Speicher im RAM fuer das Skript reservieren
        if (buffer) {
          file.readBytes(buffer, fileSize);
          buffer[fileSize] = '\0';
          file.close();
          int status = luaL_loadbuffer(L, buffer, fileSize, filename.c_str());          // geladenen Text an Lua uebergeben
          free(buffer);                                                                 // Puffer sofort freigeben, um RAM zu schonen

          if (status == LUA_OK) {
            lua_pushnil(L);

            return 2;                                                                   // 2 Werte an Lua zurueckgeben! (chunk, nil)
          } else {
            const char* err = lua_tostring(L, -1);
            Terminal.print(" -> LUA SYNTAXFEHLER IN DATEI: ");
            Terminal.println(err);
            lua_pushnil(L);
            lua_pushstring(L, err);
            return 2;
          }
        }
        file.close();
      }
    }

    Terminal.print("Fehler: Nicht auf SD-Karte vorhanden!\n\r");
    lua_pushnil(L);
    lua_pushstring(L, "Datei existiert nicht!");
    return 2;
  }


  // -------- sys.gettime() ------------
  int sys_get_time(lua_State* L) {
    uint32_t unixZeit = e_rtc.getEpoch();
    //unixZeit += 3600;     //Winterzeit / Zeitzonen-Anpassung, falls nötig

    // Berechnung der Uhrzeit über reine Mathematik
    int sekunden = unixZeit % 60;
    int minuten  = (unixZeit / 60) % 60;
    int stunden  = (unixZeit / 3600) % 24;

    // NEU: Die drei Werte einzeln als Ganzzahlen auf den Lua-Stack legen
    lua_pushinteger(L, stunden);
    lua_pushinteger(L, minuten);
    lua_pushinteger(L, sekunden);

    return 3; // 3 Rückgabewerte an Lua (Stunden, Minuten, Sekunden)
  }
  // -------- sys.getdate() -----------
  int sys_get_date(lua_State* L) {
    time_t rawtime = e_rtc.getEpoch();
    rawtime += 3600;                          // Zeitzonenausgleich (+1 Stunde für Deutschland-Winterzeit)
    struct tm* timeinfo = gmtime(&rawtime);   // gmtime nutzt native C-Bibliothek des Teensy-Compilers

    int tag   = timeinfo->tm_mday;
    int monat = timeinfo->tm_mon + 1;       // tm_mon zählt von 0 bis 11 -> korrigieren auf 1-12
    int jahr  = timeinfo->tm_year + 1900;   // tm_year zählt seit 1900 -> auf echtes Jahr korrigieren

    // Die drei Werte einzeln als Ganzzahlen auf den Lua-Stack legen
    lua_pushinteger(L, tag);
    lua_pushinteger(L, monat);
    lua_pushinteger(L, jahr);

    return 3; // 3 Rückgabewerte an Lua (Tag, Monat, Jahr)
  }

  /*
    void zeigeFehlerPopup(const __FlashStringHelper* titel, const __FlashStringHelper* meldung) {
    // Wandelt die Flash-Texte in temporäre C-Strings um
    String t(titel);
    String m(meldung);
    zeigeFehlerPopup(t.c_str(), m.c_str());
    }
    // Unterfunktion Fehlerfenster
    void zeigeFehlerPopup(const char* titel, const char* nachricht) {
    cleanupWindows();
    editorStartZeile = extrahiereFehlerZeile(nachricht);                     //fehlerhafte Zeile merken für Editor
    renderWindow(160, 160, 320, 160, 255, DARKRED, titel, nachricht, RED);   //Fehlerfenster aufbauen
    vga.drawText(220, 300, "Druecke eine Taste...", YELLOW, DARKRED, false); //und Fehlertext anzeigen
    wait_key(false);
    restoreTerminalArea(160, 160, 321, 161);
    }
  */
  //********************************************** System-Funktionen *****************
  // ============================================================================
  // SYSTEM INTERFACE
  // ============================================================================
  int NoteToFreq(int mnote)
  {
    if (mnote < 0)   mnote = 0;
    if (mnote > 127) mnote = 127; // Begrenzung auf Standard-MIDI-Bereich

    int octave = mnote / 12;
    int noteIndex = mnote - (octave * 12);

    if (octave > 8) {
      return noteTable[noteIndex] << (octave - 8);
    } else {
      return noteTable[noteIndex] >> (8 - octave);
    }
  }

  // -------- sound(kanal, note, dauer, lautstaerke) ----------------------------
  int lua_sound(lua_State* L) {
    // 1. Die 4 Argumente von Lua abgreifen (wirft automatisch einen Lua-Fehler, falls Argumente fehlen)
    int kanal      = luaL_checkinteger(L, 1);
    int note       = luaL_checkinteger(L, 2);
    int dauer      = luaL_checkinteger(L, 3);
    int lautstaerke = luaL_checkinteger(L, 4);

    // 2. Sicherheits-Begrenzungen (analog zu Ihrem Original-Code)
    if (kanal > 5)       kanal = 5;
    if (kanal < 0)       kanal = 0;
    if (lautstaerke > 127) lautstaerke = 127;
    if (lautstaerke < 0)   lautstaerke = 0;

    // Note in Frequenz (Hz) umrechnen
    int frequenz = NoteToFreq(note);
    // Format: \e_S <Kanal> ; <Frequenz> ; <Dauer_ms> ; <Lautstärke> $
    String seq = "\e_S" + String(kanal) + ";" + String(frequenz) + ";" + String(dauer) + ";" + String(lautstaerke) + "$";
    Terminal.print(seq);
    return 0; // Keine Rückgabewerte an Lua
  }
  //************************************* Inchar *************************************
static int inchar()
{
  while (1) {
    if (Terminal.available()) {
      char c = Terminal.read();

      // Wenn ein ESC-Zeichen (ASCII 27) reinkommt, folgt evtl. eine Sequenz
      if (c == 27) {
        // Kurz warten, um zu sehen, ob weitere Zeichen der Sequenz im Puffer landen
        uint32_t timeout = millis() + 10;
        while (!Terminal.available() && millis() < timeout) {
          vTaskDelay(pdMS_TO_TICKS(1));
        }

        // Wenn nach 10ms kein weiteres Zeichen kommt, war es die echte ESC-Taste!
        if (!Terminal.available()) {
          return KEY_ESC;
        }

        // Das nächste Zeichen lesen (meistens '[' oder 'O' bei F-Tasten)
        char next1 = Terminal.read();

        if (next1 == '[') {
          while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
          char next2 = Terminal.read();

          // 1. Pfeiltasten prüfen
          if (next2 == 'A') return KEY_UP;
          if (next2 == 'B') return KEY_DOWN;
          if (next2 == 'C') return KEY_RIGHT;
          if (next2 == 'D') return KEY_LEFT;
          if (next2 == 'H') return KEY_HOME;
          if (next2 == 'F') return KEY_END;

          // 2. Tasten mit einfacher, direkter Tilde (ENTF, PageUp, PageDown)
          if (next2 == '3' || next2 == '5' || next2 == '6') {
            while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
            char tilde = Terminal.read(); // Das '~' verwerfen
            if (next2 == '3') return KEY_DELETE;
            if (next2 == '5') return KEY_PAGE_UP;
            if (next2 == '6') return KEY_PAGE_DOWN;
          }

          // 3. Funktionstasten F5 bis F12 (Zwei-Ziffern-Sequenzen sicher lesen)
          if (next2 == '1' || next2 == '2') {
            while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
            char next3 = Terminal.read(); // Die zweite Ziffer lesen (z.B. '5' bei F5 oder '3' bei F11)
            
            while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
            char tilde = Terminal.read(); // Das abschließende '~' lesen und verwerfen

            if (tilde == '~') {
              if (next2 == '1') {
                if (next3 == '5') return KEY_F5;
                if (next3 == '7') return KEY_F6;
                if (next3 == '8') return KEY_F7;
                if (next3 == '9') return KEY_F8;
              }
              if (next2 == '2') {
                if (next3 == '0') return KEY_F9;
                if (next3 == '1') {speichere_bildschirm_als_bmp(0, 0, 320, 240, "screen.bmp"); return KEY_F10;}
                if (next3 == '3') return KEY_F11; // Korrekt gelöst!
                if (next3 == '4') return KEY_F12; // Korrekt gelöst!
              }
            }
          }
        }
        // VT100 / Xterm Modus für F1 bis F4
        else if (next1 == 'O') {
          while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
          char next2 = Terminal.read();
          if (next2 == 'P') return KEY_F1;
          if (next2 == 'Q') return KEY_F2;
          if (next2 == 'R') return KEY_F3;
          if (next2 == 'S') return KEY_F4;
        }

        // Falls die Sequenz unbekannt oder unvollständig war
        return 0;
      }

      // Jedes normale ASCII-Zeichen direkt zurückgeben
      return c;
    }

    vTaskDelay(pdMS_TO_TICKS(5)); // CPU-Entlastung im Loop
  }
}


/*
  static int inchar()
  {
    int v;
    char c;
    char d;
    while (1) {
      if (Terminal.available()) {
        char c = Terminal.read();

        // Wenn ein ESC-Zeichen (ASCII 27) reinkommt, folgt evtl. eine Sequenz
        if (c == 27) {
          // Kurz warten, um zu sehen, ob weitere Zeichen der Sequenz im Puffer landen
          uint32_t timeout = millis() + 10;
          while (!Terminal.available() && millis() < timeout) {
            vTaskDelay(pdMS_TO_TICKS(1));
          }

          // Wenn nach 10ms kein weiteres Zeichen kommt, war es die echte ESC-Taste!
          if (!Terminal.available()) {
            return KEY_ESC;
          }

          // Das nächste Zeichen lesen (meistens '[' oder 'O' bei F-Tasten)
          char next1 = Terminal.read();

          if (next1 == '[') {
            while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
            char next2 = Terminal.read();

            // 1. Pfeiltasten prüfen
            if (next2 == 'A') return KEY_UP;
            if (next2 == 'B') return KEY_DOWN;
            if (next2 == 'C') return KEY_RIGHT;
            if (next2 == 'D') return KEY_LEFT;
            if (next2 == 'H') return KEY_HOME;
            if (next2 == 'F') return KEY_END;

            // 2. Tasten mit abschließender Tilde (z.B. ENTF, PageUp, PageDown)
            if (next2 == '3' || next2 == '5' || next2 == '6' || (next2 >= '1' && next2 <= '2')) {
              while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
              char tilde = Terminal.read(); // Das '~' auslesen und verwerfen

              if (next2 == '3' && tilde == '~') return KEY_DELETE;
              if (next2 == '5' && tilde == '~') return KEY_PAGE_UP;
              if (next2 == '6' && tilde == '~') return KEY_PAGE_DOWN;

              // F11 und F12 nutzen oft [23~ und [24~
              if (next2 == '2' && tilde == '3') {
                if (Terminal.read() == '~') return KEY_F11;
              }
              if (next2 == '2' && tilde == '4') {
                if (Terminal.read() == '~') return KEY_F12;
              }

            }

            // 3. Funktionstasten F5 bis F10 (je nach Terminal-Emulation)
            if (next2 == '1' && Terminal.available()) {
              char next3 = Terminal.read();
              if (Terminal.read() == '~') { // Tilde verwerfen
                if (next3 == '5') return KEY_F5;
                if (next3 == '7') return KEY_F6;
                if (next3 == '8') return KEY_F7;
                if (next3 == '9') return KEY_F8;
              }
            }
            if (next2 == '2' && Terminal.available()) {
              char next3 = Terminal.read();
              if (Terminal.read() == '~') {
                if (next3 == '0') return KEY_F9;
                if (next3 == '1') return KEY_F10;  //Screenshot-Funktion
              }
            }
          }
          // VT100 / Xterm Modus für F1 bis F4 (senden oft ESC O P, ESC O Q, etc.)
          else if (next1 == 'O') {
            while (!Terminal.available()) vTaskDelay(pdMS_TO_TICKS(1));
            char next2 = Terminal.read();
            if (next2 == 'P') return KEY_F1;
            if (next2 == 'Q') return KEY_F2;
            if (next2 == 'R') return KEY_F3;
            if (next2 == 'S') return KEY_F4;
          }

          // Falls die Sequenz unbekannt war, verwerfen wir sie und senden nichts
          return 0;
        }

        // Jedes normale ASCII-Zeichen (A-Z, 0-9, Enter=13, Backspace=8 etc.) direkt zurückgeben
        return c;
      }

      vTaskDelay(pdMS_TO_TICKS(5)); // CPU-Entlastung im Loop
    }
  }
*/



  void* lua_psram_allocator(void *ud, void *ptr, size_t osize, size_t nsize) {
    (void)ud;

    // Fall 1: Speicher soll komplett freigegeben werden
    if (nsize == 0) {
      if (ptr != nullptr) {
        free(ptr);
        // Wir ziehen die alte Größe vom Lua-Verbrauch ab
        if (luaCurrentMemoryUsage >= osize) {
          luaCurrentMemoryUsage -= osize;
        } else {
          luaCurrentMemoryUsage = 0;
        }
      }
      return nullptr;
    }

    // Fall 2: Speicher wird neu angefordert oder verändert (realloc)
    else {
      long long differenz = (long long)nsize - (long long)osize;

      // Wenn es eine Vergrößerung ist, prüfen wir das Limit
      if (differenz > 0) {
        if ((luaCurrentMemoryUsage + differenz) > LUA_MAX_PSRAM) {
          Terminal.println("[LUA] Speicherlimit im PSRAM erreicht!");
          return nullptr;
        }
      }

      // Die eigentliche Allokation im PSRAM ausführen
      void* new_ptr = heap_caps_realloc(ptr, nsize, MALLOC_CAP_SPIRAM);
      // Nur wenn die Allokation erfolgreich war, aktualisieren wir den Zähler
      if (new_ptr != nullptr) {
        luaCurrentMemoryUsage += differenz;
      }
      return new_ptr;
    }
  }

  void luaComputerTask(void * parameter) {
    bool ln = true;
    int c;

    //L = luaL_newstate();

    lua_State *L = lua_newstate(lua_psram_allocator, nullptr, 0);

    if (L == nullptr) {
      Terminal.println("CRITICAL ERROR: Lua konnte nicht im PSRAM gestartet werden!");
      vTaskDelete(nullptr);
    }


    //-------------------------------- Lua-Registrierungen ----------------------------
    //luaL_openlibs(L);
    luaL_requiref(L, "_G", luaopen_base, 1);      // Basis-Funktionen (assert, type, print, etc.)
    lua_pop(L, 1);

    luaL_requiref(L, "math", luaopen_math, 1);    // Mathematische Funktionen (sin, cos, random...)
    lua_pop(L, 1);

    luaL_requiref(L, "string", luaopen_string, 1);// String-Manipulationen
    lua_pop(L, 1);

    luaL_requiref(L, "table", luaopen_table, 1);  // Tabellen-Funktionen (insert, remove...)
    lua_pop(L, 1);

    luaL_requiref(L, "package", luaopen_package, 1); // Aktiviert require() und package
    lua_pop(L, 1);

    lua_register(L, "print",    lua_custom_print);
    lua_register(L, "write",    lua_custom_write);
    lua_register(L, "delay",    lua_delay);
    lua_register(L, "delayus",  lua_delay_us);
    lua_register(L, "inkey",    lua_global_inkey);
    lua_register(L, "waitkey",  lua_global_waitkey);
    lua_register(L, "edit",     lua_cmd_edit);
    lua_register(L, "run",      lua_dofile);
    lua_register(L, "sound",    lua_sound);
    lua_register(L, "info",     lua_info);


    lua_newtable(L);
    lua_pushcfunction(L, lua_vga_color);         lua_setfield(L, -2, "color");
    lua_pushcfunction(L, lua_vga_pset);          lua_setfield(L, -2, "pset");
    lua_pushcfunction(L, lua_vga_line);          lua_setfield(L, -2, "line");
    lua_pushcfunction(L, lua_vga_rect);          lua_setfield(L, -2, "rect");
    lua_pushcfunction(L, lua_vga_box);           lua_setfield(L, -2, "box");
    lua_pushcfunction(L, lua_vga_ellipse);       lua_setfield(L, -2, "ellipse");
    lua_pushcfunction(L, lua_vga_filledellipse); lua_setfield(L, -2, "fillellipse");
    lua_pushcfunction(L, lua_vga_text);          lua_setfield(L, -2, "text");
    lua_pushcfunction(L, lua_vga_cls);           lua_setfield(L, -2, "cls");
    lua_pushcfunction(L, lua_vga_pos);           lua_setfield(L, -2, "pos");
    lua_pushcfunction(L, lua_vga_get_colors);    lua_setfield(L, -2, "gcolor");
    lua_pushcfunction(L, lua_vga_wait_vsync);    lua_setfield(L, -2, "waitsync");
    lua_pushcfunction(L, lua_vga_set_title);     lua_setfield(L, -2, "setTitle");
    lua_pushcfunction(L, lua_vga_set_status);    lua_setfield(L, -2, "setStatus");
    lua_pushcfunction(L, lua_vga_close_window);  lua_setfield(L, -2, "closeWindow");
    lua_pushcfunction(L, lua_vga_open_window);   lua_setfield(L, -2, "openWindow");
    lua_pushcfunction(L, lua_vga_update_window); lua_setfield(L, -2, "updateWindow");
    lua_pushcfunction(L, lua_vga_cursor_onoff);  lua_setfield(L, -2, "cursor");
    lua_pushcfunction(L, lua_vga_bmpload);       lua_setfield(L, -2, "bmpLoad");
    lua_pushcfunction(L, lua_vga_bmpsave);       lua_setfield(L, -2, "bmpSave");

    lua_setglobal(L, "vga");        // Die Tabelle "vga" registrieren

    lua_newtable(L);
    lua_pushcfunction(L, lua_sys_timer);         lua_setfield(L, -2, "timer");
    lua_pushcfunction(L, lua_sys_load);          lua_setfield(L, -2, "load");
    lua_pushcfunction(L, sys_get_time);          lua_setfield(L, -2, "gettime");
    lua_pushcfunction(L, sys_get_date);          lua_setfield(L, -2, "getdate");

    // Die Tabelle global unter dem Namen "sys" registrieren
    lua_setglobal(L, "sys");


    // Eine neue Tabelle für die SD-Bibliothek in Lua erstellen
    lua_newtable(L);
    // Die C++ Funktionen der Tabelle zuweisen
    lua_pushcfunction(L, lua_sd_ls);     lua_setfield(L, -2, "ls");
    lua_pushcfunction(L, lua_sd_remove); lua_setfield(L, -2, "remove");
    lua_pushcfunction(L, lua_sd_mkdir);  lua_setfield(L, -2, "mkdir");
    lua_pushcfunction(L, lua_sd_rmdir);  lua_setfield(L, -2, "rmdir");
    lua_pushcfunction(L, lua_sd_cd);     lua_setfield(L, -2, "cd");
    lua_pushcfunction(L, lua_sd_copy);   lua_setfield(L, -2, "copy");
    lua_pushcfunction(L, lua_sd_rename); lua_setfield(L, -2, "rename");
    lua_pushcfunction(L, lua_sd_exists); lua_setfield(L, -2, "exist");
    //              lua_pushcfunction(L, lua_sd_append); lua_setfield(L, -2, "append");
    //              lua_pushcfunction(L, lua_sd_write);  lua_setfield(L, -2, "write");
    //              lua_pushcfunction(L, lua_sd_read_lines); lua_setfield(L, -2, "readline");
    lua_pushcfunction(L, lua_sd_mount);   lua_setfield(L, -2, "mount");
    lua_pushcfunction(L, lua_sd_unmount); lua_setfield(L, -2, "unmount");
    lua_pushcfunction(L, lua_sd_cat);     lua_setfield(L, -2, "cat");
    lua_pushcfunction(L, lua_sd_get_file_list); lua_setfield(L, -2, "listfile");
    lua_pushcfunction(L, lua_sd_pwd);     lua_setfield(L, -2, "pwd");
    //              lua_pushcfunction(L, lua_sd_open);    lua_setfield(L, -2, "open");
    //              lua_pushcfunction(L, lua_sd_read);    lua_setfield(L, -2, "read");
    //              lua_pushcfunction(L, lua_sd_seek);    lua_setfield(L, -2, "seek");
    //              lua_pushcfunction(L, lua_sd_close);   lua_setfield(L, -2, "close");

    lua_setglobal(L, "sd");         // Die Tabelle global unter dem Namen "sd" registrieren

    //---------------------------------------------------------------------------------

    // ========================================================================
    // AUTOMATISCHER START: init.lua von SD-Karte laden und ausführen
    // ========================================================================
    if (SD.exists("/lua/init.lua")) {
      File bootFile = SD.open("/lua/init.lua", FILE_READ);
      if (bootFile) {
        size_t fileSize = bootFile.size();

        char* bootBuffer = (char*)malloc(fileSize + 1);         // Dynamischen temporären Speicher im RAM1 für den Boot-Text anfordern
        if (bootBuffer != NULL) {
          bootFile.readBytes(bootBuffer, fileSize);
          bootBuffer[fileSize] = '\0';
          bootFile.close();

          if (luaL_dostring(L, bootBuffer) != LUA_OK) {         // Übergabe des geladenen Text-Strings an den Lua-Kern
            const char* error_msg = lua_tostring(L, -1);
            Terminal.print("Fehler in init.lua: ");
            Terminal.println(error_msg);
            lua_pop(L, 1);
          }
          free(bootBuffer);                                     // Speicher wieder freigeben
        } else {
          Terminal.println("Fehler: Zu wenig RAM fuer Boot-Puffer!\n\r");
          bootFile.close();
        }
      } else {
        Terminal.println("Fehler: Konnte init.lua nicht oeffnen!\n\r");
      }
    }
    Terminal.print("> ");                                         //Eingabeprompt
    Terminal.enableCursor(Cursor);

    while (true) {
      while (ln) {
        c = inchar();
        switch (c) {
          case 13:
            inputBuffer += '\0';
            Terminal.println();
            ln = false;
            break;

          case 127:
            if (inputBuffer.length() > 0) {
              inputBuffer.remove(inputBuffer.length() - 1);
              Terminal.write("\b\e[K");
            }
            break;

          case KEY_ESC:
            ln = false;
            break;

          case KEY_F1:
            inputBuffer = "run(\"file.lua\")\n";
            ln = false;
            break;

          case KEY_F2:
            inputBuffer = String("edit(\"") + currentEditingFilename + "\")\n";
            currentEditingFilename = '\0';
            ln = false;
            break;

          case KEY_F3:
            inputBuffer = String("run(\"") + currentEditingFilename + "\")\n";
            currentEditingFilename = '\0';
            ln = false;
            break;

          case KEY_F4:
            inputBuffer = "info()\n";
            ln = false;
            break;


          default:
            inputBuffer += (char)c;
            Terminal.write(c);
            break;
        }
      }

      int status = luaL_dostring(L, inputBuffer.c_str());//line);
      inputBuffer = "";
      if (status != LUA_OK) {
        const char* errorMsg = lua_tostring(L, -1);
        Terminal.printf("Fehler: %s\n", errorMsg);
        lua_pop(L, 1);

      }
      Terminal.println();
      Terminal.print("> ");
      ln = true;
    }
    vTaskDelay(pdMS_TO_TICKS(10));
  }

  //######################################################## SETUP #######################################################
  void setup() {
    Serial.begin(9600);                                                     // serielle Schnittstelle für DEBUG
    delay(200);
    pinMode(kSD_CS, OUTPUT);
    digitalWrite(kSD_CS, HIGH);

    SPI.begin();
    Keyboard.begin(GPIO_NUM_33, GPIO_NUM_32);
    PS2Controller.keyboard() -> setLayout(&fabgl::GermanLayout);                       //deutsche Tastatur
    VGAController.begin();                                                             //VGA-Variante //64 oder 16 Farben
    //VGAController.setFont(&fabgl::FONT_5x7);
    VGAController.setResolution(QVGA_320x240_60Hz);//QVGA_320x240_60Hz);                                    //Standard-Auflösung
    Terminal.begin(&VGAController);
    Terminal.activate(TerminalTransition::None); // Sofort aktivieren ohne Effekt
    Terminal.connectLocally();                                                         // für Terminal Komandos
    Terminal.loadFont(&fabgl::FONT_6x8);//6x8);

    fbcolor(fColor, bColor);
    tc.setCursorPos(1, 1);
    Terminal.clear();
    //GFX.clear();
    Terminal.println("\n--- ESP32 Lua - COMPUTER V.1.0 ---");
    // 1. SPI und SD-Karte starten
    spiSD.begin(kSD_CLK, kSD_MISO, kSD_MOSI, kSD_CS);

    if (!SD.begin(kSD_CS, spiSD, speedHz)) {
      Terminal.print("SD-Karten-Fehler");
    } else {
      // Wenn die SD-Karte da ist, Ordner prüfen/erstellen
      if (!SD.exists("/lua")) {
        SD.mkdir("/lua");
      }

    }

    // Prüfen, ob PSRAM auf dem ESP32 überhaupt aktiv/vorhanden ist
    if (psramInit()) {
      //Terminal.printf("PSRAM aktiv. Freier Speicher: %d Bytes\n", ESP.getFreePsram());

      // 1. Editor-Puffer im PSRAM anlegen
      textBuffer = (char*)ps_malloc(EDIT_BUFF_SIZE);

      // 2. Clipboard-Puffer im PSRAM anlegen
      clipboardBuffer = (char*)ps_malloc(CLIPBOARD_SIZE);

      if (textBuffer != nullptr && clipboardBuffer != nullptr) {
        memset(textBuffer, 0, EDIT_BUFF_SIZE);
        memset(clipboardBuffer, 0, CLIPBOARD_SIZE);


      } else {
        Terminal.println("ERROR: Nicht genug PSRAM!");
      }
    } else {
      Terminal.println("ERROR: Kein PSRAM gefunden!");
    }

    Terminal.enableCursor(false);

    //--------------- ESP32 RTC stellen --------------------
    char const *compileDate = __DATE__;
    char const *compileTime = __TIME__;

    // Monate konvertieren
    char monthStr[4];
    int day, year, hour, minute, second;
    sscanf(compileDate, "%s %d %d", monthStr, &day, &year);
    sscanf(compileTime, "%d:%d:%d", &hour, &minute, &second);

    int month = 1;
    const char* months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
    for (int i = 0; i < 12; i++) {
      if (strcmp(monthStr, months[i]) == 0) {
        month = i + 1;
        break;
      }
    }
    e_rtc.setTime(second, minute, hour, day, month, year);

    //--------------- ESP32 RTC starten und stellen --------

    // starte den Lua-Computer-Task auf Core 1
    xTaskCreatePinnedToCore(
      luaComputerTask,    // Funktion, die ausgeführt werden soll
      "LuaTask",          // Name des Tasks
      32768,              // Stack-Größe in Bytes (32 KB - absolut sicher für Lua)
      NULL,               // Parameter, die übergeben werden
      1,                  // Priorität des Tasks
      &LuaTaskHandle,     // Task-Handle
      1                   // Core (0 oder 1)
    );
    Terminal.print("> ");
  }

  //######################################################## LOOP ########################################################
  void loop() {
    delay(1000);
  }
