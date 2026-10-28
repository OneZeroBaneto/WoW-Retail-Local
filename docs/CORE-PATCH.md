# Windows-Konsolenpatch

Die festgelegten Forever- und Retail-Stände verwenden unter Windows `ReadConsoleW` und `WriteConsoleW`. Diese APIs erwarten Konsolenhandles. Der Supervisor verwendet umgeleitete Pipes, damit er Befehle, Logs und einen geordneten Shutdown verwalten kann. Ohne Anpassung erhält der Worldserver diese Befehle nicht.

`patches/0001-windows-pipe-console.patch` verändert ausschließlich `src/server/worldserver/CommandLine/CliRunnable.cpp`:

- Echte Windows-Konsole: bisherige Unicode-Konsolenfunktionen bleiben erhalten.
- Umgeleiteter Eingang: zeilenweise UTF-8-Kommandos über `std::getline`; EOF fordert das Ende an.
- Umgeleiteter Ausgang: UTF-8-Antworten über `fwrite` und `fflush`.

`Source` lädt den festen Commit und wendet genau diesen Patch an. Der SHA-256 steht im Lockfile. Die Quellprüfung vergleicht den vollständigen Diff gegen die Patchdatei und lehnt zusätzliche Änderungen ab. Der Buildmarker enthält Commit und Patch-SHA. Ein Update benötigt eine erneute Prüfung und Kompilierung.

## Test und Grenzen

`tests/native/upstream/CliRunnable.cpp` ist die unveränderte Datei aus beiden festgelegten Commits. Der Git-Blob-SHA ist `5e8fd69a0728ee06c13c739181ac6b3c82930817`. Herkunft:

- [Forever-Original](https://github.com/advocaite/TrinityCore/blob/9999bc56c19e9b179143242463dc523243827224/src/server/worldserver/CommandLine/CliRunnable.cpp)
- [Retail-Original](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/worldserver/CommandLine/CliRunnable.cpp)

`tests/ConsoleProbe.py` wendet den Patch auf eine temporäre Kopie dieses Originalcodes an, kompiliert ihn gegen kleine Spielwelt-Stubs und sendet `help` und `server shutdown 0` durch echte Prozesspipes. Der Test verlangt beide Antworten und einen sauberen Exit. Ohne Patch scheitert er. Unter macOS wird die Windows-API-Grenze simuliert; unter Windows verwendet er `GetConsoleMode` aus dem Windows SDK. Die GitHub-Actions-Datei enthält diesen Windows-Test.

Das prüft den Konsolenadapter, nicht die komplette Spielwelt, die asynchrone Core-Shutdownlogik oder einen echten Spielstand. Vollständiger Core-Build, Windows-Lauf und Persistenzprüfung sind gesonderte Abnahmepunkte. Upstream-Datei und Patch stehen unter GPL-2.0-or-later; siehe LICENSE.
