# Fedora DMS & Niri Dotfiles

A robust, modular, and elegant backup and restore system tailored for **Fedora Linux** (DNF5/DNF), **Dank Material Shell (DMS)**, **Niri Wayland Compositor**, Flatpaks, systemd user services, and desktop dotfiles.

---

## 🌟 Key Features

- **Dank Material Shell Priority Phase**: On restoration, the core desktop environment (DMS, Niri compositor, Quickshell, Matugen, dgop, and associated COPRs) is prioritized and installed first before secondary packages.
- **Modern CLI UI with `gum`**: Styled banners, progress spinners, interactive multi-select menus, and confirmations powered by [Charm's `gum`](https://github.com/charmbracelet/gum) with automatic bootstrapping and graceful ANSI fallback.
- **Full Dry-Run Mode (`--dry-run` / `-n`)**: Fully simulate and preview all operations, commands, and target file paths across both backup and restore without modifying system state.
- **Zero-Data-Loss Safety Backups**: Restoring configurations never overwrites files blindly; timestamped safety backups are automatically generated in `~/.dotfiles_backup/<timestamp>/`.
- **Sensitive Data & Cache Filtering**: Strictly tracks essential configurations while excluding browser session tokens, VPN keys, Electron workspace storage, and temporary archives.
- **Resilient Package Management**: Handles DNF packages in high-speed batches, with graceful fallback to individual installs to prevent failure from removed or renamed packages.

---

## 📂 Repository Structure

```
.
├── backup.sh                       # Backup entrypoint (interactive or flag-driven)
├── restore.sh                      # Restore entrypoint (DMS-first, gum progress)
├── config.env                      # Tracked dotfiles, exclusion patterns, repo lists
├── lib/
│   ├── ui.sh                       # gum UI wrappers, spinners, badges & ANSI fallback
│   ├── dms_phase.sh                # DMS & Niri priority setup (COPRs, core RPMs, configs, service)
│   ├── repos.sh                    # Secondary COPRs and RPM Fusion / third-party repos
│   ├── packages.sh                 # DNF5 package export & batch/resilient install + VSCodium extensions
│   ├── flatpaks.sh                 # Flatpak remotes & applications export & install
│   ├── dotfiles.sh                 # Dotfile backup, restore, safety backups, font cache refresh
│   ├── dconf.sh                    # dconf desktop settings dump & import
│   └── services.sh                 # systemd --user service recording & enablement
├── data/
│   ├── repos/                      # DMS COPRs, secondary COPRs, RPM repo tags
│   ├── packages/                   # DMS core packages & user-installed DNF packages
│   ├── flatpak/                    # Flatpak remotes and application IDs
│   ├── dconf/                      # GNOME/GTK dark mode, fonts, themes dconf dump
│   ├── services/                   # Custom enabled systemd user services
│   └── extensions/                 # VSCodium extension IDs
└── dotfiles/
    ├── config/                     # Mapped to ~/.config/ (DankMaterialShell, niri, alacritty, etc.)
    ├── home/                       # Mapped to ~/ (.bashrc, .gitconfig, etc.)
    └── local_share/                # Mapped to ~/.local/share/ (fonts)
```

---

## 🚀 Quick Start

### 1. Backing Up Current System

Run the backup script to export packages, repos, flatpaks, services, and dotfiles:

```bash
# Preview the backup without modifying anything
./backup.sh --dry-run

# Run full backup (or interactive menu)
./backup.sh

# Run full backup non-interactively
./backup.sh --all -y
```

#### Selective Backups:
```bash
./backup.sh --dms             # Only DankMaterialShell and Niri
./backup.sh --dotfiles        # Only tracked dotfiles and fonts
./backup.sh --packages        # Only DNF packages and extensions
./backup.sh --flatpaks        # Only Flatpak apps and remotes
./backup.sh --dconf           # Only desktop dconf settings
./backup.sh --services        # Only systemd user services
```

---

### 2. Restoring on a Fresh Fedora Installation

Clone your repository onto the target Fedora machine and run:

```bash
git clone https://github.com/<your-username>/fedora-dms-dotfiles.git ~/repos/fedora-dms-dotfiles
cd ~/repos/fedora-dms-dotfiles

# Preview the restoration steps safely
./restore.sh --dry-run

# Execute full restore (DMS prioritized first)
./restore.sh --all
```

#### Selective Restores:
```bash
./restore.sh --dms-only       # Quick setup of DankMaterialShell, Niri & shell service
./restore.sh --dotfiles       # Restore only dotfiles & fonts (with safety backup)
./restore.sh --packages       # Install DNF packages & VSCodium extensions
./restore.sh --flatpaks       # Configure Flatpak remotes & install applications
```

---

## 🛡️ Safety & Data Protection

### Automatic Pre-Restore Backup
Whenever `restore.sh` replaces an existing configuration in `~/.config` or `~/`, it creates a safety copy first:
```
~/.dotfiles_backup/20261004_221500/
├── .config/
│   ├── DankMaterialShell/
│   └── niri/
└── .bashrc
```

### Exclusions & Security
The following files and paths are excluded by default to prevent leaking credentials or committing bloat:
- Browser profiles & session tokens (`~/.mozilla`, `net.imput.helium`, `chromium`)
- VPN & proxy client configs (`AmneziaVPN.ORG`, `Happ`, `Happ.conf`, `clash-verge-rev`)
- VS Code workspace cache (`~/.config/VSCodium/User/workspaceStorage`)
- Private keys and token files (`*.key`, `*.pem`, `id_*`, `*.token`)

---

## 🧩 Dependencies & Requirements

- **OS**: Fedora Linux 40+ (Tested on Fedora 44 with DNF5)
- **UI**: Charm's `gum` (automatically installed during restore if missing; fallback ANSI logger if non-interactive)
- **Tools**: `dnf5` / `dnf`, `rpm`, `rsync`, `flatpak`, `dconf`
