#!/usr/bin/env bash
# lib/dms_phase.sh - DMS & Niri priority setup (COPRs, core RPMs, configs, service)

backup_dms_phase() {
    ui_step "Backing up DankMaterialShell & Niri (Priority Component)"
    mkdir -p "${DATA_DIR}/repos" "${DATA_DIR}/packages" "${DOTFILES_DIR}/config"

    # 1. Export priority COPRs
    local dms_copr_file="${DATA_DIR}/repos/dms-copr.list"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would export DMS priority COPRs to ${dms_copr_file}"
    else
        > "$dms_copr_file"
        for copr in "${DMS_PRIORITY_COPRS[@]}"; do
            echo "$copr" >> "$dms_copr_file"
        done
        ui_success "Exported ${#DMS_PRIORITY_COPRS[@]} priority COPRs to ${dms_copr_file}"
    fi

    # 2. Export priority packages
    local dms_pkg_file="${DATA_DIR}/packages/dms-packages.txt"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would export DMS priority packages to ${dms_pkg_file}"
    else
        > "$dms_pkg_file"
        for pkg in "${DMS_PRIORITY_PACKAGES[@]}"; do
            if rpm -q "$pkg" >/dev/null 2>&1; then
                echo "$pkg" >> "$dms_pkg_file"
            fi
        done
        local count
        count=$(wc -l < "$dms_pkg_file")
        ui_success "Exported ${count} installed priority packages to ${dms_pkg_file}"
    fi

    # 3. Export dotfiles for DankMaterialShell and niri
    for dir in "${DMS_PRIORITY_CONFIG_DIRS[@]}"; do
        local src="${HOME}/.config/${dir}"
        local dest="${DOTFILES_DIR}/config/${dir}"
        if [ -d "$src" ]; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would copy ${src} -> ${dest}"
            else
                mkdir -p "$(dirname "$dest")"
                rsync -a --delete --exclude='*.log' --exclude='cache/' --exclude='*.sock' "${src}/" "${dest}/"
                ui_success "Synced ~/.config/${dir} -> dotfiles/config/${dir}"
            fi
        else
            ui_warn "~/.config/${dir} not found, skipping."
        fi
    done
}

restore_dms_phase() {
    ui_header "Phase 1: DankMaterialShell & Niri Priority Setup" "Compositor, shell, widgets & keybindings"

    local dms_copr_file="${DATA_DIR}/repos/dms-copr.list"
    local dms_pkg_file="${DATA_DIR}/packages/dms-packages.txt"

    # Step 1: Enable Priority COPRs
    ui_step "Phase 1.1: Enabling Priority COPR Repositories"
    local coprs_to_enable=()
    if [ -f "$dms_copr_file" ]; then
        mapfile -t coprs_to_enable < <(grep -v '^[[:space:]]*#' "$dms_copr_file" | grep -v '^[[:space:]]*$')
    else
        coprs_to_enable=("${DMS_PRIORITY_COPRS[@]}")
    fi

    for copr in "${coprs_to_enable[@]}"; do
        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would check and enable COPR: sudo dnf copr enable -y ${copr}"
        else
            if dnf copr list 2>/dev/null | grep -q "$copr"; then
                ui_info "COPR ${copr} is already enabled"
            else
                ui_info "Enabling COPR: ${copr}..."
                if sudo dnf copr enable -y "$copr"; then
                    ui_success "Enabled COPR: ${copr}"
                else
                    ui_error "Failed to enable COPR: ${copr}"
                fi
            fi
        fi
    done

    # Step 2: Install Priority DMS Packages
    ui_step "Phase 1.2: Installing DMS Core Packages"
    local pkgs_to_install=()
    if [ -f "$dms_pkg_file" ]; then
        mapfile -t pkgs_to_install < <(grep -v '^[[:space:]]*#' "$dms_pkg_file" | grep -v '^[[:space:]]*$')
    else
        pkgs_to_install=("${DMS_PRIORITY_PACKAGES[@]}")
    fi

    local missing_pkgs=()
    for pkg in "${pkgs_to_install[@]}"; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
            ui_info "Package ${pkg} is already installed"
        else
            missing_pkgs+=("$pkg")
        fi
    done

    NOT_INSTALLED_DMS_PACKAGES=()
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        local dnf_opts=("-y")
        if [ "${SKIP_UNAVAILABLE:-true}" = "true" ]; then
            if dnf install --help 2>&1 | grep -q -- '--skip-unavailable'; then
                dnf_opts+=("--skip-unavailable")
            fi
        fi

        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would install packages: sudo dnf install ${dnf_opts[*]} ${missing_pkgs[*]}"
        else
            ui_info "Installing missing DMS packages: ${missing_pkgs[*]}"
            ui_spin "Installing DMS core packages" sudo dnf install "${dnf_opts[@]}" "${missing_pkgs[@]}"
            
            local dms_failed=()
            for pkg in "${missing_pkgs[@]}"; do
                if ! rpm -q "$pkg" >/dev/null 2>&1; then
                    dms_failed+=("$pkg")
                fi
            done
            if [ ${#dms_failed[@]} -gt 0 ]; then
                ui_warn "The following DMS core package(s) could not be installed:"
                for pkg in "${dms_failed[@]}"; do
                    ui_list_item "$pkg"
                done
                NOT_INSTALLED_DMS_PACKAGES=("${dms_failed[@]}")
            else
                ui_success "Installed DMS core packages"
            fi
        fi
    else
        ui_success "All DMS core packages are already installed"
    fi

    # Step 3: Deploy DMS & Niri Dotfiles (with safety backups)
    ui_step "Phase 1.3: Deploying DMS & Niri Configurations"
    local backup_timestamp
    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local safety_backup_dir="${RESTORE_BACKUP_BASE}/${backup_timestamp}"

    for dir in "${DMS_PRIORITY_CONFIG_DIRS[@]}"; do
        local src="${DOTFILES_DIR}/config/${dir}"
        local dest="${HOME}/.config/${dir}"

        if [ -d "$src" ]; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                if [ -e "$dest" ]; then
                    ui_dryrun "Would backup existing ${dest} -> ${safety_backup_dir}/${dir}"
                fi
                ui_dryrun "Would deploy ${src} -> ${dest}"
            else
                if [ -e "$dest" ]; then
                    mkdir -p "$safety_backup_dir"
                    cp -a "$dest" "${safety_backup_dir}/${dir}"
                    ui_info "Safety backup: ${dest} -> ${safety_backup_dir}/${dir}"
                fi
                mkdir -p "$(dirname "$dest")"
                rsync -a "${src}/" "${dest}/"
                ui_success "Restored ~/.config/${dir}"
            fi
        else
            ui_warn "Source dotfile directory ${src} not found in repo"
        fi
    done

    # Step 4: Enable & Reload dms.service
    ui_step "Phase 1.4: Enabling dms.service"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would run: systemctl --user daemon-reload"
        ui_dryrun "Would run: systemctl --user enable dms.service"
    else
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user daemon-reload || true
            if systemctl --user enable dms.service 2>/dev/null; then
                ui_success "Enabled systemd user service: dms.service"
            else
                ui_warn "dms.service unit not yet available or failed to enable"
            fi
        fi
    fi

    ui_success "DMS & Niri Priority Phase Complete!"
}
