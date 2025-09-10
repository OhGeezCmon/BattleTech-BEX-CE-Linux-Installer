#!/bin/bash

# BEX:CE (BattleTech Extended 3025-3061) Installation Script for Linux
# Version: 1.0
# Compatible with BEX:CE 1.9.3.7
# 
# Written by: OhGeezCmon and Cursor
#
# This script automates the installation of BEX:CE on Linux systems using Steam Proton
# Also optionally installs the Extended BiggerDrops Patch mod
# Requires: Steam and Proton (no plain Wine support)
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
INSTALL_BIGGERDROPS=false

# BattleTech Steam App ID (for Proton compat data)
BATTLETECH_APP_ID="637090"

# URLs and file information
BEX_CE_URL="https://discourse.modsinexile.com/uploads/short-url/iPwkIrehw4cIX24DyWbRMQ5pWDO.zip"
MODTEK_URL="https://github.com/BattletechModders/ModTek/releases/download/v0.8.0.0/ModTek_v0.8.0.zip"
CAB_URL="https://discourse.modsinexile.com/uploads/short-url/8X3zwatCvUjgEx3DR6y4yqlUb3i.exe"
BIGGERDROPS_URL="https://discourse.modsinexile.com/uploads/short-url/A3IKwCNwRIuv26jMXmQRxDLIVrs.zip"
INSTALL_BIGGERDROPS=false

# Step tracking
CURRENT_STEP=0
TOTAL_STEPS=0

# Function to show step progress
show_step_progress() {
    local step_name="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo
    echo -e "${GREEN}================================================================================${NC}"
    echo -e "${GREEN}${BOLD}✅ STEP $CURRENT_STEP OF $TOTAL_STEPS COMPLETED: $step_name ✅${NC}"
    echo -e "${GREEN}================================================================================${NC}"
    echo
}

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
        echo -e "${YELLOW}================================================================================${NC}"
        echo -e "${YELLOW}${BOLD}⏸️  DEBUG MODE - STEP PAUSE ⏸️${NC}"
        echo -e "${YELLOW}================================================================================${NC}"
        echo
        print_status "Press Enter to continue to the next step..."
        read -r
        echo
    fi
}

# Function to execute commands with verbose logging and proper error handling
execute_command() {
    local cmd="$1"
    local description="$2"
    local critical="${3:-true}"  # Default to critical (exit on failure)
    
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
        
        if [[ "$critical" == "true" ]]; then
            print_error "Critical command failed. Aborting installation."
            exit $exit_code
        fi
        return $exit_code
    fi
}

# Function to verify file operations succeeded
verify_file_operation() {
    local operation="$1"  # "download", "extract", etc.
    local file_path="$2"
    local expected_type="${3:-file}"  # "file" or "directory"
    
    if [[ "$expected_type" == "directory" ]]; then
        if [[ -d "$file_path" ]]; then
            print_success "$operation completed successfully"
            return 0
        else
            print_error "$operation failed - directory not found: $file_path"
            return 1
        fi
    else
        if [[ -f "$file_path" ]]; then
            print_success "$operation completed successfully"
            return 0
        else
            print_error "$operation failed - file not found: $file_path"
            return 1
        fi
    fi
}


# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to find Steam Proton installation
find_proton() {
    local battletech_path="$1"
    
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
                # Determine compat data path based on BattleTech installation location
                local compat_data=""
                # Debug output to stderr (won't be captured by command substitution)
                if [[ "$DEBUG_MODE" == "true" ]]; then
                    echo "DEBUG: Found Proton at: $proton_path" >&2
                    echo "DEBUG: BattleTech path: $battletech_path" >&2
                fi
                
                # Extract Steam root from BattleTech path
                if [[ "$battletech_path" == *"/.steam/steam/steamapps/common/BATTLETECH" ]]; then
                    compat_data="$(dirname "$(dirname "$(dirname "$battletech_path")")")/compatdata"
                elif [[ "$battletech_path" == *"/.local/share/Steam/steamapps/common/BATTLETECH" ]]; then
                    compat_data="$(dirname "$(dirname "$(dirname "$battletech_path")")")/compatdata"
                elif [[ "$battletech_path" == *"/usr/share/steam/steamapps/common/BATTLETECH" ]]; then
                    compat_data="$(dirname "$(dirname "$(dirname "$battletech_path")")")/compatdata"
                elif [[ "$battletech_path" == *"/opt/steam/steamapps/common/BATTLETECH" ]]; then
                    compat_data="$(dirname "$(dirname "$(dirname "$battletech_path")")")/compatdata"
                else
                    # For custom paths (like SD cards), try to find compatdata relative to BattleTech path
                    local steam_root="$(dirname "$(dirname "$(dirname "$battletech_path")")")"
                    compat_data="$steam_root/steamapps/compatdata"
                    if [[ "$DEBUG_MODE" == "true" ]]; then
                        echo "DEBUG: Using custom path logic" >&2
                        echo "DEBUG: Steam root: $steam_root" >&2
                        echo "DEBUG: Compat data: $compat_data" >&2
                        # Verify compatdata directory exists (should always exist for Steam installations)
                        if [[ -d "$compat_data" ]]; then
                            echo "DEBUG: Compat data directory exists: $compat_data" >&2
                        else
                            echo "DEBUG: WARNING - Compat data directory missing: $compat_data" >&2
                        fi
                    fi
                fi
                
                # Verify compat data directory exists
                if [[ -d "$compat_data" ]]; then
                    # Extract Steam root path for STEAM_COMPAT_CLIENT_INSTALL_PATH
                    local steam_root="$(dirname "$(dirname "$(dirname "$battletech_path")")")"
                    echo "$proton_path/proton|$compat_data|$steam_root"
                    return 0
                fi
            fi
        done
    done
    
    return 1
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

# Function to download file with progress and proper error handling
download_file() {
    local url="$1"
    local output="$2"
    local filename=$(basename "$output")
    
    # Check if file already exists - if it does, skip download
    if [[ -f "$output" ]]; then
        print_success "File $filename already exists. Skipping download."
        log_message "Skipped download of $filename - file already exists"
        return 0
    fi
    
    print_status "Downloading $filename..."
    
    # Determine download command and execute
    local download_cmd=""
    if command_exists wget; then
        download_cmd="wget --progress=bar:force -O \"$output\" \"$url\""
    elif command_exists curl; then
        download_cmd="curl -L --progress-bar -o \"$output\" \"$url\""
    else
        print_error "Neither wget nor curl is available. Please install one of them."
        exit 1
    fi
    
    # Execute download with proper error handling
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        execute_command "$download_cmd" "Downloading $filename"
    else
        # For non-verbose mode, execute directly but still check for errors
        if ! eval "$download_cmd"; then
            print_error "Download failed for $filename"
            log_message "Download failed: $download_cmd"
            exit 1
        fi
    fi
    
    # Verify download succeeded
    verify_file_operation "Download" "$output" "file"
    log_message "Downloaded $filename from $url"
}

# Function to extract zip file with proper error handling
extract_zip() {
    local zip_file="$1"
    local extract_dir="$2"
    local filename=$(basename "$zip_file")
    
    print_status "Extracting $filename..."
    
    # Verify source file exists
    if [[ ! -f "$zip_file" ]]; then
        print_error "Source file not found: $zip_file"
        exit 1
    fi
    
    # Create extraction directory
    local cmd="mkdir -p \"$extract_dir\""
    execute_command "$cmd" "Creating extraction directory"
    
    # Extract the zip file
    local cmd="unzip -o -q \"$zip_file\" -d \"$extract_dir\""
    execute_command "$cmd" "Extracting $filename to $extract_dir"
    
    # Verify extraction succeeded by checking if directory has content
    if [[ -d "$extract_dir" ]] && [[ -n "$(ls -A "$extract_dir" 2>/dev/null)" ]]; then
        print_success "Extracted $filename"
        log_message "Extracted $filename to $extract_dir"
    else
        print_error "Extraction failed - no content found in $extract_dir"
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
            echo -e "${YELLOW}================================================================================${NC}"
            echo -e "${YELLOW}${BOLD}💾 BACKUP OPTIONS 💾${NC}"
            echo -e "${YELLOW}================================================================================${NC}"
            echo
            echo -e "${BOLD}Existing Mods directory found with $file_count files.${NC}"
            echo
            echo -e "${GREEN}1.${NC} Create backup of existing mods (recommended)"
            echo -e "${GREEN}2.${NC} Continue without backup (existing mods will be overwritten)"
            echo
            echo -e "${YELLOW}================================================================================${NC}"
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
    if proton_info=$(find_proton "$battletech_path"); then
        # Parse Proton path, compat data path, and Steam root
        local proton_cmd=$(echo "$proton_info" | cut -d'|' -f1)
        local compat_data=$(echo "$proton_info" | cut -d'|' -f2)
        local steam_root=$(echo "$proton_info" | cut -d'|' -f3)
        print_success "Found Steam Proton: $proton_cmd"
        print_status "Using compat data path: $compat_data"
        print_status "Using Steam root path: $steam_root"
        if [[ "$DEBUG_MODE" == "true" ]]; then
            print_status "DEBUG: BattleTech path: $battletech_path"
            print_status "DEBUG: Using custom path logic for SD card installation"
        fi
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
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root"
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
        
        show_step_progress "ModTek Injection"
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
    if proton_info=$(find_proton "$battletech_path"); then
        # Parse Proton path, compat data path, and Steam root
        local proton_cmd=$(echo "$proton_info" | cut -d'|' -f1)
        local compat_data=$(echo "$proton_info" | cut -d'|' -f2)
        local steam_root=$(echo "$proton_info" | cut -d'|' -f3)
        print_success "Found Steam Proton: $proton_cmd"
        print_status "Using compat data path: $compat_data"
        print_status "Using Steam root path: $steam_root"
        if [[ "$DEBUG_MODE" == "true" ]]; then
            print_status "DEBUG: BattleTech path: $battletech_path"
            print_status "DEBUG: Using custom path logic for SD card installation"
        fi
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
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root"
    export PROTON_USE_WINED3D=1
    
    # Additional environment variables that might be needed
    export STEAM_COMPAT_APP_ID="$BATTLETECH_APP_ID"
    export PROTON_LOG_DIR="$compat_data/$BATTLETECH_APP_ID"
    
    # Debug output for environment variables
    print_status "Environment variables set:"
    print_status "  STEAM_COMPAT_DATA_PATH=$STEAM_COMPAT_DATA_PATH"
    print_status "  STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_COMPAT_CLIENT_INSTALL_PATH"
    
    # Verify directories exist
    print_status "Verifying directories exist:"
    if [[ -d "$compat_data" ]]; then
        print_status "  ✓ Compat data directory exists: $compat_data"
    else
        print_error "  ✗ Compat data directory missing: $compat_data"
    fi
    
    if [[ -d "$steam_root" ]]; then
        print_status "  ✓ Steam root directory exists: $steam_root"
    else
        print_error "  ✗ Steam root directory missing: $steam_root"
    fi
    
    local app_compat_path="$compat_data/$BATTLETECH_APP_ID"
    if [[ -d "$app_compat_path" ]]; then
        print_status "  ✓ App compat directory exists: $app_compat_path"
    else
        print_warning "  ⚠ App compat directory missing (will be created): $app_compat_path"
    fi
    
    # Use BattleTech's app ID for compat data
    local app_compat_path="$compat_data/$BATTLETECH_APP_ID"
    
    # Set the specific compat data path for this app
    export STEAM_COMPAT_DATA_PATH="$app_compat_path"
    
    # Inform user before starting installation
    print_status "Starting CAB installer with Proton..."
    echo
    echo -e "${YELLOW}================================================================================${NC}"
    echo -e "${YELLOW}${BOLD}⚠️  IMPORTANT CAB INSTALLATION INSTRUCTIONS ⚠️${NC}"
    echo -e "${YELLOW}================================================================================${NC}"
    echo
    echo -e "${BOLD}When the CAB installer window opens, please follow these steps:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Checkout workspace: Leave unchanged (should be on same hard drive)"
    echo -e "${GREEN}2.${NC} Install Target: Make sure it shows ${BOLD}c:\\BATTLETECH\\mods${NC}"
    echo -e "${GREEN}3.${NC} ${BOLD}CRITICAL:${NC} Set ${BOLD}\"CAB Install Mode\"${NC} to ${BOLD}${RED}\"Legacy CABs\"${NC}"
    echo -e "${GREEN}4.${NC} Click ${BOLD}\"Update CAB\"${NC} and wait for it to finish"
    echo -e "${GREEN}5.${NC} ${BOLD}Close the installer window${NC} when complete"
    echo
    echo -e "${YELLOW}================================================================================${NC}"
    echo
    print_status "Press Enter when you're ready to start the CAB installation..."
    read -r
    
    local cmd="\"$proton_cmd\" run \"$cab_exe\""
    execute_command "$cmd" "Running CAB installer with Proton"
    
    # Wait for user to complete installation
    echo
    print_status "CAB installer window is now open!"
    print_warning "Remember: Set 'CAB Install Mode' to 'Legacy CAB' and target 'c:\\BATTLETECH\\mods'"
    print_status "Press Enter when you have completed the installation and closed the window..."
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
        show_step_progress "CAB Files Installation"
    else
        print_warning "CAB files not found in expected Proton directory: $proton_mods_dir"
        log_message "CAB files not found in Proton directory - may need manual installation"
        print_warning "CAB installation may not have completed successfully"
        print_warning "Please check if CAB was installed manually or try running the installer again"
    fi
    
    log_message "CAB installer executed with $proton_cmd"
}

# Function to install BiggerDrops mod
install_biggerdrops() {
    local battletech_path="$1"
    local temp_dir="$SCRIPT_DIR/temp"
    
    print_status "Installing Extended BiggerDrops Patch..."
    wait_for_confirmation
    
    # Download BiggerDrops ZIP file
    local biggerdrops_zip="$temp_dir/Extended_BiggerDrops_Patch.zip"
    download_file "$BIGGERDROPS_URL" "$biggerdrops_zip"
    
    # Extract BiggerDrops to Mods directory
    local mods_dir="$battletech_path/Mods"
    extract_zip "$biggerdrops_zip" "$mods_dir"
    
    show_step_progress "BiggerDrops Files Extraction"
    log_message "Extended BiggerDrops Patch extracted to $mods_dir"
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
            show_step_progress "BEX Files Extraction"
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
    echo -e "${GREEN}================================================================================${NC}"
    echo -e "${GREEN}${BOLD}🎉 ALL STEPS COMPLETED - BEX:CE INSTALLATION SUCCESSFUL! 🎉${NC}"
    echo -e "${GREEN}================================================================================${NC}"
    echo
    echo "Installation Summary:"
    echo "===================="
    echo "BattleTech Path: $battletech_path"
    echo "ModTek: Installed (via Proton)"
    echo "CAB: Installed (via Proton)"
    echo "BEX:CE: Installed"
    if [[ "$INSTALL_BIGGERDROPS" == "true" ]]; then
        echo "Extended BiggerDrops Patch: Installed"
    else
        echo "Extended BiggerDrops Patch: Skipped"
    fi
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
    if [[ "$INSTALL_BIGGERDROPS" == "true" ]]; then
        echo "- Extended BiggerDrops Patch increases mission drop sizes for more challenging battles"
    fi
    show_cleanup_commands
    echo "For support, visit: https://github.com/OhGeezCmon/BattleTech-BEX-CE-Linux-Installer"
    echo "Or contact ohgeezcmon on Discord"
    echo
}

# Function to show cleanup commands
show_cleanup_commands() {
    local temp_dir="$SCRIPT_DIR/temp"
    local cleanup_paths=("$temp_dir")
    
    # Check for Proton directory cleanup if CAB was installed
    local proton_info
    if proton_info=$(find_proton "$battletech_path"); then
        # Parse Proton path, compat data path, and Steam root
        local compat_data=$(echo "$proton_info" | cut -d'|' -f2)
        local steam_root=$(echo "$proton_info" | cut -d'|' -f3)
        local proton_mods_dir="$compat_data/$BATTLETECH_APP_ID/pfx/drive_c/BATTLETECH/mods"
        
        if [[ -d "$proton_mods_dir" ]]; then
            cleanup_paths+=("$proton_mods_dir")
        fi
    fi
    
    echo
    echo -e "${YELLOW}================================================================================${NC}"
    echo -e "${YELLOW}${RED}⚠️  CLEANUP COMMANDS (OPTIONAL) ⚠️${NC}"
    echo -e "${YELLOW}================================================================================${NC}"
    echo
    echo "The following directories can be safely removed to free up disk space:"
    echo
    for path in "${cleanup_paths[@]}"; do
        if [[ -n "$path" && -d "$path" ]]; then
            echo -e "${GREEN}rm -rf \"$path\"${NC}"
        fi
    done
    echo
    echo "Note: These directories contain temporary files and Proton installation data"
    echo "that are no longer needed after installation."
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
    
    echo
    echo -e "${YELLOW}==========================================================================================${NC}"
    echo -e "${YELLOW}${BOLD}██████╗  █████╗ ████████╗████████╗██╗     ███████╗████████╗███████╗ ██████╗██╗  ██╗${NC}"
    echo -e "${YELLOW}${BOLD}██╔══██╗██╔══██╗╚══██╔══╝╚══██╔══╝██║     ██╔════╝╚══██╔══╝██╔════╝██╔════╝██║  ██║${NC}"
    echo -e "${YELLOW}${BOLD}██████╔╝███████║   ██║      ██║   ██║     █████╗     ██║   █████╗  ██║     ███████║${NC}"
    echo -e "${YELLOW}${BOLD}██╔══██╗██╔══██║   ██║      ██║   ██║     ██╔══╝     ██║   ██╔══╝  ██║     ██╔══██║${NC}"
    echo -e "${YELLOW}${BOLD}██████╔╝██║  ██║   ██║      ██║   ███████╗███████╗   ██║   ███████╗╚██████╗██║  ██║${NC}"
    echo -e "${YELLOW}${BOLD}╚═════╝ ╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚══════╝╚══════╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝${NC}"
    echo
    echo -e "${WHITE}${BOLD}▄▖  ▗      ▌   ▌  ▄▖             ▌    ▌    ▄▖ ▌▘▗ ▘    ${NC}"
    echo -e "${WHITE}${BOLD}▙▖▚▘▜▘█▌▛▌▛▌█▌▛▌  ▌ ▛▌▛▛▌▛▛▌▀▌▛▌▛▌█▌▛▘ ▛▘  ▙▖▛▌▌▜▘▌▛▌▛▌${NC}"
    echo -e "${WHITE}${BOLD}▙▖▞▖▐▖▙▖▌▌▙▌▙▖▙▌  ▙▖▙▌▌▌▌▌▌▌█▌▌▌▙▌▙▖▌  ▄▌  ▙▖▙▌▌▐▖▌▙▌▌▌${NC}"
    echo
    echo -e "${YELLOW}==========================================================================================${NC}"
    echo -e "${YELLOW}${BOLD}Installation Script for Linux${NC}"
    echo -e "${YELLOW}${BOLD}BattleTech Extended 3025-3061${NC}"
    echo -e "${YELLOW}${BOLD}Version 1.9.3.7${NC}"
    echo -e "${YELLOW}==========================================================================================${NC}"
    echo
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "${YELLOW}Verbose mode enabled - all commands will be displayed${NC}"
    fi
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${YELLOW}Debug mode enabled - pausing after each step${NC}"
    fi
    echo
    
    # Ask about BiggerDrops mod
    echo -e "${YELLOW}================================================================================${NC}"
    echo -e "${YELLOW}${BOLD}📦 OPTIONAL MOD INSTALLATION 📦${NC}"
    echo -e "${YELLOW}================================================================================${NC}"
    echo
    echo -e "${BOLD}Extended BiggerDrops Patch Mod:${NC}"
    echo -e "- Increases mission drop sizes for more challenging battles"
    echo -e "- ${BOLD}${RED}REQUIRES A NEW SAVE GAME${NC} - cannot be added to existing saves"
    echo -e "- Must decide now - cannot be installed later"
    echo
    echo -e "${YELLOW}================================================================================${NC}"
    echo
    while true; do
        read -p "Do you want to install the Extended BiggerDrops Patch mod? (y/n): " -r
        case $REPLY in
            [Yy]|[Yy][Ee][Ss])
                INSTALL_BIGGERDROPS=true
                print_success "Extended BiggerDrops Patch will be installed"
                break
                ;;
            [Nn]|[Nn][Oo])
                INSTALL_BIGGERDROPS=false
                print_status "Extended BiggerDrops Patch will be skipped"
                break
                ;;
            *)
                echo "Please answer yes (y) or no (n)."
                ;;
        esac
    done
    echo
    
    # Initialize log file
    echo "BEX:CE Installation Log - $(date)" > "$LOG_FILE"
    log_message "Starting BEX:CE installation"
    log_message "Install BiggerDrops: $INSTALL_BIGGERDROPS"
    
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
    
    # Set up error handling trap
    trap 'print_error "Installation failed. Check the log file for details: $LOG_FILE"; show_cleanup_commands; exit 1' ERR
    
    # Backup existing mods
    print_status "Checking for existing mods and creating backup..."
    wait_for_confirmation
    backup_existing_mods "$battletech_path"
    
    # Calculate total steps
    TOTAL_STEPS=3  # BEX:CE, CAB, ModTek
    if [[ "$INSTALL_BIGGERDROPS" == "true" ]]; then
        TOTAL_STEPS=$((TOTAL_STEPS + 1))  # Add BiggerDrops step
    fi
    
    # Install components
    install_bex_ce "$battletech_path"
    
    # Install BiggerDrops if requested
    if [[ "$INSTALL_BIGGERDROPS" == "true" ]]; then
        install_biggerdrops "$battletech_path"
    fi
    
    install_cab "$battletech_path"
    install_modtek "$battletech_path"
    
    # Prepare cleanup information
    print_status "Preparing cleanup information..."
    local cleanup_paths=()
    cleanup_paths+=("$temp_dir")
    
    # Check for Proton directory cleanup if CAB was installed
    local proton_info
    if proton_info=$(find_proton "$battletech_path"); then
        # Parse Proton path, compat data path, and Steam root
        local compat_data=$(echo "$proton_info" | cut -d'|' -f2)
        local steam_root=$(echo "$proton_info" | cut -d'|' -f3)
        local proton_mods_dir="$compat_data/$BATTLETECH_APP_ID/pfx/drive_c/BATTLETECH/mods"
        
        if [[ -d "$proton_mods_dir" ]]; then
            cleanup_paths+=("$proton_mods_dir")
        fi
    fi
    
    # Clear error trap since we completed successfully
    trap - ERR
    
    # Show summary
    show_summary "$battletech_path" "${cleanup_paths[@]}"
    
    log_message "BEX:CE installation completed successfully"
}

# Run main function
main "$@"
