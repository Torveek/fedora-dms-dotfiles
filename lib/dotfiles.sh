#!/usr/bin/env bash
# lib/dotfiles.sh - Dotfile backup, restore, timestamped backup creation

backup_dotfiles() {
    ui_step "Backing up User Configurations & Dotfiles"

    mkdir -p "${DOTFILES_DIR}/config" "${DOTFILES_DIR}/home" "${DOTFILES_DIR}/local_share"

    # 1. Tracked ~/.config directories
    for dir in "${TRACKED_CONFIG_DIRS[@]}"; do
        local src="${HOME}/.config/${dir}"
        local dest="${DOTFILES_DIR}/config/${dir}"
        if [ -d "$src" ]; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would sync config directory: ${src} -> ${dest}"
            else
                mkdir -p "$dest"
                rsync -a --delete \
                    --exclude='assets' \
                    --exclude='*.tar.gz' \
                    --exclude='*.cache' \
                    --exclude='*.bkp' \
                    --exclude='*.bak' \
                    --exclude='*.log' \
                    --exclude='*.tmp' \
                    --exclude='cache/' \
                    --exclude='Cache/' \
                    "${src}/" "${dest}/"
                ui_success "Backed up ~/.config/${dir}"
            fi
        else
            ui_warn "~/.config/${dir} not found, skipping."
        fi
    done

    # 2. Tracked individual files in ~/.config
    for file in "${TRACKED_CONFIG_FILES[@]}"; do
        local src="${HOME}/.config/${file}"
        local dest="${DOTFILES_DIR}/config/${file}"
        if [ -f "$src" ] || [ -L "$src" ]; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would copy config file: ${src} -> ${dest}"
            else
                mkdir -p "$(dirname "$dest")"
                cp -L "$src" "$dest"
                ui_success "Backed up ~/.config/${file}"
            fi
        fi
    done

    # 3. Tracked home dotfiles (~/.*)
    for file in "${TRACKED_HOME_FILES[@]}"; do
        # Explicit guard: never back up bash files or history files
        if [[ "$file" =~ ^\.bash ]] || [[ "$file" =~ (history|histfile) ]]; then
            continue
        fi
        local src="${HOME}/${file}"
        local dest="${DOTFILES_DIR}/home/${file}"
        if [ -f "$src" ] || [ -L "$src" ]; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would copy home file: ${src} -> ${dest}"
            else
                mkdir -p "$(dirname "$dest")"
                cp -L "$src" "$dest"
                ui_success "Backed up ~/${file}"
            fi
        fi
    done

    # 4. Fonts in ~/.local/share/fonts
    local fonts_src="${HOME}/.local/share/${TRACKED_FONTS_DIR}"
    local fonts_dest="${DOTFILES_DIR}/local_share/${TRACKED_FONTS_DIR}"
    if [ -d "$fonts_src" ]; then
        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would sync fonts: ${fonts_src} -> ${fonts_dest}"
        else
            mkdir -p "$fonts_dest"
            rsync -a --delete "${fonts_src}/" "${fonts_dest}/"
            local font_count
            font_count=$(find "$fonts_dest" -type f \( -name "*.ttf" -o -name "*.otf" \) 2>/dev/null | wc -l)
            ui_success "Backed up ${font_count} font files to dotfiles/local_share/fonts"
        fi
    fi

    ui_success "Dotfiles backup completed!"
}

restore_dotfiles() {
    ui_step "Phase 5: Restoring Dotfiles & Fonts"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local safety_dir="${RESTORE_BACKUP_BASE}/${timestamp}"

    # Helper function for safety backup
    safe_backup_target() {
        local target="$1"
        local rel_path="$2"
        if [ -e "$target" ] || [ -L "$target" ]; then
            local backup_target="${safety_dir}/${rel_path}"
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Safety backup: would save ${target} -> ${backup_target}"
            else
                mkdir -p "$(dirname "$backup_target")"
                cp -a "$target" "$backup_target"
                ui_info "Created safety backup: ${rel_path}"
            fi
        fi
    }

    # 1. Restore ~/.config entries
    if [ -d "${DOTFILES_DIR}/config" ]; then
        for item in "${DOTFILES_DIR}/config"/*; do
            [ ! -e "$item" ] && continue
            local name
            name=$(basename "$item")

            # Do not restore VSCodium settings
            [ "$name" = "VSCodium" ] && continue

            # Skip DMS priority dirs if they were already handled in Phase 1
            if [ "${SKIP_DMS_IN_DOTFILES:-false}" = "true" ]; then
                local is_dms_prio=false
                for pdir in "${DMS_PRIORITY_CONFIG_DIRS[@]}"; do
                    if [ "$name" = "$pdir" ]; then
                        is_dms_prio=true
                        break
                    fi
                done
                [ "$is_dms_prio" = "true" ] && continue
            fi

            local dest="${HOME}/.config/${name}"
            safe_backup_target "$dest" ".config/${name}"

            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would restore dotfile: ${item} -> ${dest}"
            else
                if [ -d "$item" ]; then
                    mkdir -p "$dest"
                    rsync -a "${item}/" "${dest}/"
                else
                    mkdir -p "$(dirname "$dest")"
                    rm -f "$dest"
                    cp -a "$item" "$dest"
                fi
                ui_success "Restored ~/.config/${name}"
            fi
        done
    fi

    # 2. Restore Home files (~/.*)
    if [ -d "${DOTFILES_DIR}/home" ]; then
        for item in "${DOTFILES_DIR}/home"/.*; do
            [ ! -f "$item" ] && continue
            local name
            name=$(basename "$item")
            [ "$name" = "." ] || [ "$name" = ".." ] && continue

            # Explicit guard: never restore bash configurations or history files
            if [[ "$name" =~ ^\.bash ]] || [[ "$name" =~ (history|histfile) ]]; then
                continue
            fi

            local dest="${HOME}/${name}"
            safe_backup_target "$dest" "${name}"

            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would restore home file: ${item} -> ${dest}"
            else
                rm -f "$dest"
                cp -a "$item" "$dest"
                ui_success "Restored ~/${name}"
            fi
        done
    fi

    # 3. Restore Fonts
    local fonts_src="${DOTFILES_DIR}/local_share/fonts"
    local fonts_dest="${HOME}/.local/share/fonts"
    if [ -d "$fonts_src" ]; then
        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would restore fonts: ${fonts_src} -> ${fonts_dest}"
            ui_dryrun "Would update font cache: fc-cache -f ${fonts_dest}"
        else
            mkdir -p "$fonts_dest"
            rsync -a "${fonts_src}/" "${fonts_dest}/"
            ui_success "Restored fonts to ~/.local/share/fonts"
            if command -v fc-cache >/dev/null 2>&1; then
                ui_info "Updating font cache..."
                fc-cache -f "$fonts_dest" >/dev/null 2>&1 || true
                ui_success "Font cache refreshed"
            fi
        fi
    fi

    # 4. Restore DMS runtime state if not skipped by Phase 1
    if [ -d "${DOTFILES_DIR}/local_state" ] && [ "${SKIP_DMS_IN_DOTFILES:-false}" != "true" ]; then
        for sdir in "${DMS_PRIORITY_STATE_DIRS[@]}"; do
            local ssrc="${DOTFILES_DIR}/local_state/${sdir}"
            local sdest="${HOME}/.local/state/${sdir}"
            if [ -d "$ssrc" ]; then
                safe_backup_target "$sdest" ".local/state/${sdir}"
                if [ "${DRY_RUN:-false}" = "true" ]; then
                    ui_dryrun "Would restore state directory: ${ssrc} -> ${sdest}"
                else
                    mkdir -p "$sdest"
                    rsync -a "${ssrc}/" "${sdest}/"
                    ui_success "Restored ~/.local/state/${sdir} (DMS session & locale settings)"
                fi
            fi
        done
    fi

    # 5. Bootstrap Zsh environment (Oh My Zsh, custom plugins, default shell)
    bootstrap_zsh_environment

    ui_success "Dotfiles & Fonts Restoration Completed!"
}

bootstrap_zsh_environment() {
    ui_step "Configuring Shell Environment (Oh My Zsh, Starship, Zoxide)"

    # Ensure user bin directory is in PATH for current execution
    export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"

    if [ "${ZSH_BOOTSTRAP_OHMYZSH:-false}" = "true" ]; then
        if [ ! -d "${HOME}/.oh-my-zsh" ]; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would install Oh My Zsh into ${HOME}/.oh-my-zsh"
            else
                ui_info "Oh My Zsh not detected. Installing Oh My Zsh..."
                if command -v git >/dev/null 2>&1; then
                    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh"
                    ui_success "Oh My Zsh installed to ~/.oh-my-zsh"
                else
                    ui_warn "git is not installed; skipping Oh My Zsh clone."
                fi
            fi
        else
            ui_info "Oh My Zsh is already installed at ~/.oh-my-zsh"
        fi

        # Install custom plugins
        for entry in "${ZSH_CUSTOM_PLUGINS[@]}"; do
            local pname="${entry%%:*}"
            local purl="${entry#*:}"
            local pdir="${HOME}/.oh-my-zsh/custom/plugins/${pname}"
            if [ ! -d "$pdir" ]; then
                if [ "${DRY_RUN:-false}" = "true" ]; then
                    ui_dryrun "Would clone custom Zsh plugin ${pname} from ${purl}"
                else
                    if command -v git >/dev/null 2>&1; then
                        ui_info "Installing custom Zsh plugin: ${pname}..."
                        mkdir -p "$(dirname "$pdir")"
                        git clone --depth=1 "$purl" "$pdir"
                        ui_success "Installed Zsh plugin: ${pname}"
                    fi
                fi
            else
                ui_info "Custom Zsh plugin ${pname} is already present"
            fi
        done
    fi

    # Bootstrap zoxide (required by oh-my-zsh zoxide plugin and .zshrc)
    if [ "${BOOTSTRAP_ZOXIDE:-true}" = "true" ]; then
        if ! command -v zoxide >/dev/null 2>&1; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would install zoxide into ${HOME}/.local/bin"
            else
                ui_info "zoxide not detected. Installing zoxide..."
                local zoxide_installed=false
                if command -v curl >/dev/null 2>&1; then
                    mkdir -p "${HOME}/.local/bin"
                    if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- --bin-dir "${HOME}/.local/bin" >/dev/null 2>&1; then
                        zoxide_installed=true
                    fi
                fi
                if [ "$zoxide_installed" = "true" ] || [ -x "${HOME}/.local/bin/zoxide" ]; then
                    ui_success "zoxide installed successfully"
                else
                    ui_warn "Could not install zoxide automatically. Please install it manually: sudo dnf install zoxide"
                fi
            fi
        else
            ui_info "zoxide is already installed ($(command -v zoxide))"
        fi
    fi

    # Bootstrap Starship prompt (required for decorated shell prompt)
    if [ "${BOOTSTRAP_STARSHIP:-true}" = "true" ]; then
        if ! command -v starship >/dev/null 2>&1; then
            if [ "${DRY_RUN:-false}" = "true" ]; then
                ui_dryrun "Would install Starship prompt binary via official installer"
            else
                ui_info "Starship not detected. Installing Starship prompt..."
                local starship_installed=false
                if command -v curl >/dev/null 2>&1; then
                    local target_bin_dir="${HOME}/.local/bin"
                    if [ -w "/usr/local/bin" ]; then
                        target_bin_dir="/usr/local/bin"
                    fi
                    mkdir -p "$target_bin_dir"
                    if curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$target_bin_dir" >/dev/null 2>&1; then
                        starship_installed=true
                    fi
                fi
                if [ "$starship_installed" = "true" ] || command -v starship >/dev/null 2>&1 || [ -x "${HOME}/.local/bin/starship" ]; then
                    ui_success "Starship prompt installed successfully"
                else
                    ui_warn "Could not install Starship automatically. Please install it manually: curl -sS https://starship.rs/install.sh | sh"
                fi
            fi
        else
            ui_info "Starship prompt is already installed ($(command -v starship))"
        fi
    fi

    # Check default login shell via /etc/passwd
    local zsh_bin
    zsh_bin=$(command -v zsh 2>/dev/null || true)
    local current_login_shell
    current_login_shell=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
    [ -z "$current_login_shell" ] && current_login_shell="${SHELL:-/bin/bash}"

    if [ -n "$zsh_bin" ] && [[ ! "$current_login_shell" =~ /zsh$ ]]; then
        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would prompt to set default shell to ${zsh_bin} (current login shell: ${current_login_shell})"
        else
            if [ "${ASSUME_YES:-false}" = "true" ] || ui_confirm "Your current login shell is ${current_login_shell}. Set default shell to zsh (${zsh_bin})?" true; then
                local changed=false
                if command -v sudo >/dev/null 2>&1; then
                    if sudo usermod -s "$zsh_bin" "$USER" >/dev/null 2>&1; then
                        changed=true
                    fi
                fi
                if [ "$changed" = "false" ]; then
                    if chsh -s "$zsh_bin" >/dev/null 2>&1 || chsh -s "$zsh_bin" "$USER" >/dev/null 2>&1; then
                        changed=true
                    fi
                fi

                if [ "$changed" = "true" ]; then
                    ui_success "Default login shell set to ${zsh_bin}"
                else
                    ui_info "Note: To change default shell manually, run: chsh -s ${zsh_bin}"
                fi
            fi
        fi
    else
        ui_info "Default login shell is already zsh (${current_login_shell})"
    fi
}
