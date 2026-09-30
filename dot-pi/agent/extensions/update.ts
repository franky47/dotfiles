import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("update", {
    description: "Update Pi and installed extensions, then reload configuration",
    handler: async (_args, ctx) => {
      ctx.ui.notify("Updating Pi and extensions...", "info");

      let result;
      try {
        result = await pi.exec("pi", ["update", "--all"], { timeout: 240_000 });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Pi update failed: ${message}`, "error");
        return;
      }

      if (result.killed) {
        ctx.ui.notify("Pi update timed out. Some updates may have completed. Run /update again.", "error");
        return;
      }

      if (result.code !== 0) {
        const error = result.stderr.trim() || result.stdout.trim() || "Unknown error";
        ctx.ui.notify(
          `Pi update failed: ${error}. Some updates may have completed. Resolve the error, then run /update again.`,
          "error",
        );
        return;
      }

      ctx.ui.notify(
        "Pi and extensions are up to date. Restart Pi to use a new Pi version. Reloading configuration...",
        "info",
      );
      try {
        await ctx.reload();
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        throw new Error(
          `Pi and extensions are up to date, but configuration reload failed: ${message}. Restart Pi.`,
          { cause: error },
        );
      }
    },
  });
}
