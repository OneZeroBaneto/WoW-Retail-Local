# Verifizierter Vorbereitungsstand

Stand: 28.10.2026. Zielplattform Windows x64; geprüft auf macOS mit PowerShell 7.6.9, Python 3 und Apple clang++.

## Lokale Ergebnisse

| Prüfung | Ergebnis |
| --- | --- |
| `tests/Run.Tests.ps1` | 19 von 19 bestanden |
| `tests/Parse-All.ps1` | Alle 7 PowerShell-Dateien fehlerfrei geparst |
| `tests/ConsoleProbe.py` | Gepatchter Original-Konsolencode kompiliert, beide Pipe-Befehle und Antworten geprüft, beendet |
| Ungepatchter Konsolencode | Erwarteter Fehler reproduziert: Exit 7, keine Kommandobearbeitung |
| `Manage.ps1 -Action Check` auf Mac ohne lokale Einrichtung | Erwarteter Exit 2 mit offenen Windows-Voraussetzungen |
| `Build` / `Start` auf Mac | Erwarteter Exit 1; kein Runtime-Ordner und keine Zugangsdaten angelegt |
| Unabhängige Nachprüfung | Vier konkrete Befunde korrigiert und erneut geprüft |

Die 19 Tests prüfen Konfiguration und wiederholte Ausführung, getrennte Datenbankidentität, Pfade mit Leerzeichen, Secret-Erhalt, falsche Builds/Hashes, Shell-freie Prozessargumente, Exitfehler, Extraktionsmarker, echte Child-Prozesspipes, belegte Ports, unveränderte Fremdprozesse, Source-Pins, CASC-Metadaten, Offline-Snapshot-Inhalt, exakte Patchbindung, isolierte MySQL-Umgebung, echten lokalen Git-Fetch samt Patch und Wiederholung, vorhandene Zertifikate sowie Laufzeitbibliotheken. Sie verwenden temporäre synthetische Daten, keinen Spielclient und keine produktive MySQL-Instanz.

## Quellenbindung

- Edition: `retail`
- Core: `2245496d5aebb9351dc05a4d54995f94007051a2`
- Client: `12.1.5.70575`
- Konsolenpatch SHA-256: `487e2a2d502ac732ca7889d17d43398ca718ea957bde683dafb130fbb9ba30f3`
- `worldserver.conf.dist` Git-Blob: `ad7a0a08f4b1238abca96169587d16d69c62e03b`
- `bnetserver.conf.dist` Git-Blob: `6527ba48bbbe23ed4667565d58855cbc0dee3ec9`
- Unveränderte CLI-Testquelle Git-Blob: `5e8fd69a0728ee06c13c739181ac6b3c82930817`

Die drei übernommenen Quelldateien wurden gegen den jeweiligen festen GitHub-Commit abgeglichen. Der Source-Vorbereitungstest verwendet einen lokalen Git-Testremote; der vollständige Upstream wird erst beim Windows-Schritt `Source` geladen. TDB-Release und dessen erwarteter SHA-256 sind festgelegt; der echte Download wird erst bei `DatabaseFiles` überprüft.

## Noch offen

- Windows-CI: Definition vorhanden, noch nicht ausgeführt; lokale Repos sind noch nicht auf GitHub veröffentlicht.
- Vollständiger TrinityCore-Build mit Windows-Abhängigkeiten und Start aller echten EXEs.
- Reale MySQL-Erstinstallation, TDB-Import und Clientdatenextraktion.
- Windows-Zertifikate, Client-/Launcher-Kompatibilität, Login und Weltbeitritt.
- Echter Core-Shutdown, Neustart/Persistenz, Backup und Restore auf Windows.
- Sämtliche Gameplaypunkte aus [WINDOWS-ACCEPTANCE.md](WINDOWS-ACCEPTANCE.md).

Der C++-Probe verwendet auf Mac simulierte Win32-Grenzfunktionen und eine kleine Spielwelt. Er beweist keine Windows- oder Gameplay-Abnahme. Die Windows-CI verwendet dieselbe CLI-Datei mit echtem Windows SDK, bleibt aber ebenfalls ein begrenzter Konsolentest.
