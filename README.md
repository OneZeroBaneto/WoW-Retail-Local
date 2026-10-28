# WoW Retail Local — Windows-Vorbereitung

Ein eigenes Windows-x64-Projekt für einen lokalen Retail-Testserver. Entwickelt auf macOS; Server, MySQL, Extraktoren und WoW laufen auf Windows. Die Versionen stehen in `sources.lock.json`. Die Serverquelle wird beim Vorbereiten auf genau diesen Commit heruntergeladen.

**Ziel für den ersten Test:** Retail **12.1.5.70575**, Mensch/Krieger in Nordhain. Setup, normaler Account, reversible Client-Konfiguration und konkrete Datenprüfung sind vorbereitet. Der vollständige native Windows-Lauf ist bestanden: Core-Build, 35 Core-Tests, alle vier Datenbanken mit Updates, Startdatenprüfung und BNet-HTTPS-Loginformular. Zusätzlich bestehen 27 Verhaltenstests und die echte Windows-MySQL-Integration. Clientlogin und Gameplay sind noch nicht abgenommen. Siehe [Prüfstand](docs/VALIDATION.md).

**[Windows-Testpaket herunterladen](https://github.com/OneZeroBaneto/WoW-Retail-Local/releases/tag/retail-12.1.5.70575-preparation-2026-10-28)** — fertige EXEs plus Vorbereitungsskripte. **Hier beginnen: [FIRST-PLAY.md](docs/FIRST-PLAY.md).** Das Repository enthält Quellcode und Vorbereitungsskripte. Fertige Serverpakete werden nur von erfolgreichen [Windows-Builds](https://github.com/OneZeroBaneto/WoW-Retail-Local/actions/workflows/windows-build.yml) als separates Artifact bereitgestellt. Kein WoW-Client oder extrahierte Spieldaten sind enthalten.

Retail hat erhebliche Inhaltslücken; die [offizielle Core-Dokumentation](https://trinitycore.info/install/Core-Installation) weist auf wenig Spielinhalt auf diesem Zweig hin. Login und vorhandene Systeme ergeben keine vollständige Retail-Kampagne. Die erste praktische Abnahme sollte sich auf eine konkrete Klasse, Queststrecke und Instanz begrenzen.

## Auf Windows beginnen

1. [FIRST-PLAY.md](docs/FIRST-PLAY.md) lesen und den exakten Clientbuild prüfen.
2. `Configure.bat`, lokale Windows-Pfade setzen, anschließend `Setup.bat`.
3. `Start.bat` → `Account.bat` → `Client.bat` und die konkrete Spielabnahme durchführen.
4. Mit `Stop.bat` sauber stoppen; `Backup.bat` sichert den Offline-Zustand.

| Datei | Zweck |
| --- | --- |
| `Setup.bat` | Fehlende Vorbereitungsschritte ausführen und Nordhain-Profil aktivieren |
| `Account.bat` | Normalen Account erstellen und am lokalen BNet-Dienst prüfen |
| `Client.bat` / `Restore-Client.bat` | Geprüften Launcher starten / bisheriges Portal wiederherstellen |
| `CheckGame.bat` / `Diagnose.bat` | Echte Startdaten prüfen / Diagnose ohne Geheimnisse schreiben |
| `Configure.bat` | Persönliche Pfade/Zugangsdaten und Konfigurationen erzeugen |
| `Check.bat` | Fehlende Voraussetzungen anzeigen; Exit 2 bedeutet offene Punkte |
| `Start.bat` | Eigenen MySQL-, World- und BNet-Prozess starten; Fenster offen lassen |
| `Console.bat` | Einen Worldserver-Konsolenbefehl senden; Ergebnis im Log prüfen |
| `Stop.bat` | Worldserver speichern/beenden, danach Auth und MySQL stoppen |
| `Backup.bat` | Private Offline-Sicherung mit Wiederherstellungsdaten |
| `Test.bat` | Portable Skripttests ausführen |
| `scripts/Manage.ps1` | Einzelne Vorbereitungsaktionen, siehe Anleitung |

TBC und Forever haben eigene Verzeichnisse und MySQL-Instanzen. Die Spiel-/Loginports sind standardmäßig gleich; **immer nur eine Variante gleichzeitig starten**. Das Skript stoppt bei belegten Ports und beendet keine fremde Installation. Es richtet keinen Windows-Dienst, keine Portfreigabe und keine Firewallausnahme ein.

## Inhalt und Upstream

Der Core liegt nach `Source` in `vendor/core`; das Verzeichnis ist bewusst nicht Teil dieses Git-Repos. Es ist ein eigener Git-Checkout mit festem Commit und einem dokumentierten [Windows-Konsolenpatch](docs/CORE-PATCH.md). Die Prüfung erlaubt genau diesen Patch; zusätzliche Änderungen werden erkannt und erhalten. Neue Upstream-Stände werden bewusst im Lockfile ausgewählt, mit Backups vorbereitet und neu getestet. Kein automatisches `git pull` beim Spielstart.

- [Retail-Core](https://github.com/TrinityCore/TrinityCore/tree/master)
- [Festgelegter Retail-Stand](https://github.com/TrinityCore/TrinityCore/commit/2245496d5aebb9351dc05a4d54995f94007051a2)
- [Datenbankrelease](https://github.com/TrinityCore/TrinityCore/releases/tag/TDB1210.26091)
- [Windows-Anforderungen von TrinityCore](https://trinitycore.info/install/requirements/windows)

Die übernommenen Dateien unter `config/upstream` stammen unverändert aus dem festgelegten Core-Commit. Lizenz: GPL-2.0-or-later; siehe [LICENSE](LICENSE). Namen und Spieldaten von World of Warcraft gehören ihren jeweiligen Rechteinhabern; der Client wird selbst bereitgestellt.

## Entwicklung und Prüfung

```powershell
pwsh -NoProfile -File tests/Run.Tests.ps1
pwsh -NoProfile -File tests/Readiness.Tests.ps1
pwsh -NoProfile -File tests/Parse-All.ps1
python tests/ConsoleProbe.py
```

Die PowerShell-Prüfungen laufen auf Mac und Windows. Der C++-Konsolentest benötigt auf Mac `clang++` und auf Windows eine x64 Developer Command Prompt für Visual Studio plus Python 3. Die GitHub-Actions-Prüfungen laufen im öffentlichen Repository auf kostenlosen Standard-Windows-Runnern. Ein grüner Skript-/Konsolentest ersetzt weder den vollständigen Core-Build noch den Client-/Spieltest. Den tatsächlich geprüften Stand beschreibt [VALIDATION.md](docs/VALIDATION.md).

Lokale Zustände in `local`, `runtime`, `downloads`, `build`, `vendor` und `backups` sind ignoriert. Sicherungen enthalten Passwörter und private Schlüssel. Für den Transfer an andere Personen nur das Repository bzw. das erzeugte **Source-ZIP** verwenden.
