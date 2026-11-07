#!/usr/bin/env bash
set -euo pipefail

kwriteconfig6 --file kwinrc --group Windows --key ElectricBorderMaximize false
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure
