#!/bin/bash

set -o pipefail

_temp_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_temp_script_dir"
readonly SCRIPT_NAME="tailmon.sh"
readonly SERVICE_NAME="tailmon"
readonly SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

check_prerequisites() {
    local missing=()
    
    if ! command -v tailscale >/dev/null 2>&1; then
        missing+=("tailscale")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing+=("curl")
    fi
    
    if ! command -v systemctl >/dev/null 2>&1; then
        missing+=("systemctl")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

check_files() {
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo "tailmon.sh not found at: $SCRIPT_PATH"
        exit 1
    fi
    
    if [[ ! -x "$SCRIPT_PATH" ]]; then
        chmod +x "$SCRIPT_PATH"
        echo "Made tailmon.sh executable"
    fi
    
    if [[ ! -f "${SCRIPT_DIR}/tailmon.conf" ]]; then
        echo "tailmon.conf not found"
        exit 1
    fi
}

create_systemd_service() {
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    local timer_file="/etc/systemd/system/${SERVICE_NAME}.timer"
    
    cat > "$service_file" << EOF
[Unit]
Description=TailMon - Tailscale Device Monitor
After=network.target tailscaled.service
Wants=tailscaled.service

[Service]
Type=oneshot
User=root
WorkingDirectory=${SCRIPT_DIR}
ExecStart=/bin/bash ${SCRIPT_PATH}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    cat > "$timer_file" << EOF
[Unit]
Description=TailMon Timer
Requires=tailmon.service

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s

[Install]
WantedBy=timers.target
EOF
    
    echo "Created systemd service file: $service_file"
    echo "Created systemd timer file: $timer_file"
}

enable_service() {
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}.timer"
    systemctl start "${SERVICE_NAME}.timer"
    
    echo ""
    echo "TailMon service and timer installed and started!"
    echo ""
    echo "Useful commands:"
    echo "  systemctl status ${SERVICE_NAME}"
    echo "  systemctl restart ${SERVICE_NAME}.timer"
    echo "  systemctl stop ${SERVICE_NAME}.timer"
    echo "  journalctl -u ${SERVICE_NAME} -f"
}

main() {
    check_root
    check_prerequisites
    check_files
    create_systemd_service
    enable_service
}

main "$@"
