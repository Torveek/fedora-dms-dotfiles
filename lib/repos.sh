#!/usr/bin/env bash
# lib/repos.sh - Secondary COPRs and RPM repos export & installation

backup_repos() {
    ui_step "Backing up Repository Configurations"
    mkdir -p "${DATA_DIR}/repos"

    local copr_file="${DATA_DIR}/repos/copr.list"
    local rpm_file="${DATA_DIR}/repos/rpm-repos.list"

    # 1. Export secondary COPRs
    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would export secondary COPRs to ${copr_file}"
    else
        > "$copr_file"
        local all_coprs
        all_coprs=$(dnf copr list 2>/dev/null | awk '{print $1}' | sed 's|^copr\.fedorainfracloud\.org/||' | grep -v '^$' | sort -u)
        
        while IFS= read -r copr; do
            [ -z "$copr" ] && continue
            # Exclude DMS priority COPRs
            local is_priority=false
            for p in "${DMS_PRIORITY_COPRS[@]}"; do
                if [ "$copr" = "$p" ]; then
                    is_priority=true
                    break
                fi
            done
            if [ "$is_priority" = "false" ]; then
                echo "$copr" >> "$copr_file"
            fi
        done <<< "$all_coprs"

        local copr_count
        copr_count=$(wc -l < "$copr_file")
        ui_success "Exported ${copr_count} secondary COPRs to ${copr_file}"
    fi

    # 2. Export third-party RPM repository tags
    if [ "${DRY_RUN:-false}" = "true" ]; then
        ui_dryrun "Would export third-party RPM repos to ${rpm_file}"
    else
        > "$rpm_file"
        if ls /etc/yum.repos.d/rpmfusion-free*.repo >/dev/null 2>&1; then
            echo "rpmfusion-free" >> "$rpm_file"
        fi
        if ls /etc/yum.repos.d/rpmfusion-nonfree*.repo >/dev/null 2>&1; then
            echo "rpmfusion-nonfree" >> "$rpm_file"
        fi
        if [ -f /etc/yum.repos.d/vscodium.repo ]; then
            echo "vscodium" >> "$rpm_file"
        fi
        if [ -f /etc/yum.repos.d/nodesource-nodejs.repo ]; then
            echo "nodesource-nodejs" >> "$rpm_file"
        fi
        sort -u -o "$rpm_file" "$rpm_file"
        local rpm_count
        rpm_count=$(wc -l < "$rpm_file")
        ui_success "Exported ${rpm_count} third-party RPM repositories to ${rpm_file}"
    fi
}

restore_repos() {
    ui_step "Phase 2: Enabling Secondary Repositories"

    local copr_file="${DATA_DIR}/repos/copr.list"
    local rpm_file="${DATA_DIR}/repos/rpm-repos.list"

    # Step 2.1: RPM Fusion & Third-Party Repos
    if [ -f "$rpm_file" ]; then
        local fedora_ver
        fedora_ver=$(rpm -E %fedora 2>/dev/null || echo "44")

        while IFS= read -r repo; do
            [ -z "$repo" ] && continue
            case "$repo" in
                rpmfusion-free)
                    if [ "${DRY_RUN:-false}" = "true" ]; then
                        ui_dryrun "Would install RPM Fusion Free: https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm"
                    else
                        if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
                            ui_info "Installing RPM Fusion Free release..."
                            sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" || true
                        else
                            ui_info "RPM Fusion Free is already installed"
                        fi
                    fi
                    ;;
                rpmfusion-nonfree)
                    if [ "${DRY_RUN:-false}" = "true" ]; then
                        ui_dryrun "Would install RPM Fusion Non-Free: https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
                    else
                        if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
                            ui_info "Installing RPM Fusion Non-Free release..."
                            sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" || true
                        else
                            ui_info "RPM Fusion Non-Free is already installed"
                        fi
                    fi
                    ;;
                vscodium)
                    if [ "${DRY_RUN:-false}" = "true" ]; then
                        ui_dryrun "Would import VSCodium GPG key and add /etc/yum.repos.d/vscodium.repo"
                    else
                        if [ ! -f /etc/yum.repos.d/vscodium.repo ]; then
                            ui_info "Adding VSCodium repository..."
                            sudo rpm --import https://repo.vscodium.dev/vscodium.gpg || true
                            sudo tee /etc/yum.repos.d/vscodium.repo >/dev/null << 'EOF'
[vscodium]
name=VSCodium Repo
baseurl=https://repo.vscodium.dev/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://repo.vscodium.dev/vscodium.gpg
metadata_expire=1h
EOF
                            ui_success "Configured VSCodium repository"
                        else
                            ui_info "VSCodium repo is already configured"
                        fi
                    fi
                    ;;
                nodesource-nodejs)
                    if [ "${DRY_RUN:-false}" = "true" ]; then
                        ui_dryrun "Would import NodeSource GPG key and add /etc/yum.repos.d/nodesource-nodejs.repo"
                    else
                        if [ ! -f /etc/yum.repos.d/nodesource-nodejs.repo ]; then
                            ui_info "Adding NodeSource repository..."
                            sudo rpm --import https://rpm.nodesource.com/gpgkey/ns-operations-public.key || true
                            sudo tee /etc/yum.repos.d/nodesource-nodejs.repo >/dev/null << 'EOF'
[nodesource-nodejs]
name=Node.js Packages for Linux RPM based distros - x86_64
baseurl=https://rpm.nodesource.com/pub_26.x/nodistro/nodejs/x86_64
priority=9
enabled=1
gpgcheck=1
gpgkey=https://rpm.nodesource.com/gpgkey/ns-operations-public.key
module_hotfixes=1
EOF
                            ui_success "Configured NodeSource repository"
                        else
                            ui_info "NodeSource repo is already configured"
                        fi
                    fi
                    ;;
            esac
        done < "$rpm_file"
    fi

    # Step 2.2: Secondary COPR Repositories
    if [ -f "$copr_file" ]; then
        while IFS= read -r copr; do
            [ -z "$copr" ] && continue
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would enable secondary COPR: sudo dnf copr enable -y ${copr}"
            else
                if dnf copr list 2>/dev/null | grep -q "$copr"; then
                    ui_info "COPR ${copr} is already enabled"
                else
                    ui_info "Enabling COPR: ${copr}..."
                    if sudo dnf copr enable -y "$copr"; then
                        ui_success "Enabled COPR: ${copr}"
                    else
                        ui_warn "Failed to enable COPR: ${copr}"
                    fi
                fi
            fi
        done < "$copr_file"
    fi

    ui_success "Secondary Repositories Configured!"
}
