export const VERSION = 1;
export const PANEL_PREFIX = 'Quickshell panel: ';
export const GROUP_PREFIX = 'Quickshell group: ';

export function validateCommand(command) {
    if (!command || typeof command !== 'object' || Array.isArray(command))
        throw new Error('Command must be an object');
    const keys = Object.keys(command);
    if (keys.length !== 1) throw new Error('Exactly one command is required');
    const key = keys[0];
    const value = command[key];
    const ids = list => Array.isArray(list) && list.length > 0 && list.every(id => typeof id === 'string');
    if (key === 'activate' && typeof value === 'string') return command;
    if ((key === 'close' || key === 'restore') && ids(value)) return command;
    if (key === 'layout' && value && typeof value.key === 'string' && ids(value.ids) && ids(value.slots)
        && value.slots.length <= 2 && new Set(value.ids).size === value.ids.length
        && new Set(value.slots).size === value.slots.length && value.slots.every(id => value.ids.includes(id))
        && typeof value.screen === 'string' && typeof value.focus === 'string'
        && Number.isFinite(value.ratio) && value.ratio >= 0.2 && value.ratio <= 0.8) return command;
    if (key === 'panel' && value && typeof value.title === 'string' && value.title.startsWith(PANEL_PREFIX)
        && typeof value.screen === 'string' && ['top', 'bottom'].includes(value.edge)
        && ['x', 'y', 'width', 'height', 'screenWidth', 'screenHeight', 'reserve'].every(k => Number.isFinite(value[k]))
        && value.width > 0 && value.height > 0 && value.screenWidth > 0 && value.screenHeight > 0
        && value.width <= value.screenWidth * 2 && value.height <= value.screenHeight
        && value.reserve >= 0 && value.reserve <= value.height) return command;
    throw new Error('Unsupported or invalid desktop command: ' + key);
}

export function slotsFor(rect, layout) {
    const available = Math.max(200, rect.width - 8 - (layout.slots.length - 1) * 8);
    const left = layout.slots.length === 2 ? Math.floor(available * layout.ratio) : available;
    return layout.slots.map((id, index) => ({id, x: rect.x + 4 + (index ? left + 8 : 0),
        y: rect.y + 40, width: index ? available - left : left, height: Math.max(100, rect.height - 44)}));
}
