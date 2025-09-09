# BattleTech Extended Commander's Edition (BEX:CE) Linux Installer

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![BattleTech](https://img.shields.io/badge/BattleTech-Extended%20CE-orange.svg)](https://www.paradoxinteractive.com/games/battletech/about)
[![Linux](https://img.shields.io/badge/platform-Linux-green.svg)](https://www.linux.org/)

A comprehensive installation script for BattleTech Extended Commander's Edition (BEX:CE) on Linux systems using Steam Proton. This script automates the installation of BEX:CE v1.9.3.7 and optionally installs the Extended BiggerDrops Patch mod.

## Overview

BattleTech Extended Commander's Edition (BEX:CE) is a massive overhaul mod for BattleTech that extends the timeline from 3025 to 3061, adding hundreds of new mechs, vehicles, weapons, and gameplay mechanics. This installer script makes it easy to install BEX:CE on Linux systems without the complexity of manual Wine configuration.

### What This Script Installs

- **BEX:CE v1.9.3.7** - The main BattleTech Extended mod
- **ModTek v0.8.0** - Essential mod loader for BattleTech
- **CAB (Community Asset Bundle)** - Required asset pack for BEX:CE
- **Extended BiggerDrops Patch** (Optional) - Increases mission drop sizes for more challenging battles

## Requirements

### System Requirements
- **Linux** (tested on Bazzite and SteamOS, should work on others)
- **Steam** with BattleTech installed
- **Proton** (comes with Steam) - tested with Proton 8.0 (recommended)
- **Internet connection** for downloading mod files

### Required Tools
The script will check for and guide you to install if missing:
- `unzip` - For extracting mod archives
- `wget` or `curl` - For downloading files

### BattleTech Installation
- BattleTech must be installed through Steam
- **Important**: This script requires Proton to be available, which means:
  - BattleTech must be installed as a **Windows game** (not native Linux), OR
  - You must have installed another Windows game that uses Proton, OR
  - You must have manually configured Proton for BattleTech
- If you only have the native Linux version of BattleTech, you'll need to either:
  - Reinstall BattleTech as a Windows game, or
  - Install another Windows game first to set up Proton
- BattleTech should be located in one of these standard Steam directories:
  - `~/.steam/steam/steamapps/common/BATTLETECH`
  - `~/.local/share/Steam/steamapps/common/BATTLETECH`
  - `/usr/share/steam/steamapps/common/BATTLETECH`
  - `/opt/steam/steamapps/common/BATTLETECH`

## Quick Start

1. **Download the installer:**
   ```bash
   mkdir bex-installer && cd bex-installer && wget https://raw.githubusercontent.com/OhGeezCmon/BattleTech-BEX-CE-Linux-Installer/main/install-bex-ce.sh
   ```

2. **Make the script executable:**
   ```bash
   chmod +x install-bex-ce.sh
   ```

3. **Run the installer:**
   ```bash
   ./install-bex-ce.sh
   ```

4. **Follow the on-screen prompts** to complete the installation.

## Detailed Instructions

### Basic Installation

The script will guide you through the following steps:

1. **System Check** - Verifies required tools are installed
2. **BattleTech Detection** - Automatically finds your BattleTech installation
3. **Mod Backup** - Offers to backup existing mods (recommended)
4. **BEX:CE Installation** - Downloads and extracts the main mod files
5. **Optional BiggerDrops** - Prompts to install Extended BiggerDrops Patch
6. **CAB Installation** - Runs the Community Asset Bundle installer via Proton
7. **ModTek Installation** - Sets up the mod loader
8. **Cleanup** - Provides commands to remove temporary files

### Installation Modes

#### Normal Mode (Default)
```bash
./install-bex-ce.sh
```
- Standard installation with progress indicators
- Minimal output, user-friendly interface

#### Verbose Mode
```bash
./install-bex-ce.sh --verbose
```
- Shows all commands being executed

#### Debug Mode
```bash
./install-bex-ce.sh --debug
```
- Pauses after each step for confirmation
- Allows you to review each action before proceeding
- Perfect for first-time users or troubleshooting

#### Combined Modes
```bash
./install-bex-ce.sh --verbose --debug
```
- Combines verbose logging with step-by-step confirmation
- Maximum control and visibility


## Configuration Options

### Command Line Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose mode (shows all commands) |
| `-d, --debug` | Enable debug mode (step-by-step confirmation) |
| `-h, --help` | Show help message and exit |

### Installation Choices

- **Extended BiggerDrops Patch**: Increases mission drop sizes
  - ⚠️ **Requires a new save game** - cannot be added to existing saves
  - Must decide during installation - cannot be added later

- **Mod Backup**: Backs up existing mods before installation
  - Recommended to avoid losing existing mods
  - Creates timestamped backup in place

## Troubleshooting

### Common Issues

#### "Steam Proton not found"
- Ensure Steam is installed and running
- **Check BattleTech installation type**: If you have the native Linux version, you need to either:
  - Reinstall BattleTech as a Windows game (right-click → Properties → Compatibility → Force use of compatibility tool)
  - Install another Windows game first to set up Proton
- Verify Proton is available in Steam (usually comes with Steam)
- Check that BattleTech is installed through Steam

#### "BattleTech installation not found"
- The script will prompt you to enter the path manually
- Ensure the directory contains either `BattleTech` (Linux) or `BattleTech.exe` (Windows/Proton)

#### "CAB installation failed"
- Ensure you select "Legacy CAB" mode in the installer
- Verify the install target is set to `c:\BATTLETECH\mods`
- Check that the installer window is closed before continuing

#### "ModTek injection failed"
- Ensure the ModTekInjector.exe window stays open until completion
- Check the batch file output for error messages
- Verify Proton is working correctly

### Log Files

The script creates detailed logs in `bex-install.log` for troubleshooting:
```bash
cat bex-install.log
```

### Getting Help

- **GitHub Issues**: [Report bugs or request features](https://github.com/OhGeezCmon/BattleTech-BEX-CE-Linux-Installer/issues)
- **Discord**: Contact `ohgeezcmon` on Discord for direct support
- **BEX:CE Community**: [Mods in Exile Discourse](https://discourse.modsinexile.com/)

## File Structure

After installation, your BattleTech directory will look like this:

```
BATTLETECH/
├── Mods/
│   ├── ModTek/                 # Mod loader
│   ├── BT_Extended_Clans/      # BEX:CE main mod
│   ├── Extended_BiggerDrops/   # Optional BiggerDrops mod
│   └── [CAB files]/            # Community Asset Bundle
├── BattleTech.exe              # Game executable
└── [other game files]
```

## Post-Installation

### Starting the Game

1. **Launch BattleTech through Steam**
2. **Start a new campaign or career** (BEX:CE requires new saves)
3. **Select your preferred difficulty**:
   - Normal
   - Hard
   - Simulation
   - Simulation+

### Important Notes

- **New Save Required**: BEX:CE cannot be added to existing save games
- **Timeline**: Campaign starts in 3025 and progresses to 3061
- **Mod Compatibility**: Check compatibility with other mods before installing

## Cleanup

After successful installation, you can remove temporary files:

```bash
# Remove temporary download directory
rm -rf ./temp

# Remove Proton installation directory (if CAB was installed)
rm -rf ~/.steam/steam/steamapps/compatdata/637090/pfx/drive_c/BATTLETECH/mods
```

*Note: The script will provide these exact commands at the end of installation.*

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **GitHub**: [https://github.com/OhGeezCmon/BattleTech-BEX-CE-Linux-Installer](https://github.com/OhGeezCmon/BattleTech-BEX-CE-Linux-Installer)
- **Discord**: Contact `ohgeezcmon` on Discord
- **BEX:CE Community**: [https://discourse.modsinexile.com/](https://discourse.modsinexile.com/t/battletech-extended-3025-3061-1-9-3-7/426)

---

*Special thanks to the BEX:CE team for creating this amazing mod that makes BattleTech even more incredible!*
