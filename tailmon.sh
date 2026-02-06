#!/bin/bash

# shellcheck source=./backup-functions.sh

set -o pipefail

readonly VERSION="1.0.23"
_temp_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_temp_script_dir"
readonly CONFIG_FILE="${SCRIPT_DIR}/tailmon.conf"
readonly LOG_FILE="${SCRIPT_DIR}/tailmon.log"
readonly STATE_FILE="${SCRIPT_DIR}/tailmon.state"
readonly BACKUP_FUNCTIONS="${SCRIPT_DIR}/backup-functions.sh"

DEBUG_MODE=false

source "$BACKUP_FUNCTIONS"

declare -A CONFIG_VALUES
declare -A DEVICE_STATES
declare -A DEVICE_ACTIONS

print_help() {
    echo "TailMon v${VERSION} - Tailscale Device Monitor"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo "  -s, --status   Show device status (condensed)"
    echo "  -c, --check    Send test notification and verify configuration"
    echo "  -d, --debug    Enable debug mode (verbose console output)"
    echo ""
    echo "Configuration: ${CONFIG_FILE}"
    echo "Logfile: ${LOG_FILE}"
    echo "Statefile: ${STATE_FILE}"
}

debug_print() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

log_status_change() {
    local hostname="$1"
    local status="$2"
    local action="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp - $hostname - $status - $action" >> "$LOG_FILE"
    echo "$timestamp - $hostname - $status - $action"
}

send_ntfy() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local server="${CONFIG_VALUES[NTFY_SERVER]}"
    local token="${CONFIG_VALUES[NTFY_TOKEN]}"
    
    local url="https://${server}/${topic}"
    local headers=(-H "Title: ${title}")
    
    if [[ -n "$token" ]]; then
        headers+=(-H "Authorization: Bearer ${token}")
    fi
    
    debug_print "Sending ntfy to $url with title: $title"
    
    if curl -s -X POST "${headers[@]}" -d "$message" "$url" >/dev/null 2>&1; then
        debug_print "ntfy sent successfully to $topic"
        return 0
    else
        debug_print "Failed to send ntfy to $topic"
        return 1
    fi
}

replace_placeholders() {
    local string="$1"
    local device="$2"
    local status="$3"
    
    local current_date
    local current_time
    current_date=$(date '+%d.%m.%Y')
    current_time=$(date '+%H:%M:%S')
    
    local result="${string//\{device\}/${device}}"
    result="${result//\{status\}/${status}}"
    result="${result//\{date\}/${current_date}}"
    result="${result//\{time\}/${current_time}}"
    
    echo "$result"
}

strip_quotes() {
    local string="$1"
    string=$(echo "$string" | xargs)
    string="${string#\"}"
    string="${string%\"}"
    echo "$string"
}

send_test_notification() {
    if ! validate_config; then
        exit 2
    fi
    
    parse_config
    
    local server="${CONFIG_VALUES[NTFY_SERVER]:-}"
    local token="${CONFIG_VALUES[NTFY_TOKEN]:-}"
    local topic="${CONFIG_VALUES[NTFY_TOPIC]:-}"
    
    if [[ -z "$server" || -z "$topic" ]]; then
        echo "ERROR: NTFY_SERVER and NTFY_TOPIC must be configured" >&2
        exit 2
    fi
    
    local title="TailMon Configuration Check"
    local message
    message="TailMon v${VERSION} configuration check successful at $(date '+%Y-%m-%d %H:%M:%S')"
    
    if send_ntfy "$topic" "$title" "$message"; then
        echo "Test notification sent successfully to $topic"
        exit 0
    else
        echo "ERROR: Failed to send test notification" >&2
        exit 1
    fi
}

parse_config() {
    debug_print "Parsing configuration file: $CONFIG_FILE"
    
    local current_section=""
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        if [[ -z "$line" ]]; then
            continue
        fi
        
        if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
            current_section="${BASH_REMATCH[1]}"
            debug_print "Found section: $current_section"
            continue
        fi
        
        if [[ "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            if [[ "$current_section" == "" ]]; then
                CONFIG_VALUES["$key"]="$value"
                debug_print "Config value: $key = $value"
            else
                local action_key="${current_section}.${key}"
                DEVICE_ACTIONS["$action_key"]="$value"
                debug_print "Device action: $action_key = $value"
            fi
        fi
    done < "$CONFIG_FILE"
}

load_state() {
    debug_print "Loading state file: $STATE_FILE"
    
    if [[ ! -f "$STATE_FILE" ]]; then
        debug_print "State file not found, creating new one"
        touch "$STATE_FILE"
        return 0
    fi
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
            local device="${BASH_REMATCH[1]}"
            local status="${BASH_REMATCH[2]}"
            DEVICE_STATES["$device"]="$status"
            debug_print "Loaded state: $device = $status"
        fi
    done < "$STATE_FILE"
}

save_state() {
    debug_print "Saving state to: $STATE_FILE"
    
    local temp_file="${STATE_FILE}.tmp"
    
    {
        for device in "${!DEVICE_STATES[@]}"; do
            echo "$device=${DEVICE_STATES[$device]}"
        done
    } > "$temp_file"
    
    mv "$temp_file" "$STATE_FILE"
}

check_tailscale_status() {
    debug_print "Checking Tailscale status"
    
    local output
    if ! output=$(tailscale status --json 2>&1); then
        echo "ERROR: Failed to get Tailscale status" >&2
        return 1
    fi
    
    debug_print "Tailscale status received: $(echo "$output" | wc -l) lines"
    
    declare -A current_states
    local current_hostname=""
    local current_online=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ \"DNSName\":[[:space:]]*\"([^\"]+)\" ]]; then
            current_hostname="${BASH_REMATCH[1]}"
            current_hostname="${current_hostname%%.*}"
        fi
        if [[ "$line" =~ \"Online\":[[:space:]]*(true|false) ]]; then
            current_online="${BASH_REMATCH[1]}"
            
            local status="offline"
            if [[ "$current_online" == "true" ]]; then
                status="online"
            fi
            
            current_states["$current_hostname"]="$status"
            debug_print "Device status: $current_hostname = $status"
        fi
    done <<< "$output"
    
    for hostname in "${!current_states[@]}"; do
        local new_status="${current_states[$hostname]}"
        local old_status="${DEVICE_STATES[$hostname]:-}"
        
        debug_print "Checking $hostname: old=$old_status, new=$new_status"
        
        if [[ "$new_status" != "$old_status" ]]; then
            debug_print "Status changed for $hostname: $old_status -> $new_status"
            
            local action_performed=""
            local action_key=""
            
            if [[ "$new_status" == "online" ]]; then
                action_key="${hostname}.OnOnline"
            else
                action_key="${hostname}.OnOffline"
            fi
            
            if [[ -n "${DEVICE_ACTIONS[$action_key]:-}" ]]; then
                IFS=',' read -r action_type title message <<< "${DEVICE_ACTIONS[$action_key]}"
                
                action_type=$(strip_quotes "$action_type")
                title=$(strip_quotes "$title")
                message=$(strip_quotes "$message")
                
                local resolved_title
                local resolved_message
                resolved_title=$(replace_placeholders "$title" "$hostname" "$new_status")
                resolved_message=$(replace_placeholders "$message" "$hostname" "$new_status")
                
                if [[ "$action_type" == "ntfy" ]]; then
                    local topic="${CONFIG_VALUES[NTFY_TOPIC]}"
                    if send_ntfy "$topic" "$resolved_title" "$resolved_message"; then
                        action_performed="ntfy sent"
                    else
                        action_performed="ntfy failed"
                    fi
                fi
            elif [[ -n "${DEVICE_ACTIONS[${hostname}.OnChange]:-}" ]]; then
                IFS=',' read -r action_type title message <<< "${DEVICE_ACTIONS[${hostname}.OnChange]}"
                
                action_type=$(strip_quotes "$action_type")
                title=$(strip_quotes "$title")
                message=$(strip_quotes "$message")
                
                local resolved_title
                local resolved_message
                resolved_title=$(replace_placeholders "$title" "$hostname" "$new_status")
                resolved_message=$(replace_placeholders "$message" "$hostname" "$new_status")
                
                if [[ "$action_type" == "ntfy" ]]; then
                    local topic="${CONFIG_VALUES[NTFY_TOPIC]}"
                    if send_ntfy "$topic" "$resolved_title" "$resolved_message"; then
                        action_performed="ntfy sent"
                    else
                        action_performed="ntfy failed"
                    fi
                fi
            fi
            
            DEVICE_STATES["$hostname"]="$new_status"
            log_status_change "$hostname" "$new_status" "$action_performed"
        fi
    done
}

validate_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Config file not found: $CONFIG_FILE" >&2
        return 1
    fi
    
    if ! command -v tailscale >/dev/null 2>&1; then
        echo "ERROR: tailscale command not found" >&2
        return 1
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        echo "ERROR: curl command not found" >&2
        return 1
    fi
    
    return 0
}

print_status() {
    local output
    if ! output=$(tailscale status --json 2>&1); then
        echo "ERROR: Failed to get Tailscale status" >&2
        exit 4
    fi
    
    declare -A current_states
    local display_name=""
    local current_online=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ \"DNSName\":[[:space:]]*\"([^\"]+)\" ]]; then
            display_name="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ \"Online\":[[:space:]]*(true|false) ]]; then
            current_online="${BASH_REMATCH[1]}"
            
            local status="offline"
            if [[ "$current_online" == "true" ]]; then
                status="online"
            fi
            
            local status_symbol="OFF"
            if [[ "$current_online" == "true" ]]; then
                status_symbol="ON "
            fi
            
            local simple_name="${display_name%%.*}"
            printf "%-30s %s\n" "$simple_name" "$status_symbol"
        fi
    done <<< "$output"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                print_help
                exit 0
                ;;
            -v|--version)
                echo "TailMon v${VERSION}"
                exit 0
                ;;
            -s|--status)
                print_status
                exit 0
                ;;
            -c|--check)
                send_test_notification
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                print_help
                exit 1
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    
    if ! validate_config; then
        exit 2
    fi
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp Start"
    
    parse_config
    load_state
    
    if ! check_tailscale_status; then
        exit 4
    fi
    
    save_state
    
    local timestamp_end
    timestamp_end=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp_end End"
}

main "$@"
