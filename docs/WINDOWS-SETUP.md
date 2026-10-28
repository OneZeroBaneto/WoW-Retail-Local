# Windows-Setup

## Voraussetzungen

Ziel: Windows x64, empfohlen Windows 11; native Ausführung, ohne Docker oder WSL. Benötigt werden PowerShell 7.4+, Git, CMake 3.24+, Visual Studio 2022 ab 17.4 mit „Desktopentwicklung mit C++“ und Windows SDK, Boost x64 für MSVC 14.3, OpenSSL 3 x64, MySQL Server 8.0 ab 8.0.34 inklusive Client/Entwicklungsdateien und 7-Zip. Es genügt die MySQL-Installation; dieses Projekt verwendet einen eigenen Datenordner und startet seine eigene Instanz. Ein bereits vorhandener MySQL-Windowsdienst wird nicht verändert.

Die Defaultpfade erwarten Boost 1.86 unter `C:/local/boost_1_86_0` und OpenSSL unter `C:/Program Files/OpenSSL-Win64`. Andere passende Installationspfade lassen sich in den lokalen Einstellungen setzen. Laufzeit-DLLs müssen zur x64-Buildumgebung passen. Die erste Windows-Kompilierung steht noch aus.

Quelle: https://trinitycore.info/install/requirements/windows

## Reihenfolge

Alle Befehle im Projektverzeichnis in **PowerShell 7** ausführen:

```powershell
pwsh -NoProfile -File scripts/Manage.ps1 -Action Configure
notepad local/settings.json
```

`clientRoot` ist der WoW-Hauptordner mit `.build.info` und `Data`, nicht nur der Unterordner mit der EXE. Der im Lockfile genannte Clientbuild muss vorhanden sein. `relativeExe` steht in `sources.lock.json`: Forever aktuell `_forever_/Wow.exe`; Retail `_retail_/Wow.exe`. Der CASC-Produktname wird aus der aktiven passenden Zeile der `.build.info` gelesen, nicht aus dem Verzeichnisnamen geraten.

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
- `Build` kompiliert Release x64 mit zwei parallelen Jobs und installiert nach `runtime`. Anschließend werden `libmysql.dll`, `libcrypto-3-x64.dll`, `libssl-3-x64.dll` und der OpenSSL-Provider `legacy.dll` aus den eingestellten Installationen übernommen. Beide Server müssen `--version` erfolgreich ausführen und OpenSSL muss den lokalen Legacy-Provider laden, bevor ein Buildmarker geschrieben wird. Der Vorgang kann längere Zeit dauern.
- `DatabaseFiles` lädt das festgelegte 7z-Archiv, prüft dessen SHA-256 und übernimmt nur die beiden erwarteten SQL-Dateien.
- `Extract` prüft die EXE-Version, extrahiert Karten/Tabellen/Kollision/Wegfindung in ein neues Arbeitsverzeichnis und übernimmt erst vollständige Verzeichnisse. Frühere Daten bleiben als `runtime/data-previous-*` erhalten. Die Extraktion kann lange dauern.
- `Database` initialisiert ausschließlich die eigene MySQL-Instanz, importiert die Daten und wendet die Updates des festen Core-Stands an. Das Updater-Konto hat Rechte nur auf die vier Projekt-Datenbanken. Danach wird MySQL wieder beendet. Der normale Spielstart führt keine Datenbankmigrationen aus.
- `Certificates` erzeugt neue lokale Schlüssel/Zertifikate. Bestehende Schlüssel werden nicht ersetzt. Es wird dabei noch nichts im Windows-Zertifikatsspeicher oder in der hosts-Datei installiert.

MySQL startet mit `--no-monitor`, damit der Supervisor den tatsächlichen Serverprozess anhand seiner PID prüfen kann. MySQL-Clientaufrufe bekommen explizit Host/Port/Benutzer und ein prozesslokales `MYSQL_TEST_LOGIN_FILE` auf eine nicht vorhandene Datei. Dadurch können gespeicherte Anmeldungen einer anderen MySQL-Installation die Verbindung nicht umleiten. Das gilt auch für den Core-Updater. Quellen: [MySQL unter Windows](https://dev.mysql.com/doc/refman/8.0/en/windows-installation.html), [MySQL-Optionsdateien](https://dev.mysql.com/doc/refman/8.0/en/option-files.html).

## Clientanmeldung vorbereiten

**Forever:** Der Core erwartet `trinity.actual.battle.net`. Auf dem Windows-Spielrechner die Datei `C:\Windows\System32\drivers\etc\hosts` mit Administratorrechten öffnen und eine einzelne Zeile ergänzen:

```text
127.0.0.1 trinity.actual.battle.net
```

Das eigene öffentliche CA-Zertifikat kann für den aktuellen Windows-Benutzer importiert werden:

```powershell
Import-Certificate -FilePath .\runtime\certs\ca.crt -CertStoreLocation Cert:\CurrentUser\Root
```

Den Pfad und Fingerabdruck des importierten Zertifikats für die spätere Entfernung notieren. Nur dieses selbst erzeugte Zertifikat verwenden. Keine fremden CA- oder Server-Private-Keys übernehmen. Der Aufbau ist ausschließlich lokal.

Der [Forever Launcher](https://github.com/advocaite/foreverlauncher-releases/releases/tag/v2.4.2) muss auf den lokalen Server und den eigenen Client eingestellt werden. Die Kompatibilität mit dem festgelegten 70658-Client ist **noch auf Windows zu prüfen**. Die ältere Launcher-Veröffentlichung wird nicht automatisch als kompatibel behandelt oder ausgeführt. Ein Loginproblem ist ein Abnahmefehler, nicht durch Austausch der Buildnummer zu umgehen.

**Retail:** Laut [TrinityCore-Clientanleitung](https://trinitycore.info/install/Client-Setup) ist ein passender Custom Launcher erforderlich, beispielsweise der dort verlinkte Arctium-Launcher. Auf den festgelegten Build achten und Portal `127.0.0.1` benutzen. Dieses Paket liefert noch keinen verifizierten Retail-Launcher. Den Blizzard-Originalclient separat erhalten; normale Battle.net-Updates dürfen den festgelegten Testclient nicht unbemerkt ersetzen.

## Starten und Account anlegen

```powershell
.\Start.bat
```

Das Fenster offen lassen. Erst wenn es meldet, dass alle Dienste lokal lauschen, in einem zweiten Fenster `Console.bat` öffnen. Dort eingeben:

```text
bnetaccount create DEINNAME@LOCAL DEINPASSWORT
```

Das legt einen normalen Spielaccount an, keinen GM. Die Queuebestätigung allein ist keine Erfolgsmeldung: `runtime/logs/*world.out.log` auf das Ergebnis prüfen. Diese Logs und Konsolenverläufe können vertrauliche Inhalte enthalten und bleiben lokal. Für Administration kann man über dieselbe Konsole `.help` ohne führenden Punkt, also `help`, verwenden. Nicht ungeprüft GM-Rechte an Spielaccounts vergeben.

Danach den passenden Launcher öffnen und den Login praktisch testen. `Check.bat` prüft Vorbereitung; es beweist keinen erfolgreichen Spielereintritt.

## Stoppen, Sichern und Wiederherstellen

Spieler ausloggen, dann `Stop.bat` ausführen. Der Supervisor schickt `server shutdown 0` an den eigenen Worldserver und wartet auf dessen Ende. Erst anschließend beendet er seinen Authprozess und fährt seine MySQL-Instanz herunter. Bei einem Timeout erfolgt kein erzwungenes Beenden von Worldserver oder MySQL. Nicht einfach das Startfenster schließen.

Nach dem Stopp `Backup.bat` ausführen. Die fertige Sicherung steht unter `backups/<Zeitstempel-ID>`, inklusive Datenbank, lokaler Einstellungen und Zertifikate. Ein fehlgeschlagener Kopiervorgang bleibt als `incomplete-*` erkennbar. Extrahierte Karten und Core-Binaries sind reproduzierbar und nicht Teil der Sicherung.

Wiederherstellung erfolgt zunächst manuell: alle Dienste stoppen, vorhandenen Zustand separat sichern, denselben Repo-/Core-Stand und dieselbe MySQL-Version verwenden, Inhalte des Snapshots in den ursprünglichen Projektpfad kopieren, Clientdaten/Binaries bereitstellen und `Check` sowie Neustart-/Persistenztests durchführen. Bei einem anderen Zielpfad lokale Pfade bewusst anpassen; die Root-Prüfung verhindert unbemerkte Verwendung fremder Pfade. Ein Restore wird erst nach einem echten Test als zuverlässig bezeichnet.

## Fehler und Updates

- Belegte Ports: andere TBC-/Forever-/Retail-Instanz sauber stoppen. Das Paket tötet keine Prozesse anhand ihres Namens.
- Halb fertige DB-Initialisierung: Verzeichnis und Logs erhalten. Nicht `runtime/mysql-data` löschen, um eine Fehlermeldung loszuwerden.
- Verwaiste Prozesse nach geschlossenem Supervisor: keine automatischen PID-/Namens-Kills. Prozesse, Pfade und Datenbankzustand prüfen. Erst den Worldserver geordnet beenden; für die anschließende MySQL-Abschaltung die Projektfunktion `Stop-LocalMySQL` mit dem passenden Root und dessen Einstellungen verwenden. Ein nackter `mysqladmin --defaults-file=...`-Aufruf ist wegen möglicher fremder `.mylogin.cnf`-Einträge ungeeignet.
- Versionswechsel: zuerst Offline-Backup; Core-/Client-/DB-Pins gemeinsam prüfen. Für den ersten Wechsel eine neue Testinstallation verwenden. Source/Build/Extract/Database sind bewusste Wartungsschritte, kein blindes In-Place-Update.
