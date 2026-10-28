# Retail: Voraussetzungen für den ersten echten Windows-Spieltest

Stand: 28.10.2026. Untersucht: TrinityCore `2245496d5aebb9351dc05a4d54995f94007051a2`, Client `12.1.5.70575`, TDB `1210.26091`. Der Nutzer besitzt bislang nur Retail. Diese Recherche belegt Quellcode, veröffentlichte Build-Ergebnisse und tatsächlich vorhandene TDB-Daten. Sie ist kein erfolgreicher Clientlogin oder Gameplaytest.

## 1. Konkreter Windows-Launcher

Die offizielle TrinityCore-Clientanleitung verlangt für master einen Custom Launcher und `SET portal "127.0.0.1"`; ausdrücklich keine Adresse `localhost`. Ihr Arctium-Link führt inzwischen zu Burralis. [TrinityCore-Anleitung](https://trinitycore.info/install/Client-Setup), [Burralis](https://burralis.io/)

Der Anbieter nennt aktuell **Burralis Game Client Launcher 1.6.1.224**, veröffentlicht am 04.09.2026. Die Liste umfasst Windows-x64-Mainline-Clients 9.x bis 12.x. Die EXE heißt `Burralis Game Launcher.exe`, gehört direkt neben die Spiel-EXE, hier `_retail_/Wow.exe`, und benötigt für Mainline kein `--version`-Argument. Der Portal-Eintrag steht folglich in `_retail_/WTF/Config.wtf`; beide Programme müssen beim Bearbeiten geschlossen sein. Für Loopback und das eigene LAN akzeptiert der Launcher laut Anleitung selbstsignierte TLS-Zertifikate. [Download/Clientliste](https://burralis.io/downloads/), [Verwendung und TLS](https://burralis.io/usage/)

Der Anbieter veröffentlicht für die Windows-EXE SHA-256 `b5359a972f760905f572aafc4066d945f6382cec2a521d555dd58d2861ef7c1c` und verlangt eine gültige digitale Signatur. AVX2 und AES-NI sind Voraussetzung. Der Download wird erst nach zwei Lizenzzustimmungen mit einem kurzlebigen Link freigegeben; diese Recherche hat keine Zustimmung abgegeben und keinen Launcher heruntergeladen. Die allgemeine 12.x-Angabe ist **kein Beleg eines getesteten Logins mit exakt 70575**. [Downloadseite](https://burralis.io/downloads/)

**Folgerung für das Paket:** Launcherpfad, EXE-Version und Portal sind echte Vorbedingungen. Ein frisch aktualisierter Retail-Client mit anderer Buildnummer darf nicht durch bloßes Umschreiben des Lockfiles als kompatibel gelten. Der dokumentierte lokale Zertifikatsaufbau enthält die IP `127.0.0.1` als SAN und passt zu diesem Loopback-Ziel; eine öffentliche Hosting-Konfiguration ist damit nicht geprüft.

## 2. Account und Charaktererstellung

`bnetaccount create EMAIL PASSWORD` ist im Core ein Konsolenbefehl. Ohne drittes Argument erzeugt er sowohl den Battle.net-Account als auch einen WoW-Unteraccount. Dessen interner Name lautet `<BNet-ID>#1`; eingeloggt wird mit der eingegebenen E-Mail. Der normale Account erhält dabei keine GM-Rechte. [Befehl](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/scripts/Commands/cs_battlenet_account.cpp#L70), [Accountanlage](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/game/Accounts/BattlenetAccountMgr.cpp#L33)

Das aktuelle Auth-Schema hat `account.expansion` standardmäßig auf 11. Das ausgelieferte Worldserver-Config hat ebenfalls `Expansion = 11`, `StartPlayerLevel = 1`, `CharacterCreating.Disabled = 0` und ausgeschaltete Rassen-/Klassen-Sperrmasken. Für einen Menschenkrieger ist daher kein pauschales Expansion-Update nötig. Allied-Race-Freigaben sind ein separates Thema; globale Freigaben würden noch keine funktionierende Startstrecke aller Rassen belegen. [Auth-Schema](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/sql/base/auth_database.sql#L25), [Worldserver-Konfiguration](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/worldserver/worldserver.conf.dist#L709)

Die Auth-Migration `2026_10_23_00_auth.sql` enthält ausdrücklich Build 70575 und Windows-x64-Authdaten. Der vorbereitete Datenbank-Update-Schritt muss diese Migration ausführen; allein das Setzen von `realmlist.gamebuild` genügt nicht. [Auth-Migration](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/sql/updates/auth/master/2026_10_23_00_auth.sql)

## 3. Klassischer Start statt ungeprüfter NPE-Strecke

Der Client sendet bei der Charakteranlage `UseNPE`. `Player::Create` verwendet den NPE-Start nur, wenn dieses Bit gesetzt ist **und** für das Rasse-/Klassenpaar gültige optionale NPE-Daten geladen wurden. Andernfalls nimmt er `playercreateinfo.map` und die normalen Positionsfelder. Der Loader akzeptiert NPE-Daten nur, wenn `npe_map` und die vier NPE-Positions-/Orientierungsfelder sämtlich nicht NULL sind. Ein dokumentierter Config-Schalter zum generellen Abschalten von NPE wurde im festgelegten Core nicht gefunden. [Paketdefinition](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/game/Server/Packets/CharacterPackets.cpp#L471), [Positionswahl](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/game/Entities/Player/Player.cpp#L422), [Datenloader](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/game/Globals/ObjectMgr.cpp#L3863)

Für den ersten Test ist **Mensch/Krieger, normaler Nordhain-Start** ein begründetes Ziel. Falls die Clientoberfläche ausschließlich NPE anbietet, kann ein separat dokumentiertes, eng auf `race=1 AND class=1` begrenztes Datenbank-Overlay die optionalen `npe_*`-Felder auf NULL setzen. Der vorhandene Core fällt dann auch bei `UseNPE=true` auf den normalen Start zurück. Das wäre eine bewusste Testprofil-Anpassung, keine Reparatur oder Abnahme von Exile's Reach. Eine solche Änderung wurde durch diese Recherche nicht ausgeführt.

## 4. Echte TDB-Daten für Nordhain geprüft

Das bereits heruntergeladene Archiv `downloads/tdb.7z` wurde read-only mit `tar -xOf` durchlaufen. Der selbst berechnete SHA-256 stimmt mit dem Lockfile überein: `fc5513334d7534a19f533124a95910193c8150379e5ed8d0db3e547ac2c5a3f5`. Grundlage ist `TDB_full_world_1210.26091_2026_09_09.sql`; es wurde dafür keine Datenbank gestartet oder verändert. [TDB-Release](https://github.com/TrinityCore/TrinityCore/releases/tag/TDB1210.26091)

| Bereich | Tatsächliche Daten im Dump |
| --- | --- |
| Mensch/Krieger | `race=1`, `class=1`, normal `map=0`, `x=-8914.57`, `y=-133.909`, `z=80.5378`, Orientierung `5.10444` |
| NPE desselben Paares | Map 2175, Transport 29, Intro-Szene 2236; somit ein anderer Ablauf |
| Spawns beim normalen Start | 259 Spawnzeilen innerhalb 250 Einheiten 3D-Distanz; darunter 51 Worgs und 23 Spione. Die Zahl zählt Datenzeilen, nicht gleichzeitig sichtbar bewiesene NPCs |
| Marshal McBride | Entry 197, nächster Spawn ca. 3,8 Einheiten entfernt, Phase 0/PhaseGroup 0, 30 Queststarter-Verknüpfungen |
| Blackrock Worg | Entry 49871, nächster Spawn ca. 46,4 entfernt, Phase 0/PhaseGroup 0/PhaseUseFlags 0, Difficulty 0, Faction 32, `unit_flags=0`, Health-/DamageModifier jeweils 1 |
| Worg-Loot | Difficulty-`LootID=49871`: Item 3300 mit 10 %, Item 62328 mit 90 %, jeweils 1 Stück und `QuestRequired=0` |
| Blackrock Spy | Entry 49874, nächster Spawn ca. 55,3 entfernt, Phase 0/PhaseGroup 0, `unit_flags=0`, SmartAI, LootID 49874, GoldMin/Max 1–5 |
| Krieger-Startquest | Quest 28766 „Beating Them Back!“, McBride als Starter, `AllowableClasses=1`, `PrevQuestID=0`; Ziel 254141 verlangt sechs Kills von Entry 49871 |

Der Core verwendet beim Kreaturenloot den `LootID` aus `creature_template_difficulty`; die hier geprüfte Verknüpfung ist daher die relevante und nicht ein historisches Feld der Kreaturenvorlage. [Creature::GetLootId](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/game/Entities/Creature/Creature.cpp#L1350)

Die zum Pin gehörenden aktuellen World-Updates enthalten für Quest 28766 nur eine Emote-Korrektur; die recherchierten Entries 49871/49874 werden dort nicht geändert. Es bleibt sinnvoll, dieselben Daten nach dem echten Import erneut zu prüfen. [Emote-Update](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/sql/updates/world/master/2026_09_20_04_world.sql#L167)

Diese Prüfung belegt eine passende bevölkerte Datenbasis. Sichtbarkeit im konkreten Charakterzustand, korrekt skalierte Lebenspunkte, Trefferberechnung, KI, Questfortschritt und tatsächlich erhaltene Beute müssen im laufenden Spiel nachgewiesen werden.

## 5. Windows-Build-Evidenz

Für genau den Core-Pin ist der Upstream-Run [40596069843](https://github.com/TrinityCore/TrinityCore/actions/runs/40596069843) erfolgreich. Er veröffentlicht `TrinityCoreMasterWin64VS2022`, Artifact-ID `12776448140`, 188.365.861 Bytes, Digest `sha256:b401a22ec5dad5ba23461e501d1c0e5c5310f26484c9deb0bb2a5a98371fab5f`. Die API meldete am Recherchezeitpunkt nicht abgelaufen und Ablauf am 25.01.2027. [Artifact-Metadaten](https://api.github.com/repos/TrinityCore/TrinityCore/actions/runs/40596069843/artifacts)

Der Workflow baut den Core samt Tools, kopiert externe DLLs und führt bei `bnetserver` und `worldserver` `--version` aus. Er prüft weder eine reale Datenbankinstallation noch Clientlogin oder Gameplay. Er enthält auch nicht den lokalen Konsolen-Patch. Der Workflow kopiert erst MySQLs eigene `libcrypto*`/`libssl*`-Abhängigkeiten und danach die OpenSSL-Bibliotheken; eine lokale DLL-Übernahme sollte diesen Fall abdecken. [Exakter Workflow](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/.github/workflows/win-x64-build.yml)

## 6. Abnahme für „Login, Charakter, Mobs, Töten“

1. Passenden Clientbuild und Launcher prüfen; Daten aus genau diesem Client vollständig extrahieren. Der Worldserver prüft beim Start mehrere klassische Map-/VMap-Startkoordinaten einschließlich des menschlichen Startgebiets. [Map-Startprüfung](https://github.com/TrinityCore/TrinityCore/blob/2245496d5aebb9351dc05a4d54995f94007051a2/src/server/game/World/World.cpp#L1264)
2. Auth-/Character-/World-/Hotfix-Datenbanken importieren, Updates ausführen und den realen Inhalt der Starterdaten prüfen.
3. Über den Core einen normalen Account anlegen, mit E-Mail anmelden, Realm auswählen, Menschenkrieger erstellen und Nordhain betreten.
4. McBride sehen, Quest 28766 annehmen, sechs Worgs regulär töten, Loot aufnehmen, Quest abgeben; keinen GM-Kill als Nachweis verwenden.
5. Sterben/wiederbeleben, ausloggen, geordneten Serverstopp und Neustart durchführen. Level/XP, Position, Tascheninhalt und Queststatus müssen erhalten bleiben.

Solange diese Schritte nicht mit dem echten Windows-Client durchgeführt wurden, sind Build-/Skript- und Datenprüfungen lediglich belastbare Vorbereitung. Andere Rassen, Klassen, Gebiete und Instanzen benötigen anschließend eigene Abnahmewege.
