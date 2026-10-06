#!/usr/bin/env bash
# lib/packages.sh - DNF package export & batch/resilient install

backup_packages() {
    ui_step "Backing up User-Installed Packages"
    mkdir -p "${DATA_DIR}/packages"

    local dnf_pkg_file="${DATA_DIR}/packages/dnf-packages.txt"

    # Export DNF userinstalled packages (excluding DMS priority)
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
}

restore_packages() {
    ui_step "Phase 3: Installing User DNF Packages"

    local dnf_pkg_file="${DATA_DIR}/packages/dnf-packages.txt"
    if [ ! -f "$dnf_pkg_file" ]; then
        ui_warn "Package file ${dnf_pkg_file} not found, skipping."
        return 0
    fi

    # Determine DNF options (e.g., --skip-unavailable for DNF5)
    local dnf_opts=("-y")
    if [ "${SKIP_UNAVAILABLE:-true}" = "true" ]; then
        if dnf install --help 2>&1 | grep -q -- '--skip-unavailable'; then
            dnf_opts+=("--skip-unavailable")
        fi
    fi

    # Build cache of currently installed packages
    ui_info "Checking installed packages against ${dnf_pkg_file}..."
    unset installed_pkgs
    declare -A installed_pkgs=()
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
    NOT_INSTALLED_PACKAGES=()

    if [ "$missing_count" -eq 0 ]; then
        ui_success "All user RPM packages are already installed!"
    else
        ui_info "Found ${missing_count} missing packages to install."

        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would install ${missing_count} packages: sudo dnf install ${dnf_opts[*]} ${missing_pkgs[*]}"
        else
            ui_info "Attempting batch installation of ${missing_count} packages..."
            if sudo dnf install "${dnf_opts[@]}" "${missing_pkgs[@]}"; then
                ui_info "Batch installation step completed."
            else
                ui_warn "Batch install encountered issues. Switching to resilient individual package installation..."
                local installed_count=0
                for pkg in "${missing_pkgs[@]}"; do
                    if sudo dnf install "${dnf_opts[@]}" "$pkg" >/dev/null 2>&1; then
                        installed_count=$((installed_count + 1))
                    fi
                done
                ui_info "Resilient installation step completed."
            fi

            # Check which packages are still not installed
            unset current_installed
            declare -A current_installed=()
            while IFS= read -r p; do
                [ -n "$p" ] && current_installed["$p"]=1
            done < <(rpm -qa --qf '%{name}\n' 2>/dev/null)

            local not_installed=()
            for pkg in "${missing_pkgs[@]}"; do
                if [ -z "${current_installed[$pkg]:-}" ]; then
                    not_installed+=("$pkg")
                fi
            done

            NOT_INSTALLED_PACKAGES=("${not_installed[@]}")
            local not_installed_count=${#not_installed[@]}
            local successfully_installed=$((missing_count - not_installed_count))

            if [ "$not_installed_count" -eq 0 ]; then
                ui_success "Successfully installed all ${missing_count} packages!"
            else
                if [ "$successfully_installed" -gt 0 ]; then
                    ui_success "Successfully installed ${successfully_installed} of ${missing_count} packages."
                fi
                ui_warn "${not_installed_count} package(s) could not be installed (unavailable in repos or failed):"
                for pkg in "${not_installed[@]}"; do
                    ui_list_item "$pkg"
                done
            fi
        fi
    fi
}
