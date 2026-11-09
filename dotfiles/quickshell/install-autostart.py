#!/usr/bin/env python3
"""Register the dotfiles Quickshell launcher with the desktop session."""
import os
from pathlib import Path

launcher = Path(__file__).resolve().with_name('run.sh')
autostart = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'autostart'
target = autostart / 'dotfiles-quickshell.desktop'

# Exec quoting, followed by Desktop Entry string escaping (two parsing layers).
argument = str(launcher).replace('%', '%%')
for char in ('\\', '"', '`', '$'):
    argument = argument.replace(char, '\\' + char)
argument = argument.replace('\\', '\\\\')
entry = f'''[Desktop Entry]
Type=Application
Name=Quickshell desktop
Comment=Start the dotfiles top bar and dock
Exec="{argument}" -n
TryExec=qs
Terminal=false
OnlyShowIn=KDE;GNOME;
'''
autostart.mkdir(parents=True, exist_ok=True)
if target.exists() and target.read_text() != entry:
    target.with_suffix('.desktop.backup').write_text(target.read_text())
target.write_text(entry)
print(f'Enabled login startup: {target}')
