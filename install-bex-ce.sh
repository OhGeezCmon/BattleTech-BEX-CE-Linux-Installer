#!/bin/bash

# BEX:CE (BattleTech Extended 3025-3061) Installation Script for Linux
# Version: 1.0
# Compatible with BEX:CE 1.9.3.7
# 
# Written by: OhGeezCmon and Cursor
#
# This script automates the installation of BEX:CE on Linux systems using Steam Proton
# Requires: Steam and Proton (no Wine support)
# Based on: https://discourse.modsinexile.com/t/battletech-extended-3025-3061-1-9-3-7/426

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/bex-install.log"
BACKUP_DIR="$SCRIPT_DIR/backups"
VERBOSE_MODE=false
DEBUG_MODE=false

# BattleTech Steam App ID (for Proton compat data)
BATTLETECH_APP_ID="637090"

# URLs and file information
BEX_CE_URL="https://discourse.modsinexile.com/uploads/short-url/iPwkIrehw4cIX24DyWbRMQ5pWDO.zip"
MODTEK_URL="https://github.com/BattletechModders/ModTek/releases/download/v0.8.0.0/ModTek_v0.8.0.zip"
CAB_URL="https://discourse.modsinexile.com/uploads/short-url/8X3zwatCvUjgEx3DR6y4yqlUb3i.exe"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to wait for user confirmation
wait_for_confirmation() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo
        print_status "Press Enter to continue..."
        read -r
        echo
    fi
}

# Function to execute commands with verbose logging
execute_command() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        print_status "Executing: $cmd"
        echo "Command: $cmd" >> "$LOG_FILE"
        wait_for_confirmation
    fi
    
    if [[ -n "$description" ]]; then
        log_message "$description"
    fi
    
    # Execute the command and capture output
    if eval "$cmd"; then
        if [[ "$VERBOSE_MODE" == "true" ]]; then
            print_success "Command completed successfully"
        fi
        return 0
    else
        local exit_code=$?
        print_error "Command failed with exit code: $exit_code"
        log_message "Command failed: $cmd (exit code: $exit_code)"
        return $exit_code
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to find Steam Proton installation
find_proton() {
    # Check for Steam Proton
    local steam_paths=(
        "$HOME/.steam/steam/steamapps/common/Proton*"
        "$HOME/.local/share/Steam/steamapps/common/Proton*"
        "/usr/share/steam/steamapps/common/Proton*"
        "/opt/steam/steamapps/common/Proton*"
    )
    
    for path_pattern in "${steam_paths[@]}"; do
        for proton_path in $path_pattern; do
            if [[ -d "$proton_path" && -f "$proton_path/proton" ]]; then
                # Return both the proton path and the compat data path
                local compat_data="$HOME/.steam/steam/steamapps/compatdata"
                if [[ ! -d "$compat_data" ]]; then
                    compat_data="$HOME/.local/share/Steam/steamapps/compatdata"
                fi
                echo "$proton_path/proton|$compat_data"
                return 0
            fi
        done
    done
    
    return 1
}

# Function to detect distribution and package manager
detect_distro() {
    local distro=""
    local package_manager=""
    local is_immutable=false
    
    # Check for immutable OS indicators
    if [[ -f "/etc/os-release" ]]; then
        local os_id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        local os_name=$(grep "^NAME=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        
        # Check for immutable OSes
        if [[ "$os_id" == "bazzite" ]] || [[ "$os_name" == *"Silverblue"* ]] || [[ "$os_name" == *"Kinoite"* ]] || [[ "$os_name" == *"CoreOS"* ]]; then
            is_immutable=true
        fi
    fi
    
    # Detect package manager and distribution
    if command_exists apt; then
        package_manager="apt"
        distro="debian"
    elif command_exists dnf; then
        package_manager="dnf"
        distro="fedora"
    elif command_exists pacman; then
        package_manager="pacman"
        distro="arch"
    elif command_exists zypper; then
        package_manager="zypper"
        distro="opensuse"
    elif command_exists flatpak; then
        package_manager="flatpak"
        distro="flatpak"
    else
        package_manager="unknown"
        distro="unknown"
    fi
    
    echo "$distro|$package_manager|$is_immutable"
}



# Function to check if BattleTech is installed
find_battletech_install() {
    local possible_paths=(
        "$HOME/.steam/steam/steamapps/common/BATTLETECH"
        "$HOME/.local/share/Steam/steamapps/common/BATTLETECH"
        "/usr/share/steam/steamapps/common/BATTLETECH"
        "/opt/steam/steamapps/common/BATTLETECH"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            # Check for Linux executable
            if [[ -f "$path/BattleTech" && -x "$path/BattleTech" ]]; then
                echo "$path"
                return 0
            # Check for Windows executable (for Proton installations)
            elif [[ -f "$path/BattleTech.exe" ]]; then
                echo "$path"
                return 0
            fi
        fi
    done
    
    return 1
}

# Function to prompt for BattleTech installation path
prompt_battletech_path() {
    local path
    while true; do
        read -p "Please enter the full path to your BattleTech installation directory: " path
        if [[ -d "$path" ]]; then
            # Check for Linux executable
            if [[ -f "$path/BattleTech" && -x "$path/BattleTech" ]]; then
                echo "$path"
                return 0
            # Check for Windows executable (for Proton installations)
            elif [[ -f "$path/BattleTech.exe" ]]; then
                echo "$path"
                return 0
            else
                print_error "Invalid BattleTech installation path. Please ensure the directory contains either 'BattleTech' (Linux) or 'BattleTech.exe' (Windows/Proton)"
            fi
        else
            print_error "Directory does not exist. Please enter a valid path."
        fi
    done
}

# Function to download file with progress and resume support
download_file() {
    local url="$1"
    local output="$2"
    local filename=$(basename "$output")
    
    # Check if file already exists - if it does, skip download
    if [[ -f "$output" ]]; then
        print_success "File $filename already exists. Skipping download."
        log_message "Skipped download of $filename - file already exists"
        return 0
    else
        print_status "Downloading $filename..."
    fi
    
    if command_exists wget; then
        local cmd="wget --progress=bar:force -O \"$output\" \"$url\""
        
        if [[ "$VERBOSE_MODE" == "true" ]]; then
            print_status "Executing: $cmd"
            echo "Command: $cmd" >> "$LOG_FILE"
            execute_command "$cmd" "Downloading $filename with wget"
        else
            # Show progress for non-verbose mode
            wget --progress=bar:force -O "$output" "$url" 2>&1 | \
                grep -o '[0-9]*%' | tail -1 | while read percent; do
                echo -ne "\rProgress: $percent"
            done
            echo
        fi
    elif command_exists curl; then
        local cmd="curl -L --progress-bar -o \"$output\" \"$url\""
        
        if [[ "$VERBOSE_MODE" == "true" ]]; then
            print_status "Executing: $cmd"
            echo "Command: $cmd" >> "$LOG_FILE"
            execute_command "$cmd" "Downloading $filename with curl"
        else
            curl -L --progress-bar -o "$output" "$url"
        fi
    else
        print_error "Neither wget nor curl is available. Please install one of them."
        exit 1
    fi
    
    if [[ -f "$output" ]]; then
        print_success "Downloaded $filename"
        log_message "Downloaded $filename from $url"
    else
        print_error "Failed to download $filename"
        exit 1
    fi
}

# Function to extract zip file
extract_zip() {
    local zip_file="$1"
    local extract_dir="$2"
    local filename=$(basename "$zip_file")
    
    print_status "Extracting $filename..."
    
    if command_exists unzip; then
        # Create fresh extraction directory
        local cmd="mkdir -p \"$extract_dir\""
        execute_command "$cmd" "Creating extraction directory"
        
        # Extract the zip file
        local cmd="unzip -o -q \"$zip_file\" -d \"$extract_dir\""
        execute_command "$cmd" "Extracting $filename to $extract_dir"
       
        print_success "Extracted $filename"
        log_message "Extracted $filename to $extract_dir with proper ownership and permissions"
    else
        print_error "unzip is not available. Please install unzip."
        exit 1
    fi
}

# Function to backup existing mods
backup_existing_mods() {
    local battletech_path="$1"
    local mods_dir="$battletech_path/Mods"
    
    if [[ -d "$mods_dir" ]]; then
        # Check if the Mods directory has any files
        local file_count=$(find "$mods_dir" -type f | wc -l)
        
        if [[ "$file_count" -gt 0 ]]; then
            print_warning "Existing Mods directory found with $file_count files."
            echo
            echo "Options:"
            echo "1. Create backup of existing mods (recommended)"
            echo "2. Continue without backup (existing mods will be overwritten)"
            echo
            while true; do
                read -p "Choose an option (1 or 2): " choice
                case $choice in
                    1)
                        print_status "Creating backup of existing mods..."
                        
                        # Rename existing Mods folder in place
                        local backup_name="Mods_backup_$(date +%Y%m%d_%H%M%S)"
                        local backup_path="$battletech_path/$backup_name"
                        local cmd="mv \"$mods_dir\" \"$backup_path\""
                        execute_command "$cmd" "Renaming Mods directory to $backup_name"
                        
                        # Create new empty Mods directory
                        cmd="mkdir -p \"$mods_dir\""
                        execute_command "$cmd" "Creating new empty Mods directory"
                        
                        print_success "Backup created at $backup_path"
                        print_success "New empty Mods directory created"
                        log_message "Backed up existing mods by renaming to $backup_name and created new Mods directory"
                        break
                        ;;
                    2)
                        print_warning "Continuing without backup. Existing mods will be overwritten."
                        log_message "User chose to continue without backup - existing mods will be overwritten"
                        break
                        ;;
                    *)
                        print_error "Invalid choice. Please enter 1 or 2."
                        ;;
                esac
            done
        else
            print_status "Mods directory exists but is empty. No backup needed."
            log_message "Mods directory exists but is empty - no backup needed"
        fi
    else
        print_status "No existing Mods directory found. No backup needed."
        log_message "No existing Mods directory found - no backup needed"
    fi
}

# Function to install ModTek
install_modtek() {
    local battletech_path="$1"
    local temp_dir="$SCRIPT_DIR/temp"
    
    print_status "Installing ModTek..."
    print_warning "ModTek requires running ModTekInjector.exe with Proton"
    wait_for_confirmation
    
    # Find Steam Proton
    local proton_info
    if proton_info=$(find_proton); then
        # Parse Proton path and compat data path
        local proton_cmd=$(echo "$proton_info" | cut -d'|' -f1)
        local compat_data=$(echo "$proton_info" | cut -d'|' -f2)
        print_success "Found Steam Proton: $proton_cmd"
        print_status "Using compat data path: $compat_data"
    else
        print_error "Steam Proton not found. Please install Steam and Proton."
        print_error "This script now only supports Steam Proton."
        exit 1
    fi
    
    # Download ModTek ZIP file
    local modtek_zip="$temp_dir/ModTek.zip"
    download_file "$MODTEK_URL" "$modtek_zip"
    
    # Extract ModTek to Mods directory
    local mods_dir="$battletech_path/Mods"
    local cmd="mkdir -p \"$mods_dir\""
    execute_command "$cmd" "Creating Mods directory"
    
    extract_zip "$modtek_zip" "$mods_dir"
    
    # Find the ModTekInjector.exe file
    local modtek_injector=$(find "$mods_dir" -name "ModTekInjector.exe" -type f | head -1)
    if [[ -n "$modtek_injector" ]]; then
        # Find the ModTek directory
        local modtek_dir=$(dirname "$modtek_injector")
        
        # Create a batch file to wrap the ModTekInjector.exe call
        local batch_file="$modtek_dir/modtek_injector.bat"
        print_status "Creating batch file to wrap ModTekInjector.exe..."
        
        cat > "$batch_file" << EOF
@echo off
echo Starting ModTekInjector.exe...
echo.
echo Current directory: %CD%
echo.
ModTekInjector.exe
echo.
echo ModTekInjector.exe has finished running.
echo Please review the output above to see the results.
echo.
echo Press any key to continue...
pause >nul
echo.
echo Batch file completed.
EOF
        
        # Set proper permissions for the batch file
        local cmd="chmod +x \"$batch_file\""
        execute_command "$cmd" "Setting permissions for batch file"
        
        print_status "Running ModTekInjector.exe via batch file with Proton..."
        print_warning "The injector may open a GUI window. Please follow the installation prompts."
        
        # Convert batch file path to Windows format for Proton
        print_status "Original batch file path: $batch_file"
        local proton_batch_path=$(echo "$batch_file" | sed "s|^$HOME|Z:|" | sed 's|/|\\|g')
        print_status "Windows path for batch file: $proton_batch_path"
        
        # Set up Proton environment variables
        export STEAM_COMPAT_DATA_PATH="$compat_data"
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
        export PROTON_USE_WINED3D=1
        
        # Use BattleTech's app ID for compat data
        local app_compat_path="$compat_data/$BATTLETECH_APP_ID"
        
        # Set the specific compat data path for this app
        export STEAM_COMPAT_DATA_PATH="$app_compat_path"
        
        # Run the batch file with Proton by changing to the ModTek directory first
        print_status "Running batch file with Proton from ModTek directory..."
        local cmd="cd \"$modtek_dir\" && \"$proton_cmd\" run start modtek_injector.bat 2>&1 | tee -a \"$LOG_FILE\""
        print_status "Full command: $cmd"
        execute_command "$cmd" "Running ModTekInjector.exe batch file with Proton start"
        
        print_success "ModTek injection completed"
        log_message "ModTekInjector.exe executed via batch file with $proton_cmd"
    else
        print_error "Could not find ModTekInjector.exe in extracted files"
        exit 1
    fi
}

# Function to install CAB
install_cab() {
    local battletech_path="$1"
    local temp_dir="$SCRIPT_DIR/temp"
    
    print_status "Installing CAB (Community Asset Bundle)..."
    print_warning "CAB is a Windows executable that will be run with Proton"
    wait_for_confirmation
    
    # Find Steam Proton
    local proton_info
    if proton_info=$(find_proton); then
        # Parse Proton path and compat data path
        local proton_cmd=$(echo "$proton_info" | cut -d'|' -f1)
        local compat_data=$(echo "$proton_info" | cut -d'|' -f2)
        print_success "Found Steam Proton: $proton_cmd"
        print_status "Using compat data path: $compat_data"
    else
        print_error "Steam Proton not found. Please install Steam and Proton."
        print_error "This script now only supports Steam Proton."
        exit 1
    fi
    
    # Download CAB installer
    local cab_exe="$temp_dir/CAB_Installer.exe"
    download_file "$CAB_URL" "$cab_exe"
    
    # Run CAB installer with Proton
    print_status "Running CAB installer with Proton..."
    print_warning "The installer may open a GUI window. Please follow the installation prompts."
    
    # Set up Proton environment variables
    export STEAM_COMPAT_DATA_PATH="$compat_data"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
    export PROTON_USE_WINED3D=1
    
    # Use BattleTech's app ID for compat data
    local app_compat_path="$compat_data/$BATTLETECH_APP_ID"
    
    # Set the specific compat data path for this app
    export STEAM_COMPAT_DATA_PATH="$app_compat_path"
    
    local cmd="\"$proton_cmd\" run \"$cab_exe\""
    execute_command "$cmd" "Running CAB installer with Proton"
    
    # Wait for user to complete installation
    print_status "Please complete the CAB installation in the GUI window that opened."
    print_status "Press Enter when the installation is complete..."
    read -r
    
    # Move CAB files from Proton directory to actual BattleTech Mods directory
    local proton_mods_dir="$compat_data/$BATTLETECH_APP_ID/pfx/drive_c/BATTLETECH/mods"
    local battletech_mods_dir="$battletech_path/Mods"
    
    if [[ -d "$proton_mods_dir" ]]; then
        print_status "Copying CAB files from Proton directory to BattleTech Mods directory..."
        local cmd="cp -r \"$proton_mods_dir\"/* \"$battletech_mods_dir/\""
        execute_command "$cmd" "Copying CAB files from Proton directory to Mods directory"
        
        # Set proper ownership and permissions
        cmd="chown -R $(id -u):$(id -g) \"$battletech_mods_dir\""
        execute_command "$cmd" "Setting ownership for CAB files"
        
        print_success "CAB files copied to BattleTech Mods directory"
        log_message "CAB files copied from $proton_mods_dir to $battletech_mods_dir"
    else
        print_warning "CAB files not found in expected Proton directory: $proton_mods_dir"
        log_message "CAB files not found in Proton directory - may need manual installation"
    fi
    
    print_success "CAB installation completed"
    log_message "CAB installer executed with $proton_cmd"
}

# Function to install BEX:CE
install_bex_ce() {
    local battletech_path="$1"
    local temp_dir="$SCRIPT_DIR/temp"
    
    print_status "Installing BEX:CE..."
    wait_for_confirmation
    
    # Download BEX:CE
    local bex_zip="$temp_dir/BEX_CE.zip"
    download_file "$BEX_CE_URL" "$bex_zip"
    
    # Create Mods directory if it doesn't exist
    local mods_dir="$battletech_path/Mods"
    local cmd="mkdir -p \"$mods_dir\""
    execute_command "$cmd" "Creating Mods directory"
    
    # Extract BEX:CE directly into Mods directory
    extract_zip "$bex_zip" "$mods_dir"
    
    # Verify BEX:CE extraction
    if [[ -d "$mods_dir" ]]; then
        # Find the extracted BEX directory
        local bex_dir=$(find "$mods_dir" -maxdepth 1 -type d -name "*Extended*" | head -1)
        if [[ -n "$bex_dir" ]]; then
            print_success "BEX:CE installed successfully"
            log_message "BEX:CE installed to $mods_dir"
        else
            print_error "Could not find BEX:CE files in extracted archive"
            exit 1
        fi
    else
        print_error "BEX:CE extraction failed"
        exit 1
    fi
}


# Function to display installation summary
show_summary() {
    local battletech_path="$1"
    shift
    local cleanup_paths=("$@")
    
    echo
    print_success "BEX:CE installation completed successfully!"
    echo
    echo "Installation Summary:"
    echo "===================="
    echo "BattleTech Path: $battletech_path"
    echo "ModTek: Installed (via Proton)"
    echo "CAB: Installed (via Proton)"
    echo "BEX:CE: Installed"
    echo "Log File: $LOG_FILE"
    echo
    echo "Next Steps:"
    echo "==========="
    echo "1. Launch BattleTech through Steam"
    echo "2. ModTek will automatically load BEX:CE"
    echo "3. Start a new campaign or career (BEX:CE requires new saves)"
    echo "4. Select your preferred difficulty: Normal, Hard, Simulation, or Simulation+"
    echo
    echo "Important Notes:"
    echo "================"
    echo "- ModTek and CAB were installed using Proton to run Windows executables"
    echo "- BEX:CE is NOT compatible with vanilla saves"
    echo "- You must start a new game"
    echo "- The mod adds 1000+ mechs and vehicles"
    echo "- Timeline starts in 3025 and progresses to 3061"
    echo
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC} ${RED}⚠️  IMPORTANT: CLEANUP COMMANDS (OPTIONAL) ⚠️${NC}                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} The following directories can be safely removed to free up disk space:     ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                                          ${YELLOW}║${NC}"
    for path in "${cleanup_paths[@]}"; do
        if [[ -n "$path" && -d "$path" ]]; then
            echo -e "${YELLOW}║${NC} ${GREEN}rm -rf \"$path\"${NC}"
        fi
    done
    echo -e "${YELLOW}║${NC}                                                                          ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} Note: These directories contain temporary files and Proton installation data ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} that are no longer needed after successful installation.                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "For support, visit: https://discourse.modsinexile.com/"
    echo
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -v, --verbose    Enable verbose mode (shows all commands being executed)"
    echo "  -d, --debug      Enable debug mode (pauses after each step for confirmation)"
    echo "  -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0                # Run installation normally"
    echo "  $0 --verbose      # Run with verbose logging"
    echo "  $0 --debug        # Run with step-by-step confirmation"
    echo "  $0 -v -d          # Run with both verbose and debug modes"
    echo
    echo "Modes:"
    echo "  Verbose Mode:     Shows all commands as they are executed"
    echo "  Debug Mode:       Pauses after each major step, waiting for Enter key"
    echo "  Combined:         Use both modes together for maximum visibility"
}

# Main installation function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    echo "=========================================="
    echo "BEX:CE Installation Script for Linux"
    echo "BattleTech Extended 3025-3061 v1.9.3.7"
    echo "=========================================="
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "${YELLOW}Verbose mode enabled - all commands will be displayed${NC}"
    fi
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${YELLOW}Debug mode enabled - pausing after each step${NC}"
    fi
    echo
    
    # Initialize log file
    echo "BEX:CE Installation Log - $(date)" > "$LOG_FILE"
    log_message "Starting BEX:CE installation"
    
    # Check for required tools
    print_status "Checking system requirements..."
    
    if ! command_exists unzip; then
        print_error "unzip is required but not installed. Please install it first."
        echo "On Ubuntu/Debian: sudo apt install unzip"
        echo "On Fedora/RHEL: sudo dnf install unzip"
        exit 1
    fi
    
    if ! command_exists wget && ! command_exists curl; then
        print_error "Either wget or curl is required but neither is installed."
        echo "On Ubuntu/Debian: sudo apt install wget"
        echo "On Fedora/RHEL: sudo dnf install wget"
        exit 1
    fi
    
    print_success "System requirements check passed"
    
    # Find BattleTech installation
    print_status "Looking for BattleTech installation..."
    local battletech_path
    
    if battletech_path=$(find_battletech_install); then
        print_success "Found BattleTech at: $battletech_path"
    else
        print_warning "Could not automatically find BattleTech installation"
        battletech_path=$(prompt_battletech_path)
    fi
    
    log_message "Using BattleTech path: $battletech_path"
    
    # Create temporary directory
    local temp_dir="$SCRIPT_DIR/temp"
    mkdir -p "$temp_dir"
    
    # Backup existing mods
    print_status "Checking for existing mods and creating backup..."
    wait_for_confirmation
    backup_existing_mods "$battletech_path"
    
    # Install components
    install_bex_ce "$battletech_path"  # Skipped for debugging
    install_cab "$battletech_path"     # Skipped for debugging
    install_modtek "$battletech_path"    # Debugging ModTekInjector execution
    
    # Prepare cleanup information
    print_status "Preparing cleanup information..."
    local cleanup_paths=()
    cleanup_paths+=("$temp_dir")
    
    # Check for Proton directory cleanup if CAB was installed
    local proton_info
    if proton_info=$(find_proton); then
        # Parse Proton path and compat data path
        local compat_data=$(echo "$proton_info" | cut -d'|' -f2)
        local proton_mods_dir="$compat_data/$BATTLETECH_APP_ID/pfx/drive_c/BATTLETECH/mods"
        
        if [[ -d "$proton_mods_dir" ]]; then
            cleanup_paths+=("$proton_mods_dir")
        fi
    fi
    
    # Show summary
    show_summary "$battletech_path" "${cleanup_paths[@]}"
    
    log_message "BEX:CE installation completed successfully"
}

# Run main function
main "$@"
