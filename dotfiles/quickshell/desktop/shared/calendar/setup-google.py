#!/usr/bin/env python3
"""Configure the local calendar cache; optionally connect a Desktop OAuth client."""
import argparse
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--oauth', type=Path, help='Downloaded Google Desktop OAuth JSON (kept outside dotfiles)')
args = parser.parse_args()
os.umask(0o077)
config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))
state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'quickshell-calendar'
data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'quickshell-calendar'
private = config / 'quickshell-calendar'
for directory in [private, state, data / 'calendars/local', config / 'khal']:
    directory.mkdir(parents=True, exist_ok=True)
    directory.chmod(0o700)
khal_config = config / 'khal/config'
if not khal_config.exists():
    khal_config.write_text(f'''[calendars]
[[desktop]]
path = {data}/calendars/*
type = discover
readonly = true

[locale]
timeformat = %H:%M
dateformat = %Y-%m-%d
longdateformat = %Y-%m-%d
datetimeformat = %Y-%m-%d %H:%M
longdatetimeformat = %Y-%m-%d %H:%M
firstweekday = 0
''')
    khal_config.chmod(0o600)
else:
    print('Existing khal config kept; ensure it includes', data / 'calendars/*')
if not args.oauth:
    print('Local calendar cache ready. Run again with --oauth /path/to/downloaded-client.json to connect Google.')
    raise SystemExit(0)
client = json.loads(args.oauth.expanduser().read_text()).get('installed')
if not client or not client.get('client_id') or not client.get('client_secret'):
    parser.error('Expected a downloaded Desktop OAuth client JSON with an installed section')
path = private / 'vdirsyncer.conf'
content = f'''[general]
status_path = {json.dumps(str(state / 'sync-status'))}

[pair google]
a = "google_local"
b = "google_remote"
collections = ["from b"]
conflict_resolution = "b wins"
metadata = ["color", "displayname"]

[storage google_local]
type = "filesystem"
path = {json.dumps(str(data / 'calendars'))}
fileext = ".ics"

[storage google_remote]
type = "google_calendar"
read_only = true
token_file = {json.dumps(str(private / 'google-token.json'))}
client_id = {json.dumps(client['client_id'])}
client_secret = {json.dumps(client['client_secret'])}
'''
if path.exists() and path.read_text() != content:
    parser.error(f'{path} belongs to a different configuration; refusing to replace it')
path.write_text(content)
path.chmod(0o600)
print('Private configuration written. Authorise Google in the browser when prompted.')
for command in ['discover', 'sync', 'metasync']:
    subprocess.run(['vdirsyncer', '-c', str(path), command, 'google'], check=True)
(state / 'connected').write_text('google\n')
print('Google calendar connected. The popup will refresh and sync every 15 minutes.')
