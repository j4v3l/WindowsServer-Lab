# 🎨 Oh My Posh Setup Guide

## 🎯 What You'll Learn

- How to install and configure Oh My Posh on Windows systems
- How to customize your PowerShell prompt with beautiful themes
- How to install and use Nerd Fonts for proper rendering of icons
- How to integrate Oh My Posh with Windows Terminal and VS Code

## 📋 Prerequisites

- Windows 10 or Windows 11
- PowerShell 5.1 or PowerShell Core (7.x)
- Administrator privileges (recommended but not required)
- Windows Terminal (optional, but recommended)
- VS Code (optional)

## 🚀 Quick Start

The simplest way to set up Oh My Posh is by running our automated setup script:

```powershell
# Run with default settings
.\Scripts\Setup-OhMyPosh.ps1

# Run with a specific theme
.\Scripts\Setup-OhMyPosh.ps1 -Theme "paradox"

# Run with Windows Terminal and VS Code configuration
.\Scripts\Setup-OhMyPosh.ps1 -ConfigureWindowsTerminal -ConfigureVSCode
```

## 🛠️ Manual Installation

If you prefer to install Oh My Posh manually, follow these steps:

1. **Install Oh My Posh**

   ```powershell
   # Using winget (recommended)
   winget install JanDeDobbeleer.OhMyPosh -s winget

   # OR using the installer script
   Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
   ```

2. **Install a Nerd Font**

   ```powershell
   # List available fonts
   oh-my-posh font list

   # Install a font
   oh-my-posh font install MesloLGM
   ```

3. **Configure PowerShell Profile**

   ```powershell
   # Create or open your PowerShell profile
   if (!(Test-Path -Path $PROFILE)) {
       New-Item -Path $PROFILE -Type File -Force
   }
   notepad $PROFILE

   # Add this line to your profile
   oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
   ```

## 🎨 Customizing Oh My Posh

### Themes

Oh My Posh comes with many built-in themes. To view available themes:

```powershell
oh-my-posh theme list
```

To preview a theme:

```powershell
Get-PoshThemes
```

To use a different theme, either:

1. Update your PowerShell profile with the new theme path
2. Run our setup script with the `-Theme` parameter:

```powershell
.\Scripts\Setup-OhMyPosh.ps1 -Theme "atomic"
```

### Custom Themes

You can create custom themes by:

1. Exporting an existing theme:

   ```powershell
   oh-my-posh config export --output "C:\Users\YourName\Documents\custom.omp.json"
   ```

2. Editing the JSON file to customize colors, segments, etc.

3. Updating your PowerShell profile to use your custom theme:

   ```powershell
   oh-my-posh init pwsh --config "C:\Users\YourName\Documents\custom.omp.json" | Invoke-Expression
   ```

## 🖥️ Terminal Integration

### Windows Terminal

1. Open Windows Terminal settings (Ctrl+,)
2. Find the profiles section and add the following to the defaults:

```json
"defaults": {
    "font": {
        "face": "MesloLGM NF"
    }
}
```

### VS Code

1. Open Settings (Ctrl+,)
2. Search for "terminal font"
3. Set "Terminal > Integrated: Font Family" to `MesloLGM NF`

## ❓ Troubleshooting

### Icons Not Displaying

If icons appear as rectangles or question marks:

- Ensure you've installed a Nerd Font
- Verify your terminal is using the Nerd Font
- Try a different Nerd Font (e.g., FiraCode, JetBrainsMono)

### Oh My Posh Not Starting

If Oh My Posh doesn't initialize on PowerShell startup:

- Check your PowerShell profile with `notepad $PROFILE`
- Ensure the Oh My Posh initialization line is present and correct
- Verify Oh My Posh is installed with `oh-my-posh --version`

### Performance Issues

If you experience lag in your terminal:

- Try a simpler theme (e.g., "minimal", "pure")
- Disable segments you don't need by editing your theme
- Adjust refresh milliseconds in your theme configuration

## 📚 Additional Resources

- [Oh My Posh Documentation](https://ohmyposh.dev/)
- [Windows Terminal Documentation](https://docs.microsoft.com/en-us/windows/terminal/)
- [Nerd Fonts Website](https://www.nerdfonts.com/)

## 🔄 Integration with Windows Server Lab Environment

This Oh My Posh setup script is part of the Windows Server Lab Environment project adapted for Proxmox VE. It follows the same standards and conventions as other scripts in the project.

For a smooth integration:

1. Make sure to run the script from the project directory
2. Consider configuring all your lab machines with the same theme for consistency
3. Include the setup as part of your lab deployment automation scripts
