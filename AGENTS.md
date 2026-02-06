# TailMon - Agent-Vorgaben

## Technologie-Stapel

### Primäre Programmiersprache
- **Bash-Shellscript** - Alle Implementierungen erfolgen in reinem Bash
- Keine Python, Perl oder andere Skriptsprachen
- Maximale Portabilität über verschiedene Linux-Distributionen

### Code-Qualität

### Linting
- Alle Bash-Scripts müssen mit ShellCheck validiert werden
- ShellCheck-Version: >= 0.9.0
- Keine Warnungen mit Severity "Error"
- Warnungen mit Severity "Warning" müssen dokumentiert oder behoben werden

### Bash-Versionsanforderungen
- Ziel: Bash >= 4.0
- Nutzung von modernen Bash-Features ist erlaubt (Arrays, Assoziative Arrays)
- POSIX-Shell ist nicht erforderlich

### Code-Stil

### Formatierung
- Einrücken: 4 Leerzeichen (keine Tabs)
- Zeilenlänge: Maximal 120 Zeichen (Soft Limit 80 Zeichen)
- Konsistente Benennung: snake_case für Variablen, UPPERCASE für Konstanten

### Kommentare
- Funktionen müssen mit einem Header-Kommentar beschrieben werden:
  ```bash
  # Funktion: check_tailscale_status
  # Beschreibung: Überprüft den aktuellen Tailscale-Status
  # Parameter: Keine
  # Rückgabe: Exit-Code 0 bei Erfolg, 1 bei Fehler
  check_tailscale_status() {
      # ... Implementierung
  }
  ```

- Komplexe Logik muss mit Inline-Kommentaren erklärt werden
- Keine überflüssigen Kommentare

### Fehlertoleranz

### Exit-Codes
- 0: Erfolg
- 1: Allgemeiner Fehler
- 2: Konfigurationsfehler
- 3: Netzwerkfehler
- 4: Tailscale-CLI-Fehler

### Fehlbehandlung
- Jede Funktion muss Fehlerbehandlung implementieren
- `set -euo pipefail` für striktes Fehlerverhalten
- Graceful Degradation: Fehler sollten den Service nicht komplett beenden

### Logging-Protokoll

### Logfile (tailmon.log)
- Format: `YYYY-MM-DD HH:MM:SS - Gerätename - Status - Aktion`
- Jede Änderung wird als einzelne Zeile protokolliert
- Keine mehrzeiligen Logeinträge
- Zeitstempel: ISO 8601 ohne Zeitzone

### Log-Level
- INFO: Normale Betriebstätigkeit
- WARNING: Nicht-kritische Probleme
- ERROR: Kritische Fehler, die Funktionalität beeinträchtigen
- DEBUG: Detaillierte Informationen für Fehlersuche

### Beispiele:
```
2026-02-05 16:30:45 - kaplanmonitor-lindern - Online - ntfy sent
2026-02-05 16:31:00 - kaplanmonitor-lindern - Offline - ntfy sent
2026-02-05 16:32:15 - [INFO] - Checking Tailscale status...
2026-02-05 16:33:22 - [ERROR] - Failed to connect to Tailscale API
```

### Logging-Funktion
```bash
# Funktion: log_message
# Beschreibung: Protokolliert eine Nachricht mit Zeitstempel
# Parameter: $1 - Log-Level (INFO, WARNING, ERROR, DEBUG)
#             $2 - Nachricht
# Rückgabe: Keine
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp - [$level] - $message" >> "$LOG_FILE"
    
    # Bei ERROR auch nach stderr
    if [[ "$level" == "ERROR" ]]; then
        echo "$timestamp - [$level] - $message" >&2
    fi
}
```

### Konfigurations-Management

### tailmon.conf
- Syntax: INI-ähnliches Format
- Kommentare mit `#` am Zeilenanfang
- Leerzeilen werden ignoriert
- Abschnitte mit `[Gerätename]`

### Validierung
- Konfigurationsdatei muss beim Start validiert werden
- Syntaxfehler müssen frühzeitig erkannt werden
- Fehlende erforderliche Parameter führen zu einem Fehler

### Beispiel-Validierung
```bash
# Funktion: validate_config
# Beschreibung: Validiert die Konfigurationsdatei
# Parameter: Keine
# Rückgabe: Exit-Code 0 bei Erfolg, 1 bei Fehler
validate_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_message "ERROR" "Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Weitere Validierungsschritte...
}
```

### Persistenz

### tailmon.state
- Speichert den letzten bekannten Zustand der Geräte
- Format: Gerätename=Status
- Beispiel:
  ```
  kaplanmonitor-lindern=online
  server-01=offline
  laptop-user=online
  ```

### Atomare Updates
- Schreiben der Zustandsdatei muss atomar erfolgen
- Temporäre Datei schreiben und dann umbenennen
- Fehlertoleranz bei gleichzeitigem Zugriff

### Beispiel-Persistenz
```bash
# Funktion: save_state
# Beschreibung: Speichert den aktuellen Zustand atomar
# Parameter: $1 - Assoziativer Array mit Zuständen
# Rückgabe: Exit-Code 0 bei Erfolg, 1 bei Fehler
save_state() {
    local -n states="$1"
    local temp_file="${STATE_FILE}.tmp"
    
    {
        for device in "${!states[@]}"; do
            echo "$device=${states[$device]}"
        done
    } > "$temp_file"
    
    mv "$temp_file" "$STATE_FILE"
    return $?
}
```

### Testing

### Unit-Tests
- Jede Funktion muss testbar sein
- Mocking von externen Abhängigkeiten (Tailscale CLI, ntfy)
- Tests werden mit Bash Test-Frameworks geschrieben

### Integrationstests
- Tests mit echtem Tailscale-Setup
- Tests mit echtem ntfy-Server (oder Mock)
- Überprüfung der Log-Ausgabe
- Überprüfung der Zustandspersistenz

### Continuous Integration
- ShellCheck läuft bei jedem Commit
- Tests laufen automatisch bei Pull-Requests
- Kein Merge bei fehlgeschlagenen Tests

### Dokumentation

### README
- Installationsschritte
- Konfiguration
- Nutzung
- Fehlersuche

### API-Dokumentation
- Interne Funktionen
- Konfigurationsformat
- Logformat

### Code-Dokumentation
- Inline-Kommentare für komplexe Logik
- Funktionsheader für alle öffentlichen Funktionen

### Sicherheit

### Sensible Daten
- Keine Passwörter oder API-Keys im Code
- Sensible Daten nur in Konfigurationsdatei mit restriktiven Permissions
- Umgebungsvariablen für sensible Daten verwenden, falls möglich

### Permissions
- Konfigurationsdatei: 600 (nur Owner)
- Logfile: 644 (Owner lesen/schreiben, andere lesen)
- State-Datei: 600 (nur Owner)

### Shell-Sicherheit
- `set -euo pipefail` in allen Hauptskripts
- Kein Einsatz von `eval` mit unbekannten Eingaben
- Quoting von Variablen: `"${variable}"`

### Wartung

### Rolling Updates
- Service kann ohne Downtime aktualisiert werden
- Status wird über Updates hinweg beibehalten

### Monitoring
- Service-Health-Checks
- Automatische Restart bei Fehlern
- Logfile-Rotation und Archivierung

### Deploy-Prozess
1. ShellCheck validierung
2. Unit-Tests
3. Integrationstests
4. Deployment
5. Post-Deploy-Validierung

### Qualitätssicherung

**MANDATORISCHE LINTER-NUTZUNG**

Vor jeder Fertigmeldung und nach jeder Scriptanpassung:
1. ShellCheck MUSS ausgeführt werden auf alle .sh-Dateien
2. Bei Fehlern mit Severity "Error" ist professionelle Behebung ERFORDERLICH
3. Bei Warnungen mit Severity "Warning" ist Behebung oder Dokumentation ERFORDERLICH

**Linter-Befehl:**
```bash
shellcheck *.sh
```

**Fehlerbehandlung:**
- Fehler MÜSSEN behoben werden, bevor Fertigmeldung erfolgt
- Keine Ausnahmen ohne ausdrückliche Genehmigung
- Bei kritischen Fehlern: Code-Refactoring erforderlich
- Bei Warnungen: Lösung dokumentieren oder Code anpassen

### Best Practices

### Bash-Funktionen
```bash
# Schleife über Schlüssel eines assoziativen Arrays
for key in "${!array[@]}"; do
    echo "Key: $key, Value: ${array[$key]}"
done

# String-Manipulation
string="example"
uppercase="${string^^}"
lowercase="${string,,}"

# Bedingte Ausführung
[[ -f "$file" ]] && echo "File exists" || echo "File not found"

# Array-Operationen
arr=("one" "two" "three")
echo "${arr[@]}"        # alle Elemente
echo "${arr[1]}"        # zweites Element
echo "${#arr[@]}"       # Anzahl Elemente
```

### Vermeidung
- Backticks für Kommando-Substitution (stattdessen `$()`)
- Hardcodierte Pfade (stattdessen Umgebungsvariablen oder Konfiguration)
- Schleifen mit `find -exec` (stattdessen `while read`-Konstrukt)

### Performance
- Minimierung von externen Aufrufen
- Caching von statischen Daten
- Effiziente String-Manipulation

### Backup-Workflow

**WICHTIG: Vor jeder Änderung an .sh-Dateien ausführen!**

Bevor Sie ein Bash-Skript ändern, erstellen Sie immer ein Backup und erhöhen die Buildnummer.

### Backup-Funktionen
Die Datei `backup-functions.sh` enthält Funktionen für:
- Backup von .sh-Dateien mit Zeitstempel im Verzeichnis `backup/`
- Buildnummer-Tracking in `.build` Datei
- Automatische Versionserhöhung in Skriptdateien

### Backup-Workflow
```bash
# Vor jeder Änderung an .sh Dateien:
source ./backup-functions.sh
backup_sh_file <skriptname>.sh
new_build=$(increment_build_number)
increment_version_in_script <skriptname>.sh "$new_build"
```

### Beispiele
```bash
# Änderung an tailmon.sh:
source ./backup-functions.sh
backup_sh_file tailmon.sh
new_build=$(increment_build_number)
increment_version_in_script tailmon.sh "$new_build"

# Änderung an install-service.sh:
source ./backup-functions.sh
backup_sh_file install-service.sh
new_build=$(increment_build_number)
increment_version_in_script install-service.sh "$new_build"
```

### Versionsformat
- Hauptversion: 1.0.x (x = Buildnummer aus .build Datei)
- Skriptdateien müssen `readonly VERSION="1.0.x"` enthalten
- Backup-Dateien erhalten Zeitstempel: `<name>.YYYYMMDD_HHMMSS`

### Verzeichnisstruktur
```
/
├── backup/
│   ├── tailmon.sh.20260205_165236
│   └── install-service.sh.20260205_165307
├── .build                    # Enthält aktuelle Buildnummer
├── backup-functions.sh      # Backup-Funktionen
├── tailmon.sh              # Aktuell mit Version 1.0.x
└── install-service.sh        # Aktuell mit Version 1.0.x
```

### Beispielimplementierung

### Hauptscript-Struktur
```bash
#!/bin/bash

set -o pipefail

# Konstanten
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${SCRIPT_DIR}/tailmon.conf"
readonly LOG_FILE="${SCRIPT_DIR}/tailmon.log"
readonly STATE_FILE="${SCRIPT_DIR}/tailmon.state"

# Hauptfunktion
main() {
    validate_config
    load_state
    check_devices
    save_state
}

# Programmstart
main "$@"
```

### Systemd-Integration

### Service-Datei
TailMon nutzt systemd-Timer für regelmäßige Ausführung:

```ini
[Unit]
Description=TailMon - Tailscale Device Monitor
After=network.target tailscaled.service
Wants=tailscaled.service

[Service]
Type=oneshot
User=root
WorkingDirectory=/home/data/prod/tailmon
ExecStart=/bin/bash /home/data/prod/tailmon/tailmon.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Timer-Datei
Regelmäßige Ausführung alle 60 Sekunden:

```ini
[Unit]
Description=TailMon Timer
Requires=tailmon.service

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s

[Install]
WantedBy=timers.target
```

### Management-Befehle
```bash
# Service-Status
systemctl status tailmon.service tailmon.timer

# Logs ansehen
journalctl -u tailmon -f

# Timer neu starten
systemctl restart tailmon.timer

# Timer stoppen
systemctl stop tailmon.timer
```

## Projekt-Status

### Aktuelle Version
- tailmon.sh: v1.0.14
- install-service.sh: v1.0.17
- backup-functions.sh: v1.0.13

### Aktuelle Features
✅ Bash-basierte Implementierung
✅ ShellCheck-Validierung (SC2155 dokumentiert)
✅ Systemd-Timer für regelmäßige Ausführung
✅ Platzhalter-Unterstützung ({device}, {status})
✅ Zustandspeicherung
✅ Logging mit Zeitstempeln
✅ MIT-Lizenz
✅ GitHub-Style README

### Bekannte Einschränkungen
- Bash-only Implementierung (keine Python/Perl)
- Benachrichtigungen nur über ntfy
- Keine Web-Interface
- Keine Statistik-Dashboard

### Geplante Features
- [ ] Web-Interface für Konfiguration
- [ ] Unterstützung für mehrere Benachrichtigungsdienste
- [ ] Native Tailscale-Events
- [ ] Statistiken und Dashboard
- [ ] Docker-Container-Unterstützung
