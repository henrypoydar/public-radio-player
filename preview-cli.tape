#
# A script for creating a preview of the prp CLI
# Requires https://github.com/charmbracelet/vhs
#

Output preview-cli.mp4

Set FontSize 22
Set Width 1280
Set Height 720
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms

# Make sure the menu bar app is running before we drive it (hidden setup).
Hide
Type "open -a PublicRadioPlayer"
Enter
Type "clear"
Enter
Sleep 2s
Show

# List the stations and channels.
Type "prp list"
Enter
Sleep 2.5s

# Where are we now?
Type "prp status"
Enter
Sleep 1.5s

# Switch channel (spaces work via the CLI).
Type 'prp switch Eclectic24'
Enter
Sleep 1.5s

# Start playback.
Type "prp play"
Enter
Sleep 3s

Type "prp status"
Enter
Sleep 1.5s

# Switch channels mid-playback.
Type "prp switch FIP"
Enter
Sleep 2.5s

# Pause.
Type "prp pause"
Enter
Sleep 2s
