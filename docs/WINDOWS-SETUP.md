# Windows-Setup

## Voraussetzungen

Ziel: Windows x64, empfohlen Windows 11; native Ausführung, ohne Docker oder WSL. Benötigt werden PowerShell 7.4+, Git, CMake 3.24+, Visual Studio 2022 ab 17.4 mit „Desktopentwicklung mit C++“ und Windows SDK, Boost x64 für MSVC 14.3, OpenSSL 3 x64, MySQL Server 8.0 ab 8.0.34 inklusive Client/Entwicklungsdateien und 7-Zip. Es genügt die MySQL-Installation; dieses Projekt verwendet einen eigenen Datenordner und startet seine eigene Instanz. Ein bereits vorhandener MySQL-Windowsdienst wird nicht verändert.

Die Defaultpfade erwarten Boost 1.86 unter `C:/local/boost_1_86_0` und OpenSSL unter `C:/Program Files/OpenSSL-Win64`. Andere passende Installationspfade lassen sich in den lokalen Einstellungen setzen. Laufzeit-DLLs müssen zur x64-Buildumgebung passen. Die CI verwendet reproduzierbar Boost 1.84.0, OpenSSL 3.5.9 und MySQL 8.0.46; den tatsächlichen Laufstatus dokumentiert [VALIDATION.md](VALIDATION.md). Mit einem fertigen Serverpaket entfallen Visual Studio, CMake und Boost.

Quellen und Downloads: [TrinityCore Windows-Anforderungen](https://trinitycore.info/install/requirements/windows), [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows), [Git für Windows](https://git-scm.com/download/win), [7-Zip](https://www.7-zip.org/), [MySQL 8.0.46 ZIP](https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.46-winx64.zip), [OpenSSL 3.5.9 x64 vollständig](https://slproweb.com/download/Win64OpenSSL-3_5_9.exe). Das MySQL-ZIP einfach in einen eigenen Ordner entpacken und `mysqlRoot` darauf setzen; keinen Dienst anlegen. Erwarteter SHA-256 des ZIPs: `28e9eda019d88eff4478d811ea2110b83f02a3966be157fe91cc55def3ab0d4d`. OpenSSL-Installer-SHA-256: `5fe338c81d62515df7292f16542a0eef2a29db3efc023cd5a8c08ec3c97027ae`. Bei Verwendung vorgebauter EXEs außerdem die [Microsoft VC++ x64 Runtime](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist) installieren, falls noch nicht vorhanden.

## Reihenfolge

Alle Befehle im Projektverzeichnis in **PowerShell 7** ausführen:

```powershell
pwsh -NoProfile -File scripts/Manage.ps1 -Action Configure
notepad local/settings.json
```

`clientRoot` ist der WoW-Hauptordner mit `.build.info` und `Data`, nicht nur der Unterordner mit der EXE. Der im Lockfile genannte Clientbuild muss vorhanden sein. `relativeExe` steht in `sources.lock.json`: Forever im dokumentierten Beta-Layout `_classic_beta_/WowB.exe`; Retail `_retail_/Wow.exe`. Bei einem anderen tatsächlichen Installationslayout nur `relativeExe` auf die vorhandene EXE anpassen, nicht die erwartete Buildnummer. Der CASC-Produktname wird aus der aktiven passenden Zeile der `.build.info` gelesen, nicht aus dem Verzeichnisnamen geraten.

Eigene Pfade setzen, generierte Passwörter behalten und dann:

```powershell
pwsh -NoProfile -File scripts/Manage.ps1 -Action Configure
pwsh -NoProfile -File scripts/Manage.ps1 -Action Check
```

`Check` meldet zu diesem Zeitpunkt erwartungsgemäß noch fehlende Quelle/Binaries/Daten. Es führt keine Installation aus.

```powershell
pwsh -NoProfile -File scripts/Manage.ps1 -Action Source
pwsh -NoProfile -File scripts/Manage.ps1 -Action Build
pwsh -NoProfile -File scripts/Manage.ps1 -Action DatabaseFiles
pwsh -NoProfile -File scripts/Manage.ps1 -Action Extract
pwsh -NoProfile -File scripts/Manage.ps1 -Action Database
pwsh -NoProfile -File scripts/Manage.ps1 -Action Certificates
```

- `Source` lädt den festgelegten Commit und wendet ausschließlich den per SHA-256 festgelegten Patch für Windows-Konsolenpipes an. Andere Änderungen werden abgelehnt und nicht zurückgesetzt. Details: [CORE-PATCH.md](CORE-PATCH.md).
- `Build` kompiliert Release x64 mit zwei parallelen Jobs und installiert nach `runtime`. Vor der Testentdeckung und nach der Installation werden MySQLs eigene SSL-Abhängigkeiten sowie `libmysql.dll`, `libcrypto-3-x64.dll`, `libssl-3-x64.dll` und der OpenSSL-Provider `legacy.dll` aus den eingestellten Installationen übernommen. Beide Server müssen `--version` erfolgreich ausführen und OpenSSL muss den lokalen Legacy-Provider laden, bevor ein Buildmarker geschrieben wird. Der Vorgang kann längere Zeit dauern.
- `DatabaseFiles` lädt das festgelegte 7z-Archiv, prüft dessen SHA-256 und übernimmt nur die beiden erwarteten SQL-Dateien.
- `Extract` prüft die EXE-Version, extrahiert Karten/Tabellen/Kollision/Wegfindung in ein neues Arbeitsverzeichnis und übernimmt erst vollständige Verzeichnisse. Frühere Daten bleiben als `runtime/data-previous-*` erhalten. Die Extraktion kann lange dauern.
- `Database` initialisiert ausschließlich die eigene MySQL-Instanz, importiert die Daten und wendet die Updates des festen Core-Stands an. Das Updater-Konto hat Rechte nur auf die vier Projekt-Datenbanken. Danach wird MySQL wieder beendet. Der normale Spielstart führt keine Datenbankmigrationen aus.
- `Certificates` erzeugt neue lokale Schlüssel/Zertifikate. Bestehende Schlüssel werden nicht ersetzt. Es wird dabei noch nichts im Windows-Zertifikatsspeicher oder in der hosts-Datei installiert.

MySQL startet mit `--no-monitor`, damit der Supervisor den tatsächlichen Serverprozess anhand seiner PID prüfen kann. MySQL-Clientaufrufe bekommen explizit Host/Port/Benutzer und ein prozesslokales `MYSQL_TEST_LOGIN_FILE` auf eine nicht vorhandene Datei. Dadurch können gespeicherte Anmeldungen einer anderen MySQL-Installation die Verbindung nicht umleiten. Das gilt auch für den Core-Updater. Quellen: [MySQL unter Windows](https://dev.mysql.com/doc/refman/8.0/en/windows-installation.html), [MySQL-Optionsdateien](https://dev.mysql.com/doc/refman/8.0/en/option-files.html).

## Clientanmeldung und erster Start

Die aktuelle Anleitung steht in [FIRST-PLAY.md](FIRST-PLAY.md): Burralis-Launcher, lokales Portal, `Account.bat`, Mensch/Krieger in Nordhain und konkrete Spielabnahme. Forever wird in seinem separaten Projekt vorbereitet und benötigt einen eigenen passenden Client.

`Setup.bat` führt die obigen Schritte mit Wiederaufnahme abgeschlossener Stufen aus. Ein vorhandener passender Windows-Build wird verwendet. Bei Bedarf bleiben die einzelnen `Manage.ps1`-Aktionen verfügbar. `Console.bat` erlaubt einzelne Worldserver-Befehle; das Ergebnis ist im lokalen Log zu prüfen, eine Queuebestätigung allein ist kein Ausführungserfolg.

## Stoppen, Sichern und Wiederherstellen

Spieler ausloggen, dann `Stop.bat` ausführen. Der Supervisor schickt `server shutdown 0` an den eigenen Worldserver und wartet auf dessen Ende. Erst anschließend beendet er seinen Authprozess und fährt seine MySQL-Instanz herunter. Bei einem Timeout erfolgt kein erzwungenes Beenden von Worldserver oder MySQL. Nicht einfach das Startfenster schließen.

Nach dem Stopp `Backup.bat` ausführen. Die fertige Sicherung steht unter `backups/<Zeitstempel-ID>`, inklusive Datenbank, lokaler Einstellungen und Zertifikate. Ein fehlgeschlagener Kopiervorgang bleibt als `incomplete-*` erkennbar. Extrahierte Karten und Core-Binaries sind reproduzierbar und nicht Teil der Sicherung.

Wiederherstellung erfolgt zunächst manuell: alle Dienste stoppen, vorhandenen Zustand separat sichern, denselben Repo-/Core-Stand und dieselbe MySQL-Version verwenden, Inhalte des Snapshots in den ursprünglichen Projektpfad kopieren, Clientdaten/Binaries bereitstellen und `Check` sowie Neustart-/Persistenztests durchführen. Bei einem anderen Zielpfad lokale Pfade bewusst anpassen; die Root-Prüfung verhindert unbemerkte Verwendung fremder Pfade. Ein Restore wird erst nach einem echten Test als zuverlässig bezeichnet.

## Fehler und Updates

- Belegte Ports: andere TBC-/Forever-/Retail-Instanz sauber stoppen. Das Paket tötet keine Prozesse anhand ihres Namens.
- Halb fertige DB-Initialisierung: Verzeichnis und Logs erhalten. Nicht `runtime/mysql-data` löschen, um eine Fehlermeldung loszuwerden.
- Verwaiste Prozesse nach geschlossenem Supervisor: keine automatischen PID-/Namens-Kills. Prozesse, Pfade und Datenbankzustand prüfen. Erst den Worldserver geordnet beenden; für die anschließende MySQL-Abschaltung die Projektfunktion `Stop-LocalMySQL` mit dem passenden Root und dessen Einstellungen verwenden. Ein nackter `mysqladmin --defaults-file=...`-Aufruf ist wegen möglicher fremder `.mylogin.cnf`-Einträge ungeeignet.
- Versionswechsel: zuerst Offline-Backup; Core-/Client-/DB-Pins gemeinsam prüfen. Für den ersten Wechsel eine neue Testinstallation verwenden. Source/Build/Extract/Database sind bewusste Wartungsschritte, kein blindes In-Place-Update.
