# WoW Retail Local — Windows-Vorbereitung

Ein eigenes Windows-x64-Projekt für einen lokalen Retail-Testserver. Entwickelt auf macOS; Server, MySQL, Extraktoren und WoW laufen auf Windows. Die Versionen stehen in `sources.lock.json`. Die Serverquelle wird beim Vorbereiten auf genau diesen Commit heruntergeladen.

**Status:** PowerShell-Vorbereitung und portable Tests vorhanden. Windows-Kompilierung, erste Datenbankinstallation, Clientlogin und Gameplay sind noch nicht abgenommen. Dieses Repository enthält keine fertigen Server-Binaries, keine Spieldaten und keinen WoW-Client.

Retail hat erhebliche Inhaltslücken; die [offizielle Core-Dokumentation](https://trinitycore.info/install/Core-Installation) weist auf wenig Spielinhalt auf diesem Zweig hin. Login und vorhandene Systeme ergeben keine vollständige Retail-Kampagne. Die erste praktische Abnahme sollte sich auf eine konkrete Klasse, Queststrecke und Instanz begrenzen.

## Auf Windows beginnen

1. Dieses komplette Repository nach `C:\WoW-Retail-Local` kopieren oder dort entpacken. Auch Pfade mit Leerzeichen werden unterstützt.
2. Die Voraussetzungen und Schritte in [WINDOWS-SETUP.md](docs/WINDOWS-SETUP.md) abarbeiten. `Configure.bat` legt persönliche Einstellungen an; danach die Windows-Pfade in `local/settings.json` setzen und erneut konfigurieren.
3. Quelle abrufen, Server bauen, Datenbankpaket prüfen, Daten extrahieren und die lokale Datenbank vorbereiten.
4. `Start.bat` lässt die Server in seinem Fenster laufen. `Console.bat` sendet Befehle, `Stop.bat` fordert einen sauberen Shutdown an. `Backup.bat` kopiert die Daten nur bei gestoppten Servern.
5. Die [Windows- und Spielabnahme](docs/WINDOWS-ACCEPTANCE.md) durchführen und Ergebnisse mit Buildnummer festhalten.

| Datei | Zweck |
| --- | --- |
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
pwsh -NoProfile -File tests/Parse-All.ps1
python tests/ConsoleProbe.py
```

Die PowerShell-Prüfungen laufen auf Mac und Windows. Der C++-Konsolentest benötigt auf Mac `clang++` und auf Windows eine x64 Developer Command Prompt für Visual Studio plus Python 3. Die GitHub-Actions-Datei bereitet beide Prüfungen unter Windows vor, läuft aber erst nach Upload ins eigene Repository. Ein grüner Skript-/Konsolentest ersetzt weder den vollständigen Core-Build noch den Client-/Spieltest. Den tatsächlich geprüften Stand beschreibt [VALIDATION.md](docs/VALIDATION.md).

Lokale Zustände in `local`, `runtime`, `downloads`, `build`, `vendor` und `backups` sind ignoriert. Sicherungen enthalten Passwörter und private Schlüssel. Für den Transfer an andere Personen nur das Repository bzw. das erzeugte **Source-ZIP** verwenden.
