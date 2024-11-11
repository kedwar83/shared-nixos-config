#!/bin/bash

set -e

# Configuration
ACTUAL_HOME="$HOME"
REPO_PATH="$ACTUAL_HOME/.dotfiles"
DOTFILES_PATH="$REPO_PATH"
TEMP_FILE=$(mktemp)
FAILURE_LOG="$DOTFILES_PATH/failure_log.txt"
SETUP_FLAG="$ACTUAL_HOME/.system_setup_complete"

echo "Running as user: $USER"
echo "Home directory: $ACTUAL_HOME"
echo "Repo and Dotfiles path: $REPO_PATH"
echo "Temporary file: $TEMP_FILE"
echo "Failure log file: $FAILURE_LOG"

# Exclusion list for rsync
EXCLUSIONS=(
    # System and general security files
    --exclude=".Xauthority"
    --exclude=".xsession-errors"
    --exclude=".bash_history"
    --exclude=".ssh"
    --exclude=".gnupg"
    --exclude=".pki"

    # General cache and temporary files
    --exclude=".cache"
    --exclude=".compose-cache"
    --exclude=".local/share/Trash/"
    --exclude="*/recently-used.xbel"

    # Development and build files
    --exclude=".steam"
    --exclude=".local/share/Steam"
    --exclude=".local/share/Rocket\ League/"

    # Nix-specific
    --exclude=".nix-profile"
    --exclude=".nix-defexpr"
    --exclude=".dotfiles"
    --exclude=".local/state/nix/profiles/home-manager"
    --exclude=".nixos-config"
    --exclude=".system_setup_complete"

    --exclude=".mozilla"

    # Brave Browser data
    --exclude=".config/BraveSoftware/Brave-Browser"

    # Joplin

    # Signal
    --exclude=".config/Signal\ Beta/"

    # Uncatagorized
    --exclude=".config/session/"
    --exclude=".config/Joplin/"
    --exclude=".config/VSCodium/"
    --exclude=".dbus"
    --exclude=".ollama"
    --exclude=".pulse-cookie"
)

# Inclusion list for specific files to sync
INCLUSIONS=(
    ".mozilla/firefox/*/chrome/"
    ".mozilla/firefox/*/user.js"
    ".config/joplin-desktop/settings.json"
    ".config/Joplin/Preferences"
    ".config/Mullvad VPN/gui_settings.json"
    ".config/Mullvad VPN/Preferences"
    ".config/VSCodium/User/"
)


# Initialize/check git repository
init_git_repo() {
    echo "Checking git repository setup..." | tee -a "$TEMP_FILE"

    # Create directory if it doesn't exist
    if [ ! -d "$DOTFILES_PATH" ]; then
        echo "Creating dotfiles directory..." | tee -a "$TEMP_FILE"
        mkdir -p "$DOTFILES_PATH"
    fi

    # Change to the dotfiles directory
    cd "$DOTFILES_PATH"

    # Initialize git if needed
    if [ ! -d "$DOTFILES_PATH/.git" ]; then
        echo "Initializing new git repository..." | tee -a "$TEMP_FILE"
        git init
        # Make sure it's a safe directory right after initialization
        git config --global --add safe.directory "$DOTFILES_PATH"
        # Create main branch and set it as default
        git checkout -b main
    else
        # Make sure it's a safe directory
        git config --global --add safe.directory "$DOTFILES_PATH"
    fi

    # Check for remote only if we have a git repository
    if [ -d "$DOTFILES_PATH/.git" ]; then
        if ! git remote get-url origin >/dev/null 2>&1; then
            echo "Setting up remote repository..." | tee -a "$TEMP_FILE"
            git remote add origin "git@github.com:kedwar83/.dotfiles.git"
        fi

        # Try to fetch only if we have a remote configured
        if git remote -v | grep -q origin; then
            echo "Fetching from remote..." | tee -a "$TEMP_FILE"
            git fetch origin || true
        fi

        # Ensure we're on the main branch
        if ! git rev-parse --verify main >/dev/null 2>&1; then
            echo "Creating main branch..." | tee -a "$TEMP_FILE"
            git checkout -b main
        else
            echo "Checking out main branch..." | tee -a "$TEMP_FILE"
            git checkout main || git checkout -b main
        fi
    fi
}

copy_dotfiles() {
    # Blacklist
    echo "Copying dotfiles to repository..." | tee -a "$TEMP_FILE"
    rsync -av --no-links "${EXCLUSIONS[@]}" \
        --include=".*" \
        --include=".*/**" \
        --exclude="*" \
        "$ACTUAL_HOME/" "$DOTFILES_PATH/"

  # Construct rsync command
rsync -av --no-links \
    $(printf -- "--include='%s' " "${INCLUSIONS[@]}") \
    --exclude='*' \
    "$ACTUAL_HOME/" "$DOTFILES_PATH"

}

# Main script execution
if [ ! -f "$SETUP_FLAG" ]; then
    echo "First-time setup detected..." | tee -a "$TEMP_FILE"
    mkdir -p "$DOTFILES_PATH"
    init_git_repo
else
    copy_dotfiles
fi

# Stow all dotfiles
echo "Stowing dotfiles..." | tee -a "$TEMP_FILE"
if ! stow -vR --adopt . -d "$DOTFILES_PATH" -t "$ACTUAL_HOME" 2> >(tee -a "$FAILURE_LOG" >&2); then
    echo "Some files could not be stowed. Check the failure log for details." | tee -a "$TEMP_FILE"
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" notify-send "Stow Failure" "Some dotfiles could not be stowed. Check the failure log at: $FAILURE_LOG" --icon=dialog-error
fi

# Git operations
cd "$DOTFILES_PATH"

if ! git diff --quiet || ! git ls-files --others --exclude-standard --quiet; then
    echo "Changes detected, committing..." | tee -a "$TEMP_FILE"
    git add .
    git commit -m "Updated dotfiles: $(date '+%Y-%m-%d %H:%M:%S')"
    git push -u origin main
else
    echo "No changes detected, skipping commit."
fi

echo "Log file available at: $TEMP_FILE"
echo "Failure log file available at: $FAILURE_LOG"
