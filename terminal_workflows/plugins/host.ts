/**
 * The plugin host. The app spawns this file under Node and talks to it over
 * stdin/stdout, one JSON object per line (see `Request` and `Message`).
 * Every plugin file in this folder is imported, watched, and re-imported on
 * change. Plugin `console.log` calls are forwarded to the app as `log`.
 */
import { watch } from "node:fs";
import { readdir } from "node:fs/promises";
import { basename, join } from "node:path";
import { createInterface } from "node:readline";
import { pathToFileURL } from "node:url";
import type { HostCommand, Plugin, PluginState, Widget } from "./api.ts";

type Request =
  | { id: number; type: "render"; state: PluginState }
  | { id: number; type: "action"; plugin: string; action: string; state: PluginState }
  | { type: "reload" };

type View = { status: "ok"; name: string; widget: Widget } | { status: "error"; name: string; error: string };

type Message =
  | { type: "ready"; plugins: string[] }
  | { type: "rendered"; id: number; views: View[] }
  | { type: "actions"; id: number; commands: HostCommand[] }
  | { type: "failed"; id: number; message: string }
  | { type: "changed"; plugins: string[] }
  | { type: "log"; message: string };

type Loaded = { name: string; plugin: Plugin } | { name: string; error: string };

const dir = import.meta.dirname;
const RESERVED = new Set(["host.ts", "api.ts"]);
const RELOAD_DEBOUNCE_MS = 80;

const send = (message: Message): void => {
  process.stdout.write(JSON.stringify(message) + "\n");
};

const describe = (error: unknown): string => (error instanceof Error ? (error.stack ?? error.message) : String(error));

const log = (...args: unknown[]): void => {
  send({ type: "log", message: args.map((a) => (typeof a === "string" ? a : JSON.stringify(a))).join(" ") });
};
console.log = log;
console.info = log;
console.warn = log;
console.error = log;

let loaded: Loaded[] = [];
const names = (): string[] => loaded.map((entry) => entry.name);

async function load(): Promise<void> {
  const files = (await readdir(dir)).filter((f) => f.endsWith(".ts") && !f.endsWith(".d.ts") && !RESERVED.has(f)).sort();
  const next: Loaded[] = [];
  for (const file of files) {
    const name = basename(file, ".ts");
    try {
      // The query string bypasses the ES module cache so a saved file is really re-read.
      const url = pathToFileURL(join(dir, file)).href + `?v=${Date.now()}`;
      const mod = (await import(url)) as { default?: Plugin };
      const plugin = mod.default;
      if (!plugin || typeof plugin.render !== "function") {
        throw new Error(`${file}: the default export must be a Plugin with a render() method`);
      }
      next.push({ name: plugin.name || name, plugin });
    } catch (error) {
      next.push({ name, error: describe(error) });
    }
  }
  loaded = next;
}

async function render(state: PluginState): Promise<View[]> {
  return Promise.all(
    loaded.map(async (entry): Promise<View> => {
      if ("error" in entry) return { status: "error", name: entry.name, error: entry.error };
      try {
        return { status: "ok", name: entry.name, widget: await entry.plugin.render(state) };
      } catch (error) {
        return { status: "error", name: entry.name, error: describe(error) };
      }
    }),
  );
}

async function action(pluginName: string, action: string, state: PluginState): Promise<HostCommand[]> {
  const entry = loaded.find((e) => e.name === pluginName);
  if (!entry) throw new Error(`plugin "${pluginName}" is not loaded`);
  if ("error" in entry) throw new Error(entry.error);
  return (await entry.plugin.onAction?.(action, state)) ?? [];
}

async function handle(request: Request): Promise<void> {
  switch (request.type) {
    case "render":
      send({ type: "rendered", id: request.id, views: await render(request.state) });
      return;
    case "action":
      try {
        send({ type: "actions", id: request.id, commands: await action(request.plugin, request.action, request.state) });
      } catch (error) {
        send({ type: "failed", id: request.id, message: describe(error) });
      }
      return;
    case "reload":
      await load();
      send({ type: "changed", plugins: names() });
      return;
    default: {
      const unreachable: never = request;
      throw new Error(`unknown request ${JSON.stringify(unreachable)}`);
    }
  }
}

let reloadTimer: NodeJS.Timeout | undefined;
watch(dir, { persistent: false }, (_event, filename) => {
  if (!filename?.endsWith(".ts")) return;
  clearTimeout(reloadTimer);
  reloadTimer = setTimeout(() => {
    void load().then(() => send({ type: "changed", plugins: names() }));
  }, RELOAD_DEBOUNCE_MS);
});

await load();
send({ type: "ready", plugins: names() });

for await (const line of createInterface({ input: process.stdin })) {
  if (!line.trim()) continue;
  let request: Request;
  try {
    request = JSON.parse(line) as Request;
  } catch (error) {
    log(`host.ts: ignoring a line that is not JSON: ${describe(error)}`);
    continue;
  }
  await handle(request);
}
