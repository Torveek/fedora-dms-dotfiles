#!/usr/bin/env bash
# lib/flatpaks.sh - Flatpak remotes & applications export & install

backup_flatpaks() {
    ui_step "Backing up Flatpak Remotes & Applications"
    mkdir -p "${DATA_DIR}/flatpak"

    local remotes_file="${DATA_DIR}/flatpak/remotes.txt"
    local apps_file="${DATA_DIR}/flatpak/apps.txt"

    if ! command -v flatpak >/dev/null 2>&1; then
        ui_warn "flatpak command not found, skipping Flatpak backup."
        return 0
    fi

    # 1. Export remotes
    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would export Flatpak remotes to ${remotes_file}"
    else
        flatpak remotes --columns=name 2>/dev/null | awk 'NR>1 {print $1}' | grep -v '^$' > "$remotes_file"
        local r_count
        r_count=$(wc -l < "$remotes_file")
        ui_success "Exported ${r_count} Flatpak remotes to ${remotes_file}"
    fi

    # 2. Export applications
    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would export installed Flatpaks to ${apps_file}"
    else
        flatpak list --app --columns=application 2>/dev/null | awk 'NR>1 {print $1}' | grep -v '^$' | sort -u > "$apps_file"
        local a_count
        a_count=$(wc -l < "$apps_file")
        ui_success "Exported ${a_count} Flatpak applications to ${apps_file}"
    fi
}

restore_flatpaks() {
    ui_step "Phase 4: Configuring Flatpaks"

    local remotes_file="${DATA_DIR}/flatpak/remotes.txt"
    local apps_file="${DATA_DIR}/flatpak/apps.txt"

    if ! command -v flatpak >/dev/null 2>&1; then
        ui_warn "flatpak command not found. Installing flatpak via DNF..."
        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would run: sudo dnf install -y flatpak"
        else
            sudo dnf install -y flatpak || {
                ui_error "Failed to install flatpak. Skipping Flatpak restore."
                return 1
            }
        fi
    fi

    # Step 4.1: Ensure remotes exist
    if [ -f "$remotes_file" ]; then
        while IFS= read -r remote; do
            [ -z "$remote" ] && continue
            if [ "$remote" = "flathub" ]; then
                if [ "${DRY_RUN:-false}" = "true" ]; then
                    ui_dryrun "Would add Flathub remote: flatpak remote-add --if-not-exists flathub ${DEFAULT_FLATHUB_URL}"
                else
                    if ! flatpak remotes --columns=name 2>/dev/null | grep -q "^flathub$"; then
                        ui_info "Adding Flathub remote..."
                        flatpak remote-add --if-not-exists flathub "${DEFAULT_FLATHUB_URL}" || true
                        ui_success "Added Flathub remote"
                    else
                        ui_info "Flathub remote is already configured"
                    fi
                fi
            fi
        done < "$remotes_file"
    fi

    # Step 4.2: Install Flatpak apps
    if [ -f "$apps_file" ]; then
        declare -A installed_flatpaks
        while IFS= read -r app; do
            [ -n "$app" ] && installed_flatpaks["$app"]=1
        done < <(flatpak list --app --columns=application 2>/dev/null | awk 'NR>1 {print $1}')

        while IFS= read -r app; do
            [ -z "$app" ] && continue
            if [ -z "${installed_flatpaks[$app]:-}" ]; then
                if [ "${DRY_RUN:-false}" = "true" ]; then
                    ui_dryrun "Would install Flatpak app: flatpak install -y flathub ${app}"
                else
                    ui_info "Installing Flatpak: ${app}..."
                    if flatpak install -y flathub "$app"; then
                        ui_success "Installed Flatpak: ${app}"
                    else
                        ui_warn "Failed to install Flatpak: ${app}"
                    fi
                fi
            else
                ui_info "Flatpak ${app} is already installed"
            fi
        done < <(grep -v '^[[:space:]]*#' "$apps_file")
    fi

    ui_success "Flatpak Configuration Completed!"
}
