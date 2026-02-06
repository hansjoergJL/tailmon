# TailMon - Projektbeschreibung

## Projektname
TailMon

## Zweck
TailMon überwacht die Änderungen bei den Online- und Offline-Zuständen einzelner Geräte, die alle mit Tailscale verbunden sind. Das System meldet, wenn sich ein Gerät an- oder abgemeldet (oder der Zustand geändert) hat.

## Technische Anforderungen

### Tailscale CLI Integration
- `tailscale status` - Anzeigen des aktuellen Status aller verbundenen Geräte
- `tailscale status --json` - Maschinenlesbare Ausgabe für Automation

Die Ausgabe von `tailscale status` liefert:
- Spalte 1: Tailscale IP-Adresse (100.x.y.z)
- Spalte 2: Gerätename (Machine Name)
- Spalte 3: E-Mail-Adresse des Besitzers
- Spalte 4: Gerät-Betriebssystem
- Spalte 5: Verbindungsstatus
  - `active` - aktuell aktiver Datenverkehr
  - `idle` - kein aktueller Datenverkehr, aber verbunden
  - `-` - noch nie Datenverkehr

### ntfy Integration
- `ntfy publish <topic> "Nachricht"` - Senden von Benachrichtigungen
- Optional: `--title`, `--tags`, `--priority` für erweiterte Metadaten
- HTTP-Alternative: `curl -d "Nachricht" -H "Title: Titel" ntfy.sh/<topic>`

### Konfigurationsdatei (tailmon.conf)
Format:
```
[Gerätename]
OnOnline=ntfy,titel,meldung
OnOffline=ntfy,titel,meldung
OnChange=ntfy,titel,meldung
```

Mögliche Aktionstypen:
- `ntfy` - Sendet Benachrichtigung über ntfy
- `shell` - Führt Shell-Befehl aus

Generelle Settings in tailmon.conf:
- ntfy-Server URL
- Authentifizierungsdetails (falls erforderlich)
- Überwachungsintervall

## Architektur

### Komponenten
1. **tailmon.sh** - Hauptscript für das Monitoring
2. **tailmon.conf** - Konfigurationsdatei
3. **tailmon.log** - Logfile für jede Änderung (1-Zeiler pro Änderung)
4. **tailmon.state** - Zustandsdatei zur Speicherung des letzten Status

### Funktionsweise
1. Regelmäßige Ausführung des Scripts als Service
2. Abfrage des aktuellen Tailscale-Status
3. Vergleich mit gespeichertem Zustand
4. Bei Änderungen:
   - Auslösen der definierten Aktionen
   - Protokollierung in tailmon.log
   - Aktualisierung des Zustands

### Reboot-Sicherheit
- Zustand muss über Reboots hinweg persistent sein
- Service startet automatisch nach Systemstart
- Fehlertolerantes Verhalten bei Netzwerkproblemen

## Erste Phase (MVP)

### Ziel
- Überwachung eines einzelnen Geräts: `kaplanmonitor-lindern`
- Senden einer ntfy-Meldung beim Erreichen des Online-Status

### Dummy-Konfiguration
Alle erforderlichen Informationen werden als Platzhalter in der Konfigurationsdatei angelegt:
- ntfy-Server: `ntfy.sh` (oder eigene Instanz)
- Topic: `tailmon-topic-dummy`
- Titel: `Gerät online`
- Meldung: `Gerät kaplanmonitor-lindern ist jetzt online`

### Logformat
Jede Änderung wird als 1-Zeiler in `tailmon.log` protokolliert:
```
YYYY-MM-DD HH:MM:SS - Gerätename - Status - Aktion
```

Beispiel:
```
2026-02-05 16:30:45 - kaplanmonitor-lindern - Online - ntfy sent
```

## Implementierungsprioritäten

1. **Phase 1**: Grundlegende Infrastruktur
   - tailmon.conf mit Dummy-Werten
   - tailmon.sh mit einfachem Monitoring-Loop
   - Logging in tailmon.log

2. **Phase 2**: Zustandspersistenz
   - tailmon.state für Reboot-Sicherheit
   - Statusvergleich und Änderungserkennung

3. **Phase 3**: ntfy-Integration
   - Senden von Benachrichtigungen
   - Unterstützung von Titeln und Tags

4. **Phase 4**: Erweiterbarkeit
   - Mehrere Geräte
   - Verschiedene Aktionen pro Zustandsänderung
   - Shell-Aktionen

## Service-Integration

Als systemd-Service:
- Autostart beim Systemstart
- Restart bei Fehlern
- Logging an systemd-journald (zusätzlich zu tailmon.log)

## Sicherheit

- Keine Passwörter in Logfiles
- Schutz der Konfigurationsdatei (nur root/ausgewählte User)
- Sichere Handhabung von ntfy-Authentifizierungstokens (falls verwendet)
