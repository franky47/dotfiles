import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const rewrite = async (command: string, signal?: AbortSignal) => {
    try {
      const result = await pi.exec("rtk", ["rewrite", command], { timeout: 10_000, signal });
      const rewritten = result.stdout.trim();
      return rewritten && rewritten !== command ? rewritten : command;
    } catch {
      return command;
    }
  };

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash" && event.toolName !== "shell") return;

    const input = event.input as { command?: unknown };
    if (typeof input.command !== "string" || !input.command) return;

    input.command = await rewrite(input.command, ctx.signal);
  });
}
