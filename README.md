# TailMon - Tailscale Device Monitor

![Bash](https://img.shields.io/badge/bash-5.0+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![ShellCheck](https://img.shields.io/badge/shellcheck-passed-success.svg)
![Systemd](https://img.shields.io/badge/systemd-enabled-important.svg)

**TailMon** ist ein in Bash geschriebener Tailscale-Geräteüberwachungsdienst, der Benachrichtigungen über ntfy sendet, wenn Geräte online oder offline gehen.

## 🚀 Features

- **Automatische Überwachung**: Regelmäßige Prüfung des Tailscale-Status
- **Flexible Benachrichtigungen**: ntfy-Benachrichtigungen bei Statusänderungen
- **Gerätespezifische Konfiguration**: Pro Gerät individuelle Aktionen konfigurierbar
- **Platzhalter-Unterstützung**: Dynamische Platzhalter in Benachrichtigungstiteln und -texten
- **Systemd-Integration**: Nahtlose Integration mit systemd-Timern
- **Zustandspeicherung**: Atomare Speicherung des letzten bekannten Gerätezustands
- **Logging**: Detailliertes Logging mit Zeitstempeln
- **Portabilität**: Rein in Bash geschrieben, läuft auf jeder Linux-Distribution
- **Qualitätssicherung**: ShellCheck-Validierung ohne Warnungen

## 📋 Voraussetzungen

- **Betriebssystem**: Linux (getestet auf Ubuntu, Debian, Arch)
- **Tailscale**: Installiert und konfiguriert
- **Bash**: Version 4.0 oder höher
- **curl**: Für ntfy-Benachrichtigungen
- **systemd**: Für Service-Management (optional)

## 📦 Installation

### 1. Klonen Sie das Repository

```bash
git clone https://github.com/ihre-organisation/tailmon.git
cd tailmon
```

### 2. Konfiguration erstellen

Kopieren Sie die Beispielkonfiguration und passen Sie sie an:

```bash
cp tailmon.conf.sample tailmon.conf
nano tailmon.conf
```

### 3. Installieren Sie den Service

Das Installationsskript erstellt automatisch den systemd-Service und -Timer:

```bash
sudo ./install-service.sh
```

Dies installiert:
- Den systemd-Service: `/etc/systemd/system/tailmon.service`
- Den systemd-Timer: `/etc/systemd/system/tailmon.timer`
- Aktiviert den Timer für automatische Ausführung

### 4. Konfiguration anpassen

Editieren Sie `tailmon.conf`:

```ini
# Ntfy-Server URL (Standard: ntfy.sh)
NTFY_SERVER=ntfy.sh

# Authentifizierungstoken (optional)
NTFY_TOKEN=ihre_token_hier

# Standard ntfy Topic
NTFY_TOPIC=alerts

# Gerätekonfiguration

[mein-laptop]
OnOnline=ntfy, "{device} ist jetzt online"
OnOffline=ntfy, "{device} ist jetzt offline"
OnChange=ntfy, "Zustandsänderung", "{date} {time} - {device} hat den Zustand geändert zu {status}"

[anderes-geraet]
OnChange=ntfy, "Gerät Statuswechsel", "{date} {time} - {device} ist jetzt {status}"
```

## ⚙️ Konfiguration

### Ntfy-Einstellungen

| Variable | Beschreibung | Standard |
|----------|-------------|---------|
| `NTFY_SERVER` | ntfy-Server URL | `ntfy.sh` |
| `NTFY_TOKEN` | Authentifizierungstoken (optional) | - |
| `NTFY_TOPIC` | Standard ntfy-Topic | `tailmon_alerts` |

### Gerätekonfiguration

Für jedes Gerät können Sie folgende Aktionen konfigurieren:

| Aktion | Beschreibung | Platzhalter |
|--------|-------------|-------------|
| `OnOnline` | Wird ausgeführt, wenn Gerät online kommt | `{device}`, `{status}`, `{date}`, `{time}` |
| `OnOffline` | Wird ausgeführt, wenn Gerät offline geht | `{device}`, `{status}`, `{date}`, `{time}` |
| `OnChange` | Wird bei jeder Zustandsänderung ausgeführt | `{device}`, `{status}`, `{date}`, `{time}` |

### Platzhalter

| Platzhalter | Beschreibung | Format |
|-------------|-------------|--------|
| `{device}` | Hostname des Geräts | String |
| `{status}` | `online` oder `offline` | String |
| `{date}` | Aktuelles Datum | `dd.mm.yyyy` (z.B. 06.02.2026) |
| `{time}` | Aktuelle Uhrzeit | `hh:mm:ss` (z.B. 23:45:30) |

### Log-Level

Das Skript protokolliert detaillierte Informationen nach `tailmon.log`:

- `INFO`: Normale Betriebstätigkeit
- `WARNING`: Nicht-kritische Probleme
- `ERROR`: Kritische Fehler, die Funktionalität beeinträchtigen
- `DEBUG`: Detaillierte Informationen für Fehlersuche

## 🎯 Nutzung

### Manuelles Ausführen

```bash
# Status aller Geräte anzeigen
./tailmon.sh --status

# Testbenachrichtigung senden und Konfiguration prüfen
./tailmon.sh --check

# Debug-Modus aktivieren
./tailmon.sh --debug

# Hilfe anzeigen
./tailmon.sh --help

# Version anzeigen
./tailmon.sh --version
```

### Systemd-Service

Der systemd-Timer führt das Skript automatisch aus (Standard: alle 60 Sekunden).

```bash
# Service-Status prüfen
systemctl status tailmon.service tailmon.timer

# Service manuell starten
systemctl start tailmon.service

# Service manuell stoppen
systemctl stop tailmon.service

# Service neu starten
systemctl restart tailmon.service

# Logs anzeigen
journalctl -u tailmon -f

# Timer-Status prüfen
systemctl list-timers | grep tailmon
```

### Dateistruktur

```
tailmon/
├── tailmon.sh              # Hauptskript
├── tailmon.conf            # Konfigurationsdatei (nicht in git)
├── tailmon.conf.sample      # Beispielkonfiguration (in git)
├── tailmon.log             # Logdatei (wird erstellt)
├── tailmon.state           # Zustandsdatei (wird erstellt)
├── install-service.sh       # Installationsskript
├── backup-functions.sh      # Hilfsfunktionen für Backups
├── backup/                 # Backup-Verzeichnis
│   ├── tailmon.sh.YYYYMMDD_HHMMSS
│   └── ...
└── .gitignore               # Git-Konfiguration
```

## 🔧 Troubleshooting

### Service startet nicht

```bash
# Service-Status prüfen
systemctl status tailmon.service

# Logs prüfen
journalctl -xeu tailmon

# Skript manuell testen
bash -x tailmon.sh --debug
```

### Benachrichtigungen werden nicht gesendet

1. Prüfen Sie ntfy-Server-URL und Token
2. Prüfen Sie Netzwerkverbindung
3. Testen Sie ntfy manuell:
   ```bash
   curl -X POST -H "Title: Test" -d "Testnachricht" https://ihr-ntfy-server/topic
   ```
4. Prüfen Sie `tailmon.log` auf Fehler

### Gerätestatus wird nicht erkannt

1. Prüfen Sie Tailscale-Verbindung: `tailscale status --json`
2. Prüfen Sie Gerätenamen in Konfiguration
3. Aktivieren Sie Debug-Modus: `./tailmon.sh --debug`

### Code-Qualität

Das Projekt nutzt ShellCheck zur Qualitätssicherung. Alle Skripte passieren ShellCheck ohne Warnungen oder Fehler (Version >= 0.9.0).

## 🤝 Contributing

Beiträge sind willkommen! Bitte folgen Sie diesen Richtlinien:

1. Forken Sie das Repository
2. Erstellen Sie einen Feature-Branch (`git checkout -b feature/amazing-feature`)
3. Commiten Sie Ihre Änderungen (`git commit -m 'Add amazing feature'`)
4. Pushen Sie zum Branch (`git push origin feature/amazing-feature`)
5. Erstellen Sie einen Pull Request

### Code-Standards

- Alle Bash-Skripte müssen mit ShellCheck validiert werden (keine Warnungen/ Fehler)
- ShellCheck-Version: >= 0.9.0
- Funktionen müssen mit Header-Kommentaren beschrieben werden:
  ```bash
  # Funktion: funktion_name
  # Beschreibung: Kurze Beschreibung
  # Parameter: $1 - parameter1
  #             $2 - parameter2
  # Rückgabe: Exit-Code 0 bei Erfolg, 1 bei Fehler
  funktion_name() {
      # ... Implementierung
  }
  ```

### Coding-Style

- Einrücken: 4 Leerzeichen (keine Tabs)
- Zeilenlänge: Maximal 120 Zeichen (Soft Limit 80 Zeichen)
- Konsistente Benennung: `snake_case` für Variablen, `UPPERCASE` für Konstanten
- `set -o pipefail` für striktes Fehlerverhalten
- Graceful Degradation: Fehler sollten den Service nicht komplett beenden

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe die [LICENSE](LICENSE) Datei für Details.

```text
MIT License

Copyright (c) 2026 TailMon Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🙏 Danks

- [Tailscale](https://tailscale.com/) für die großartige VPN-Software
- [ntfy](https://ntfy.sh/) für den einfachen Benachrichtigungsdienst
- [ShellCheck](https://www.shellcheck.net/) für Bash-Code-Qualitätskontrolle

## 📞 Kontakt

- GitHub Issues: [https://github.com/ihre-organisation/tailmon/issues](https://github.com/ihre-organisation/tailmon/issues)

---

<p align="center">
  <sub>Made mit ❤️ von der TailMon-Community</sub>
</p>
