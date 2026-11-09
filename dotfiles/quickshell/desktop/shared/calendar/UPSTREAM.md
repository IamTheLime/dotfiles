# Calendar source

Adapted from https://github.com/derekross/omarchy-calendar at
`0c31e965037f7a388b733bfe9ba15cab36f56e7b` (MIT; see LICENSE).
ClockModel.js and Model.js are unchanged. Service.qml uses a private Google
configuration and connection marker, disables notifications by default, and
replaces Omarchy notification commands with notify-send. The popup uses our
shared theme and components rather than the Omarchy shell UI.
