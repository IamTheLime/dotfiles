/**
 * Contract between a plugin and the app. Mirrored by
 * `crates/tw-scripting/src/protocol.rs`; the host test round-trips both.
 *
 * A plugin is one `.ts` file in this folder that default-exports a `Plugin`.
 * Node runs it with native type stripping, so it must use erasable syntax
 * only (no enums, namespaces or parameter properties; `tsconfig.json`
 * enforces this) and import other files with their `.ts` extension. npm
 * packages, `async`, `fetch` and timers all work. Saving any file here
 * reloads every plugin.
 */

export interface TabInfo {
  id: number;
  title: string;
}

/** What the app passes to `render` and `onAction`. */
export interface PluginState {
  activeTab: number;
  tabs: TabInfo[];
}

/** What a plugin may ask the app to do. Executed in order. */
export type HostCommand =
  | { type: "writeToTerminal"; text: string }
  | { type: "newTab" }
  | { type: "selectTab"; index: number }
  | { type: "log"; message: string }
  /** Show a markdown document in the sidebar, replacing the current one. */
  | { type: "showMarkdown"; title?: string; markdown: string };

/** The widget tree returned from `render`. */
export type Widget =
  | { type: "column"; children: Widget[]; gap?: number }
  | { type: "row"; children: Widget[]; gap?: number }
  | { type: "text"; text: string; color?: `#${string}`; size?: number }
  | { type: "button"; label: string; action: string };

export interface Plugin {
  name: string;
  /** Called whenever the app's state changes. May be async. */
  render(state: PluginState): Widget | Promise<Widget>;
  /** Called with a button's `action` when it is clicked. May be async. */
  onAction?(action: string, state: PluginState): HostCommand[] | Promise<HostCommand[]>;
}

export const text = (text: string, color?: `#${string}`, size?: number): Widget => ({ type: "text", text, color, size });
export const button = (label: string, action: string): Widget => ({ type: "button", label, action });
export const column = (children: Widget[], gap?: number): Widget => ({ type: "column", children, gap });
export const row = (children: Widget[], gap?: number): Widget => ({ type: "row", children, gap });
