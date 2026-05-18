import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("update", {
    description: "Update pi and reload configuration",
    handler: async (_args, ctx) => {
      ctx.ui.notify("Updating pi...", "info");

      try {
        const result = await pi.exec("pi", ["update", "--self"], { timeout: 120_000 });

        // "already up to date" is a success state, not an error
        const combinedOutput = (result.stdout + "\n" + result.stderr).trim();
        const isUpToDate = /already up to date/i.test(combinedOutput);

        if (result.exitCode !== 0 && !isUpToDate) {
          const err = result.stderr.trim() || result.stdout.trim() || "Unknown error";
          ctx.ui.notify(`pi update failed: ${err}`, "error");
          return;
        }

        if (isUpToDate) {
          ctx.ui.notify("pi is already up to date.", "info");
          return;
        }

        ctx.ui.notify("pi updated successfully.", "info");
        if (result.stdout.trim()) {
          console.log(result.stdout.trim());
        }

        // Reload configuration only when there was an actual update
        ctx.ui.notify("Reloading configuration...", "info");
        await ctx.reload();
      } catch (error) {
        ctx.ui.notify(`pi update failed: ${error instanceof Error ? error.message : String(error)}`, "error");
      }
      return;
    },
  });
}
