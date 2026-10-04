#!/usr/bin/env bash
# lib/dconf.sh - dconf desktop settings dump & import

backup_dconf() {
    ui_step "Backing up Desktop dconf Settings"
    mkdir -p "${DATA_DIR}/dconf"

    local dconf_file="${DATA_DIR}/dconf/settings.dconf"

    if ! command -v dconf >/dev/null 2>&1; then
        ui_warn "dconf command not found, skipping dconf backup."
        return 0
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would export dconf settings to ${dconf_file}"
    else
        dconf dump / > "$dconf_file"
        local lines
        lines=$(wc -l < "$dconf_file")
        ui_success "Exported dconf settings (${lines} lines) to ${dconf_file}"
    fi
}

restore_dconf() {
    ui_step "Phase 6: Restoring Desktop dconf Settings"

    local dconf_file="${DATA_DIR}/dconf/settings.dconf"

    if [ ! -f "$dconf_file" ]; then
        ui_warn "dconf file ${dconf_file} not found, skipping."
        return 0
    fi

    if ! command -v dconf >/dev/null 2>&1; then
        ui_warn "dconf command not found, skipping dconf restore."
        return 0
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would load dconf settings: dconf load / < ${dconf_file}"
    else
        if dconf load / < "$dconf_file"; then
            ui_success "Restored desktop dconf settings"
        else
            ui_warn "Failed to restore some dconf settings"
        fi
    fi
}
