import assert from "node:assert/strict";
import { describe, it } from "node:test";

import updateExtension from "./update.ts";

type Command = {
  handler: (args: string, ctx: CommandContext) => Promise<void>;
};

type CommandContext = {
  ui: { notify: (message: string, level: string) => void };
  reload: () => Promise<void>;
};

type ExecResult = {
  code: number;
  stdout: string;
  stderr: string;
  killed: boolean;
};

async function runUpdateExtensions(execOutcome: ExecResult | Error, reloadError?: Error) {
  const commands = new Map<string, Command>();
  const execCalls: Array<{ command: string; args: string[]; options: object }> = [];
  const notifications: Array<{ message: string; level: string }> = [];
  let reloadCount = 0;

  const pi = {
    registerCommand(name: string, command: Command) {
      commands.set(name, command);
    },
    async exec(command: string, args: string[], options: object) {
      execCalls.push({ command, args, options });
      if (execOutcome instanceof Error) throw execOutcome;
      return execOutcome;
    },
  };

  updateExtension(pi as never);

  const command = commands.get("update-extensions");
  assert.ok(command);

  await command.handler("", {
    ui: {
      notify(message, level) {
        notifications.push({ message, level });
      },
    },
    async reload() {
      reloadCount += 1;
      if (reloadError) throw reloadError;
    },
  });

  return { execCalls, notifications, reloadCount };
}

describe("update extension", () => {
  it("registers /update-extensions to update installed extensions and reload", async () => {
    const result = await runUpdateExtensions({
      code: 0,
      stdout: "Extensions updated",
      stderr: "",
      killed: false,
    });

    assert.deepEqual(result.execCalls, [
      {
        command: "pi",
        args: ["update", "--extensions"],
        options: { timeout: 120_000 },
      },
    ]);
    assert.deepEqual(result.notifications, [
      { message: "Updating pi extensions...", level: "info" },
      { message: "Pi extensions updated successfully.", level: "info" },
      { message: "Reloading configuration...", level: "info" },
    ]);
    assert.equal(result.reloadCount, 1);
  });

  it("reports update failures without reloading", async () => {
    const result = await runUpdateExtensions({
      code: 1,
      stdout: "",
      stderr: "registry unavailable",
      killed: false,
    });

    assert.deepEqual(result.notifications, [
      { message: "Updating pi extensions...", level: "info" },
      { message: "pi extension update failed: registry unavailable", level: "error" },
    ]);
    assert.equal(result.reloadCount, 0);
  });

  it("reports timeouts without reloading", async () => {
    const result = await runUpdateExtensions({
      code: 0,
      stdout: "",
      stderr: "",
      killed: true,
    });

    assert.deepEqual(result.notifications, [
      { message: "Updating pi extensions...", level: "info" },
      { message: "pi extension update timed out.", level: "error" },
    ]);
    assert.equal(result.reloadCount, 0);
  });

  it("reports execution errors without reloading", async () => {
    const result = await runUpdateExtensions(new Error("spawn failed"));

    assert.deepEqual(result.notifications, [
      { message: "Updating pi extensions...", level: "info" },
      { message: "pi extension update failed: spawn failed", level: "error" },
    ]);
    assert.equal(result.reloadCount, 0);
  });

  it("reports reload errors without marking the update as failed", async () => {
    const result = await runUpdateExtensions(
      { code: 0, stdout: "Extensions updated", stderr: "", killed: false },
      new Error("reload failed"),
    );

    assert.deepEqual(result.notifications, [
      { message: "Updating pi extensions...", level: "info" },
      { message: "Pi extensions updated successfully.", level: "info" },
      { message: "Reloading configuration...", level: "info" },
      { message: "pi configuration reload failed: reload failed", level: "error" },
    ]);
    assert.equal(result.reloadCount, 1);
  });
});
