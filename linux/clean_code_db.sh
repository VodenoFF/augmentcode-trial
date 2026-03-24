#!/bin/bash

# Colored logging
log_info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# Check for sqlite3
check_sqlite3() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 not found. Please install SQLite3."
        exit 1
    fi
}

# VS Code data directories (local and flatpak)
get_vscode_locations() {
    local locations=()
    local config_dir_local="$HOME/.config/Code"
    local config_dir_flatpak="$HOME/.var/app/com.visualstudio.code/config/Code"

    # Local install
    if [[ -d "$config_dir_local" ]]; then
        log_info "Local VS Code installation detected."
        [[ -d "$config_dir_local/User" ]] && locations+=("$config_dir_local/User")
        [[ -d "$config_dir_local/workspaceStorage" ]] && locations+=("$config_dir_local/workspaceStorage")
        [[ -d "$config_dir_local/User/globalStorage" ]] && locations+=("$config_dir_local/User/globalStorage")
    fi

    # Flatpak install
    if [[ -d "$config_dir_flatpak" ]]; then
        log_info "Flatpak VS Code installation detected."
        [[ -d "$config_dir_flatpak/User" ]] && locations+=("$config_dir_flatpak/User")
        [[ -d "$config_dir_flatpak/workspaceStorage" ]] && locations+=("$config_dir_flatpak/workspaceStorage")
        [[ -d "$config_dir_flatpak/User/globalStorage" ]] && locations+=("$config_dir_flatpak/User/globalStorage")
    fi

    echo "${locations[@]}"
}

# Backup file
backup_file() {
    local filepath="$1"
    local backup="$filepath.backup"
    if [[ ! -f "$backup" ]]; then
        cp "$filepath" "$backup"
        log_success "Backup created: $backup"
    else
        log_warning "Backup already exists: $backup"
    fi
}

# Clean database
clean_sqlite_db() {
    local db="$1"
    backup_file "$db"
    tables=$(sqlite3 "$db" ".tables")
    for table in $tables; do
        columns=$(sqlite3 "$db" "PRAGMA table_info($table);")
        while IFS= read -r line; do
            col_type=$(echo "$line" | awk -F'|' '{print $3}')
            col_name=$(echo "$line" | awk -F'|' '{print $2}')
            if [[ "$col_type" == *TEXT* ]]; then
                sqlite3 "$db" "DELETE FROM $table WHERE $col_name LIKE '%augment%';"
            fi
        done <<< "$columns"
    done
    log_success "Cleaned: $db"
}

# Main function
main() {
    log_info "Starting VS Code database cleaning..."
    check_sqlite3

    db_count=0
    locations=($(get_vscode_locations))

    if [[ ${#locations[@]} -eq 0 ]]; then
        log_warning "No VS Code data directories found"
        exit 0
    fi

    for dir in "${locations[@]}"; do
        while IFS= read -r db; do
            log_info "Database found: $db"
            clean_sqlite_db "$db"
            ((db_count++))
        done < <(find "$dir" -type f \( -iname "*.db" -o -iname "*.vscdb" \))
    done

    if [[ $db_count -eq 0 ]]; then
        log_warning "No database files found"
    else
        log_success "$db_count databases cleaned"
    fi
}

main
