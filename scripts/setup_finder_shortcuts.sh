#!/bin/bash
# One-time macOS setup for the "Finder & System" pad template:
#   ⌃⌥⌘F → Turn Do Not Disturb On/Off   (Keyboard Shortcuts → Mission Control)
#   ⌃⌥⌘T → New Terminal at Folder       (Keyboard Shortcuts → Services → Files and Folders)
#
# Same result as setting them by hand in System Settings → Keyboard → Keyboard
# Shortcuts. Backs up both preference domains first; undo with:
#   defaults import com.apple.symbolichotkeys <backup>/symbolichotkeys.plist
#   defaults import pbs <backup>/pbs.plist
set -euo pipefail

BACKUP="$HOME/.config/micropad-studio/shortcut-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
defaults export com.apple.symbolichotkeys "$BACKUP/symbolichotkeys.plist"
defaults export pbs "$BACKUP/pbs.plist"
echo "backed up current shortcut settings to $BACKUP"

# Symbolic hotkey 175 = "Turn Do Not Disturb On/Off".
# parameters = (ASCII 'f' = 102, virtual keycode kVK_ANSI_F = 3,
#               modifiers ⌃ 262144 + ⌥ 524288 + ⌘ 1048576 = 1835008)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 175 \
    '{ enabled = 1; value = { parameters = (102, 3, 1835008); type = standard; }; }'

# Services shortcut: key_equivalent uses ^ = ⌃, ~ = ⌥, @ = ⌘.
defaults write pbs NSServicesStatus -dict-add \
    '"com.apple.Terminal - New Terminal at Folder - newTerminalAtFolder"' \
    '{ enabled_context_menu = 1; enabled_services_menu = 1; key_equivalent = "^~@t"; presentation_modes = { ContextMenu = 1; ServicesMenu = 1; }; }'

# Apply without logging out.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

echo "bound ⌃⌥⌘F → Do Not Disturb, ⌃⌥⌘T → New Terminal at Folder"
echo "If a shortcut doesn't respond yet, log out and back in (or check System Settings → Keyboard → Keyboard Shortcuts)."
