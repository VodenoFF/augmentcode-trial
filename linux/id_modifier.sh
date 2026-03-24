#!/bin/bash

# Colored logging
log_info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# Generate UUID and random hex
generate_uuid() { cat /proc/sys/kernel/random/uuid; }
generate_hex() { head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

# Locate storage.json path (local and Flatpak)
find_storage_path() {
    local paths=(
        "$HOME/.config/Code/User/storage.json"
        "$HOME/.config/Code/User/globalStorage/storage.json"
        "$HOME/.var/app/com.visualstudio.code/config/Code/User/storage.json"
        "$HOME/.var/app/com.visualstudio.code/config/Code/User/globalStorage/storage.json"
    )

    for path in "${paths[@]}"; do
        [[ -f "$path" ]] && echo "$path" && return
    done

    echo ""
}

# Backup file
backup_file() {
    local filepath="$1"
    local backup="${filepath}.backup"
    if [[ ! -f "$backup" ]]; then
        cp "$filepath" "$backup"
        log_success "Backup created: $backup"
    else
        log_warning "Backup already exists: $backup"
    fi
}

# Modify telemetry IDs
modify_telemetry_ids() {
    local file="$1"
    backup_file "$file"

    local new_machine_id
    new_machine_id=$(generate_hex)

    local new_dev_id
    new_dev_id=$(generate_uuid)

    local tmp_file
    tmp_file=$(mktemp)

    jq --arg mid "$new_machine_id" --arg did "$new_dev_id" '
        (.. | objects | select(has("machineId"))).machineId = $mid |
        (.. | objects | select(has("devDeviceId"))).devDeviceId = $did
    ' "$file" > "$tmp_file" && mv "$tmp_file" "$file"

    log_success "Telemetry IDs updated: $file"
    log_info "New machineId: $new_machine_id"
    log_info "New devDeviceId: $new_dev_id"
}

# Main
main() {
    log_info "Starting telemetry ID reset..."

    local path
    path=$(find_storage_path)
    if [[ -z "$path" ]]; then
        log_warning "storage.json not found"
        exit 0
    fi

    if ! command -v jq &> /dev/null; then
        log_error "'jq' is not installed. You can install it using: sudo apt install jq"
        exit 1
    fi

    modify_telemetry_ids "$path"
}

main
