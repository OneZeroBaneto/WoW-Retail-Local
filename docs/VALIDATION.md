# Verifizierter Vorbereitungsstand

Stand: 28.10.2026. Zielplattform Windows x64. Entwicklung auf macOS mit PowerShell 7.6.9, Python 3 und Apple clang++; zusätzlich echte Windows-Runner-Prüfungen im öffentlichen Repository.

## Lokale Ergebnisse

| Prüfung | Ergebnis |
| --- | --- |
| `tests/Run.Tests.ps1` | 19 von 19 bestanden |
| `tests/Readiness.Tests.ps1` | 8 von 8 bestanden: Datenlücken, Portal/Restore, nachträgliche Client-Einstellungen, Account-Erhalt, Setup-Wiederaufnahme, Buildnummern über 65535, gültige/mismatched/leere/abgelaufene Zertifikate |
| `tests/Parse-All.ps1` | Alle 16 PowerShell-Dateien fehlerfrei geparst |
| `tests/ConsoleProbe.py` | Gepatchter Original-Konsolencode kompiliert, beide Pipe-Befehle und Antworten geprüft, beendet |
| Ungepatchter Konsolencode | Erwarteter Fehler reproduziert: Exit 7, keine Kommandobearbeitung |
| `Manage.ps1 -Action Check` auf Mac ohne lokale Einrichtung | Erwarteter Exit 2 mit offenen Windows-Voraussetzungen |
| `Build` / `Start` auf Mac | Erwarteter Exit 1; kein Runtime-Ordner und keine Zugangsdaten angelegt |
| Unabhängige Nachprüfung | Ursprüngliche vier Befunde korrigiert. First-play-Nachprüfung: zusätzlich Zertifikats-Wiederaufnahmefehler reproduziert, korrigiert und Regression grün |

Die 19 Tests prüfen Konfiguration und wiederholte Ausführung, getrennte Datenbankidentität, Pfade mit Leerzeichen, Secret-Erhalt, falsche Builds/Hashes, Shell-freie Prozessargumente, Exitfehler, Extraktionsmarker, echte Child-Prozesspipes, belegte Ports, unveränderte Fremdprozesse, Source-Pins, CASC-Metadaten, Offline-Snapshot-Inhalt, exakte Patchbindung, isolierte MySQL-Umgebung, echten lokalen Git-Fetch samt Patch und Wiederholung, vorhandene Zertifikate sowie Laufzeitbibliotheken. Sie verwenden temporäre synthetische Daten, keinen Spielclient und keine produktive MySQL-Instanz.

## Quellenbindung

- Edition: `retail`
- Core: `2245496d5aebb9351dc05a4d54995f94007051a2`
- Client: `12.1.5.70575`
- Konsolenpatch SHA-256: `487e2a2d502ac732ca7889d17d43398ca718ea957bde683dafb130fbb9ba30f3`
- `worldserver.conf.dist` Git-Blob: `ad7a0a08f4b1238abca96169587d16d69c62e03b`
- `bnetserver.conf.dist` Git-Blob: `6527ba48bbbe23ed4667565d58855cbc0dee3ec9`
- Unveränderte CLI-Testquelle Git-Blob: `5e8fd69a0728ee06c13c739181ac6b3c82930817`

Die übernommenen Quelldateien wurden gegen den festen GitHub-Commit abgeglichen. Zusätzlich wurde der vollständige echte Core lokal über `Prepare-CoreSource` geladen und exakt gepatcht. Das echte TDB-Archiv wurde heruntergeladen; SHA-256 stimmt mit `sources.lock.json` überein.

## Tatsächlich ausgeführte Datenbankprüfung auf Mac

Ein eigener isolierter MySQL-8.0-Testcontainer ohne Netzwerkfreigabe wurde ausschließlich für die Entwicklung verwendet. Windows benötigt keinen Container. Der echte World-Dump sowie das Auth-Basisschema und alle acht Auth-Updates des festen Core-Stands wurden importiert.

| Live-SQL-Prüfung | Ergebnis |
| --- | --- |
| Auth-Schlüssel für 70575 / Win / x64 / WoW | 1 |
| Normaler Menschen-Krieger-Start auf Map 0 | 1 |
| Ungephaste Worg-/Spion-Spawns im Umkreis 250 | 74 |
| Positive, nicht questgebundene Lootverknüpfungen | 3 |
| McBride-Startquest 28766 mit sechs Worg-Kills | 1 |

Negative Kontrollen in zurückgerollten Transaktionen entfernten jeweils Spawns, Lootverknüpfungen oder den Buildschlüssel. Der zugehörige Auditwert fiel auf 0; fehlender Inhalt wird also tatsächlich erkannt. Der Nordhain-Startwechsel `npe_map: 2175 → NULL → 2175` wurde ebenfalls innerhalb einer Transaktion ausgeführt und zurückgerollt; genau eine Rasse-/Klassenzeile war betroffen. Diese Datenprüfung beweist keine Sichtbarkeit oder funktionierende Kämpfe im Client.

## Windows-Nachweise

- [Erfolgreicher Windows-Skript- und Konsolenlauf](https://github.com/OneZeroBaneto/WoW-Retail-Local/actions/runs/40756771453): portable Tests und gepatchter originaler C++-Konsolencode mit echtem Windows SDK und Prozesspipes.
- Der erste Vollbuild stoppte vor CMake wegen eines nicht mehr vorhandenen vorinstallierten MySQL-8.0-Pfads. Der Standard-Runner enthält inzwischen MySQL 8.4. Das Setup lädt jetzt MySQL 8.0.46 explizit und prüft SHA-256.
- [Vollständiger Windows-Build mit CTest, DB-Import und BNet-REST-Prüfung](https://github.com/OneZeroBaneto/WoW-Retail-Local/actions/runs/40758932831): **bei diesem Dokumentstand noch in Arbeit**. Ein erfolgreiches Ergebnis wird erst nach Auswertung bestätigt. Die Paketdatei `verification.json` trägt die tatsächlich erreichten Prüfungen.
- Der [Upstream-Windows-Build desselben Core-Pins](https://github.com/TrinityCore/TrinityCore/actions/runs/40596069843) war erfolgreich; er enthält unseren Konsolenpatch und unsere DB-/REST-Abnahme nicht und ist daher kein Ersatz für den eigenen Lauf.

## Noch offen

- Abschluss/Auswertung des eigenen vollständigen Windows-Builds, Core-Tests, MySQL-Erstinstallation und BNet-REST-Starts.
- Passender Windows-Spielclient, Clientdatenextraktion, Launcher-Kompatibilität, Accountprüfung im laufenden vollständigen Server, Clientlogin und Charaktererstellung.
- Weltbeitritt, sichtbare Gegner, Kampf, Beute, Questfortschritt, Tod/Wiederbelebung.
- Echter vollständiger Worldserver-Shutdown, Neustart/Persistenz, Backup und Restore auf Windows.
- Weitere Gameplaypunkte aus [WINDOWS-ACCEPTANCE.md](WINDOWS-ACCEPTANCE.md).

Der C++-Probe verwendet auf Mac simulierte Win32-Grenzfunktionen und eine kleine Spielwelt. Die Windows-CI verwendet dieselbe CLI-Datei mit echtem Windows SDK. Beides bleibt ein begrenzter Konsolentest. Ein grüner Build, ein vorhandener Spawn oder ein erfolgreicher HTTP-Endpunkt darf nicht als bestandener Spieltest bezeichnet werden.
