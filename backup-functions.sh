#!/bin/bash

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -z "${BUILD_FILE:-}" ]]; then
    BUILD_FILE="${SCRIPT_DIR}/.build"
fi

get_build_number() {
    if [[ ! -f "$BUILD_FILE" ]]; then
        echo "0"
    else
        cat "$BUILD_FILE"
    fi
}

increment_build_number() {
    local current
    current=$(get_build_number)
    local next=$((current + 1))
    echo "$next" > "$BUILD_FILE"
    echo "$next"
}

backup_sh_file() {
    local file_path="$1"
    local file_name
    local timestamp
    local backup_path
    file_name=$(basename "$file_path")
    timestamp=$(date "+%Y%m%d_%H%M%S")
    backup_path="${SCRIPT_DIR}/backup/${file_name}.${timestamp}"
    
    if [[ -f "$file_path" ]]; then
        cp "$file_path" "$backup_path"
        echo "Backup created: $backup_path"
    fi
}

increment_version_in_script() {
    local file_path="$1"
    local new_build="$2"
    
    if [[ -f "$file_path" ]]; then
        sed -i "s/^readonly VERSION=\"1\.0\.[0-9]*\"$/readonly VERSION=\"1.0.${new_build}\"/" "$file_path"
        echo "Version updated to 1.0.${new_build} in $file_path"
    fi
}
