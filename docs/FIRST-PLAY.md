# Erster Spieltest auf Windows

**Benötigt wird Retail 12.1.5.70575.** Die Versionsnummer unten links im Client oder in den Eigenschaften von `_retail_/Wow.exe` prüfen. „Retail installiert“ allein genügt nicht. Bei einem anderen Build stoppt die Vorbereitung. Die Buildnummer im Lockfile nicht einfach ändern: Protokoll, Daten und Core müssen zusammenpassen.

Das Ziel dieses ersten Tests ist ein normaler Menschen-Krieger in Nordhain: anmelden, erstellen, bewegen, Worgen bekämpfen, Beute aufnehmen, Startquest abschließen und den Charakter nach einem Neustart wiederfinden. Die übrige Retail-Welt enthält unvollständige Inhalte.

## Einmalig vorbereiten

1. Repository nach `C:\WoW-Retail-Local` klonen oder das Source-ZIP dort entpacken. [Windows-Voraussetzungen](WINDOWS-SETUP.md) installieren. Für ein passendes vorgebautes Serverpaket werden Visual Studio, Boost und CMake nicht gebraucht. Git, PowerShell, MySQL, OpenSSL und 7-Zip bleiben erforderlich.
2. Ein verfügbares Paket **WoW-Retail-Windows-Server** aus einem erfolgreichen [Windows-Build](https://github.com/OneZeroBaneto/WoW-Retail-Local/actions/workflows/windows-build.yml) entpacken: Der Ordner `runtime` gehört direkt in dieses Projekt. `verification.json` dokumentiert, was der Runner geprüft hat. Keine alten Binaries aus anderen Core-Ständen dazumischen.
3. `Configure.bat` ausführen, in `local/settings.json` die Pfade einstellen. `clientRoot` zeigt auf den Hauptordner mit `.build.info`, `Data` und `_retail_`. Generierte Passwörter beibehalten. Danach erneut `Configure.bat`.
4. `Setup.bat` starten. Es prüft zuerst den Clientbuild, führt die noch fehlenden Schritte aus und prüft anschließend die Auth-, Gegner-, Beute- und Questdaten. Quellcode und Datenbank werden automatisch heruntergeladen und geprüft. Ohne fertige Binaries wird lokal kompiliert. Die vollständige Karten- und Wegfindungsextraktion kann mehrere Stunden dauern und viel freien Speicher benötigen; keine feste Fertigstellungszeit ist zugesichert.
5. Den [Burralis Game Launcher](https://burralis.io/) selbst herunterladen und seine Bedingungen selbst prüfen. Erwartet: **1.6.1.224**, Datei `Burralis Game Launcher.exe` direkt neben `_retail_/Wow.exe`. SHA-256: `b5359a972f760905f572aafc4066d945f6382cec2a521d555dd58d2861ef7c1c`. `Client.bat` prüft Hash, Windows-Signatur und AVX2/AES-NI. Ein anderer Launcherstand wird nicht ungeprüft gestartet. Kein Launcher ist im Paket enthalten.

`Setup.bat` aktiviert bewusst das Profil **Nordhain für neue Menschen-Krieger**: Nur `playercreateinfo.npe_map` für Rasse 1/Klasse 1 wird auf NULL gesetzt. So verwendet der Core die vorhandene klassische Startposition, auch wenn der Client den Einführungsmodus anfragt. Originalwert und Core-Stand werden lokal gesichert; vorhandene Charaktere werden nicht versetzt. Zum Zurücksetzen bei gestopptem Server: `pwsh -File scripts/Starter.ps1 -Restore`. Andere Klassen oder Startgebiete sind damit nicht abgenommen.

## Spielen und wirklich prüfen

1. `Start.bat` öffnen und geöffnet lassen. Auf die Meldung warten, dass alle Dienste bereit sind.
2. `Account.bat` ausführen. Es legt `player@local` als normalen Account samt WoW-Unteraccount an und prüft das erzeugte Passwort durch eine echte Anmeldung am lokalen BNet-REST-Dienst. Passwort steht ausschließlich in `local/game-account.json`. Ein vorhandenes Passwort wird nicht zurückgesetzt. Diese Authprüfung ersetzt noch keinen Clientlogin.
3. WoW schließen, dann `Client.bat` starten. Es sichert die bisherigen Client-Einstellungen und setzt das Portal auf `127.0.0.1`. Im Launcher/Client mit dem lokalen Account anmelden. Der passende Launcher muss den lokalen Server unterstützen; der exakte End-to-End-Login ist noch zu testen.
4. **Mensch → Krieger → neuer Charakter.** In Nordhain einloggen. Vor Sergeant McBride stehen. Sichtbare Gegner sollten unter anderem Schwarzfelsworgen und Schwarzfelsspione sein.
5. Bei McBride die Krieger-Startquest „Beating Them Back!“ annehmen (Quest-ID 28766; Titel kann lokalisiert sein). Sechs Worgen töten, Beute aufnehmen und Quest abgeben. Bewegung, Angriff/Zauber, Schaden, Tod/Geist/Wiederbelebung, EP, Inventar und Ausrüstung prüfen. Keine GM-Befehle als Ersatz für diesen normalen Spielerablauf verwenden.
6. Ausloggen, `Stop.bat` ausführen, auf das Ende warten, erneut `Start.bat` und `Client.bat`. Charakter, Position, Beute und Questfortschritt müssen erhalten bleiben.
7. Bei gestopptem Server `Backup.bat` ausführen. Ein Restore bleibt eine eigene Abnahme, siehe [Prüfliste](WINDOWS-ACCEPTANCE.md).

Für die Rückkehr zu offiziellem Retail WoW/Launcher schließen und `Restore-Client.bat` ausführen. Unveränderte Einstellungen werden bytegenau wiederhergestellt. Hat WoW inzwischen Grafik-/Spieleinstellungen gespeichert, wird nur das Portal zurückgesetzt und der Rest erhalten. Ein inzwischen auf einen anderen Server geändertes Portal wird nicht überschrieben.

## Wenn etwas scheitert

- Genaue Fehlermeldung und Clientversion festhalten; `Diagnose.bat` erzeugt eine Zusammenfassung ohne Passwörter oder Rohlogs.
- `Check.bat` prüft die Vorbereitung, `CheckGame.bat` die tatsächlich installierten Startdaten. Eine grüne Datenprüfung bedeutet noch keinen bestandenen Spieltest.
- Lokale Logs liegen in `runtime/logs`. Sie können vertrauliche Angaben enthalten; nicht ungeprüft öffentlich hochladen. Keine komplette `local`- oder `runtime`-Kopie veröffentlichen.
- Bei einem Setupfehler den Zustand behalten. Erneuter Aufruf überspringt erfolgreich abgeschlossene Stufen; eine beschädigte oder fremde Datenbank wird nicht gelöscht.
- Andere TBC-/Forever-/Retail-Server vorher sauber stoppen. Es werden keine fremden Prozesse beendet.
