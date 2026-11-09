// Add a stable tray ID (or tooltip title) and an SVG filename here.
var icons = {
    "nordvpn": "nordvpn",
    "1password_status_icon_1": "1password",
    "signal_status_icon_1": "signal",
    "zapzap": "zapzap",
    "heroic_status_icon_1": "heroic",
    "discord_status_icon_1": "discord",
    "dnf-app-center-updater": "updater",
    "xwayland video bridge": "video-bridge",
    "chatgpt": "chatgpt"
};

function name(item) {
    return icons[String(item.id || "").toLowerCase()]
        || icons[String(item.tooltipTitle || "").toLowerCase()]
        || icons[String(item.title || "").toLowerCase()] || "";
}

function keepTint(item) {
    return ["steam", "telegramdesktop", "handy"].indexOf(String(item.id || "").toLowerCase()) >= 0
        || String(item.title || "").toLowerCase() === "handy";
}
