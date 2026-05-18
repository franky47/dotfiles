import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("update", {
    description: "Update pi and reload configuration",
    handler: async (_args, ctx) => {
      ctx.ui.notify("Updating pi...", "info");

      try {
        const beforeResult = await pi.exec("pi", ["--version"], { timeout: 5_000 });
        const before = beforeResult.stdout.trim() || beforeResult.stderr.trim() || "unknown";

        const result = await pi.exec("pi", ["update", "--self"], { timeout: 120_000 });

        // "already up to date" is a success state, not an error
        const combinedOutput = (result.stdout + "\n" + result.stderr).trim();
        const isUpToDate = /already up to date/i.test(combinedOutput);

        if (result.code !== 0 && !isUpToDate) {
          const err = result.stderr.trim() || result.stdout.trim() || "Unknown error";
          ctx.ui.notify(`pi update failed: ${err}`, "error");
          return;
        }

        if (isUpToDate) {
          ctx.ui.notify("pi is already up to date.", "info");
          return;
        }

        const afterResult = await pi.exec("pi", ["--version"], { timeout: 5_000 });
        const after = afterResult.stdout.trim() || afterResult.stderr.trim() || "unknown";
        const versionMsg = before !== after && before !== "unknown" && after !== "unknown"
          ? `pi updated: ${before} → ${after}`
          : "pi updated successfully.";

        // Reload configuration only when there was an actual update
        ctx.ui.notify("Reloading configuration...", "info");
        await ctx.reload();

        // Print after reload so the message isn't wiped by the screen reset
        ctx.ui.notify(versionMsg, "info");
      } catch (error) {
        ctx.ui.notify(`pi update failed: ${error instanceof Error ? error.message : String(error)}`, "error");
      }
      return;
    },
  });
}
