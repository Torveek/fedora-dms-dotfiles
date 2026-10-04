#!/usr/bin/env bash
# lib/services.sh - systemd --user service recording & enablement

backup_services() {
    ui_step "Backing up User Systemd Services"
    mkdir -p "${DATA_DIR}/services"

    local services_file="${DATA_DIR}/services/user-services.txt"

    if ! command -v systemctl >/dev/null 2>&1; then
        ui_warn "systemctl command not found, skipping services backup."
        return 0
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would export custom enabled user services to ${services_file}"
    else
        # Find enabled user services that were explicitly enabled (preset disabled or empty)
        systemctl --user list-unit-files --state=enabled 2>/dev/null | \
            awk '$2=="enabled" && ($3=="disabled" || $3=="-" || $3=="") {print $1}' | \
            grep -v '^$' | sort -u > "$services_file"

        # Ensure dms.service is recorded if currently active or enabled
        if systemctl --user is-enabled dms.service >/dev/null 2>&1; then
            if ! grep -q "^dms.service$" "$services_file"; then
                echo "dms.service" >> "$services_file"
            fi
        fi

        local count
        count=$(wc -l < "$services_file")
        ui_success "Exported ${count} user systemd units to ${services_file}"
    fi
}

restore_services() {
    ui_step "Phase 7: Enabling User Systemd Services"

    local services_file="${DATA_DIR}/services/user-services.txt"

    if [ ! -f "$services_file" ]; then
        ui_warn "Services file ${services_file} not found, skipping."
        return 0
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        ui_warn "systemctl command not found, skipping services restore."
        return 0
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would run: systemctl --user daemon-reload"
        while IFS= read -r unit; do
            [ -z "$unit" ] && continue
            ui_dryrun "Would enable user service: systemctl --user enable ${unit}"
        done < "$services_file"
    else
        systemctl --user daemon-reload || true
        while IFS= read -r unit; do
            [ -z "$unit" ] && continue
            if systemctl --user enable "$unit" 2>/dev/null; then
                ui_success "Enabled user unit: ${unit}"
            else
                ui_warn "Could not enable user unit: ${unit} (unit file may not exist yet)"
            fi
        done < "$services_file"
    fi

    ui_success "Systemd User Services Configuration Completed!"
}
