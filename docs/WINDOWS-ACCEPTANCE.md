# Windows- und Spielabnahme

Stand der Vorbereitung: Windows-Skript-/Konsolenprüfungen sind bestanden; vollständiger Core-/DB-Lauf und Gameplay haben jeweils eigene Nachweise in [VALIDATION.md](VALIDATION.md). Diese Liste dient zusätzlich der Abnahme auf dem tatsächlichen Windows-Spielrechner. Ergebnisse stets mit Windows-Version, Repo-Commit, Core-Commit, Clientbuild und Logpfad dokumentieren.

## Technischer Windows-Test

- [ ] Portable Tests und Syntaxprüfung auf Windows bestanden.
- [ ] Source-Pin stimmt; C++-Build und Installation erfolgreich; beide Server-EXEs starten ohne fehlende DLLs.
- [ ] SHA-256 des Datenbankarchivs geprüft; DB-Import und Core-Updates ohne Fehler abgeschlossen.
- [ ] EXE-Clientbuild und aktive CASC-Zeile stimmen; maps/dbc/gt/vmaps/mmaps aus genau dieser Installation erzeugt.
- [ ] Wiederholtes Configure erhält Passwörter und Daten; vorhandene TBC-Installation bleibt verwendbar.
- [ ] Fremder Prozess auf 1119/8081/8085 bzw. eigenem MySQL-Port verhindert den Start, bleibt unverändert am Leben.
- [ ] Zertifikat/Launcher/hosts bzw. Portal passen; zwei normale Accounts können sich anmelden und die Welt betreten.
- [ ] Stop beendet zuerst den Worldserver, danach Auth/MySQL; erneuter Start gelingt.
- [ ] Backup bei laufendem Server wird verweigert; Offline-Backup und Restore in kontrollierter Testinstallation bestanden.

## Mindest-Spielumfang

Mit wegwerfbaren Testaccounts und ohne GM-Abkürzungen prüfen:

- [ ] Charaktererstellung, Relog und Serverneustart; Position, Inventar und Fortschritt erhalten.
- [ ] Zusammenhängende Starterquests bis mindestens Stufe 10 für die gewünschten Fraktionen.
- [ ] Kampf, Ressourcen, Heilung, Auren/Cooldowns, Loot, XP, Tod und Wiederbelebung.
- [ ] Trainer, Talente, Händler/Reparatur, Bank, Ruhestein und Flug-/Transportwege.
- [ ] Zwei Accounts gleichzeitig: Gruppe, Chat, Handel, gemeinsame Kills und Questfortschritte.
- [ ] Post mit Geld/Gegenständen; AH einstellen/kaufen/abbrechen, korrekte Zustellung nach Relog/Neustart.
- [ ] Gewählte Berufe: sammeln, lernen, herstellen, Fortschritt speichern.
- [ ] Ein konkret benannter Dungeon vollständig: Bosse, Mechaniken, Loot, Wipe/Rückkehr und Reset.
- [ ] Weitere gewünschte Klassen/Gebiete/Instanzen jeweils konkret benennen und prüfen.

Nicht automatisch abgedeckt: alle Klassen, kompletter Level-Verlauf, neue Raids, sämtliche Questketten, Retail-Kampagne, Mythic+ oder PvP. Dokumentierte Einschränkungen sind zulässig; Abstürze, ungespeicherter Fortschritt oder blockierende Kernabläufe sind kein „bestanden“.
