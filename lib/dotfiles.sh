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

    # 4. Bootstrap Zsh environment (Oh My Zsh, custom plugins, default shell)
    bootstrap_zsh_environment

    ui_success "Dotfiles & Fonts Restoration Completed!"
}

bootstrap_zsh_environment() {
    if [ "${ZSH_BOOTSTRAP_OHMYZSH:-false}" = "true" ]; then
        ui_step "Checking Zsh & Oh My Zsh Environment"
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

    # Check default shell
    local zsh_bin
    zsh_bin=$(command -v zsh 2>/dev/null || true)
    if [ -n "$zsh_bin" ] && [ "$SHELL" != "$zsh_bin" ]; then
        if [ "${DRY_RUN:-false}" = "true" ]; then
            ui_dryrun "Would prompt to set default shell to ${zsh_bin} (current: ${SHELL})"
        else
            if [ "${ASSUME_YES:-false}" = "true" ] || ui_confirm "Your current shell is ${SHELL}. Set default shell to zsh (${zsh_bin})?" true; then
                if chsh -s "$zsh_bin" "$USER" 2>/dev/null; then
                    ui_success "Default shell set to ${zsh_bin}"
                else
                    ui_warn "Could not change default shell automatically. You can run: chsh -s ${zsh_bin}"
                fi
            fi
        fi
    fi
}
