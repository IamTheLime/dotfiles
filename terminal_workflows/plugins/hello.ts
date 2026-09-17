import { button, column, row, text, type Plugin } from "./api.ts";

const plugin: Plugin = {
  name: "hello",

  render(state) {
    const active = state.tabs[state.activeTab];
    const count = state.tabs.length;
    return column(
      [
        text(`${count} tab${count === 1 ? "" : "s"}, active: ${active?.title ?? "none"}`),
        text("Edit plugins/hello.ts and save to reload.", "#8a90a0"),
        row([button("Say hi", "hi"), button("List files", "ls"), button("New tab", "tab")], 6),
      ],
      8,
    );
  },

  onAction(action) {
    switch (action) {
      case "hi":
        return [{ type: "writeToTerminal", text: "echo hi from plugins/hello.ts\n" }];
      case "ls":
        return [{ type: "writeToTerminal", text: "ls -la\n" }];
      case "tab":
        return [{ type: "newTab" }, { type: "log", message: "opened a tab from hello.ts" }];
      default:
        return [{ type: "log", message: `hello.ts: unknown action ${action}` }];
    }
  },
};

export default plugin;
