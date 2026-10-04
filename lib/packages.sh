#!/usr/bin/env bash
# lib/packages.sh - DNF package export & batch/resilient install + VSCodium extensions

backup_packages() {
    ui_step "Backing up User-Installed Packages & Extensions"
    mkdir -p "${DATA_DIR}/packages" "${DATA_DIR}/extensions"

    local dnf_pkg_file="${DATA_DIR}/packages/dnf-packages.txt"
    local vscodium_file="${DATA_DIR}/extensions/vscodium.txt"

    # 1. Export DNF userinstalled packages (excluding DMS priority)
    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would query userinstalled packages and export to ${dnf_pkg_file}"
    else
        ui_info "Querying user-installed RPM packages via DNF..."
        local all_user_pkgs
        all_user_pkgs=$(dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sort -u)

        > "$dnf_pkg_file"
        while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            # Exclude DMS priority packages
            local is_dms=false
            for dpkg in "${DMS_PRIORITY_PACKAGES[@]}"; do
                if [ "$pkg" = "$dpkg" ]; then
                    is_dms=true
                    break
                fi
            done
            if [ "$is_dms" = "false" ]; then
                echo "$pkg" >> "$dnf_pkg_file"
            fi
        done <<< "$all_user_pkgs"

        local count
        count=$(wc -l < "$dnf_pkg_file")
        ui_success "Exported ${count} user-installed RPM packages to ${dnf_pkg_file}"
    fi

    # 2. Export VSCodium extensions
    if command -v codium >/dev/null 2>&1; then
        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would export VSCodium extensions to ${vscodium_file}"
        else
            codium --list-extensions 2>/dev/null | sort -u > "$vscodium_file"
            local ext_count
            ext_count=$(wc -l < "$vscodium_file")
            ui_success "Exported ${ext_count} VSCodium extensions to ${vscodium_file}"
        fi
    fi
}

restore_packages() {
    ui_step "Phase 3: Installing User DNF Packages"

    local dnf_pkg_file="${DATA_DIR}/packages/dnf-packages.txt"
    if [ ! -f "$dnf_pkg_file" ]; then
        ui_warn "Package file ${dnf_pkg_file} not found, skipping."
        return 0
    fi

    # Build cache of currently installed packages
    ui_info "Checking installed packages against ${dnf_pkg_file}..."
    declare -A installed_pkgs
    while IFS= read -r p; do
        [ -n "$p" ] && installed_pkgs["$p"]=1
    done < <(rpm -qa --qf '%{name}\n' 2>/dev/null)

    local missing_pkgs=()
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        if [ -z "${installed_pkgs[$pkg]:-}" ]; then
            missing_pkgs+=("$pkg")
        fi
    done < <(grep -v '^[[:space:]]*#' "$dnf_pkg_file")

    local missing_count=${#missing_pkgs[@]}
    if [ "$missing_count" -eq 0 ]; then
        ui_success "All user RPM packages are already installed!"
    else
        ui_info "Found ${missing_count} missing packages to install."

        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would install ${missing_count} packages: ${missing_pkgs[*]}"
        else
            ui_info "Attempting batch installation of ${missing_count} packages..."
            if sudo dnf install -y "${missing_pkgs[@]}"; then
                ui_success "Successfully batch-installed ${missing_count} packages!"
            else
                ui_warn "Batch install encountered issues. Switching to resilient individual package installation..."
                local failed_pkgs=()
                local installed_count=0
                for pkg in "${missing_pkgs[@]}"; do
                    if sudo dnf install -y "$pkg" >/dev/null 2>&1; then
                        installed_count=$((installed_count + 1))
                    else
                        failed_pkgs+=("$pkg")
                    fi
                done
                ui_success "Installed ${installed_count} packages."
                if [ ${#failed_pkgs[@]} -gt 0 ]; then
                    ui_warn "The following ${#failed_pkgs[@]} packages could not be installed: ${failed_pkgs[*]}"
                fi
            fi
        fi
    fi

    # Phase 7 helper: Restore VSCodium extensions if codium is installed
    restore_extensions
}

restore_extensions() {
    local vscodium_file="${DATA_DIR}/extensions/vscodium.txt"
    if [ ! -f "$vscodium_file" ]; then
        return 0
    fi

    if ! command -v codium >/dev/null 2>&1; then
        ui_info "VSCodium is not installed; skipping extension installation."
        return 0
    fi

    ui_step "Installing VSCodium Extensions"
    declare -A current_exts
    while IFS= read -r ext; do
        [ -n "$ext" ] && current_exts["${ext,,}"]=1
    done < <(codium --list-extensions 2>/dev/null)

    while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        local ext_lower="${ext,,}"
        if [ -z "${current_exts[$ext_lower]:-}" ]; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would install VSCodium extension: ${ext}"
            else
                ui_info "Installing VSCodium extension: ${ext}..."
                codium --install-extension "$ext" --force >/dev/null 2>&1 || ui_warn "Failed to install extension: ${ext}"
            fi
        else
            ui_info "Extension ${ext} is already installed"
        fi
    done < <(grep -v '^[[:space:]]*#' "$vscodium_file")
    ui_success "VSCodium extensions check completed!"
}
