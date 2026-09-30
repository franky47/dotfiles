import assert from "node:assert/strict";
import { describe, it } from "node:test";

import updateExtension from "../extensions/update.ts";

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

async function runUpdate(execOutcome: ExecResult | Error | string, reloadError?: Error) {
  const commands = new Map<string, Command>();
  const execCalls: Array<{ command: string; args: string[]; options: object }> = [];
  const notifications: Array<{ message: string; level: string }> = [];
  let reloadCount = 0;
  let stale = false;

  const pi = {
    registerCommand(name: string, command: Command) {
      commands.set(name, command);
    },
    async exec(command: string, args: string[], options: object) {
      assert.equal(stale, false, "Cannot use pi after reload");
      execCalls.push({ command, args, options });
      if (execOutcome instanceof Error || typeof execOutcome === "string") throw execOutcome;
      return execOutcome;
    },
  };

  updateExtension(pi as never);

  assert.deepEqual([...commands.keys()], ["update"]);
  const command = commands.get("update");
  assert.ok(command);

  await command.handler("", {
    ui: {
      notify(message, level) {
        assert.equal(stale, false, "Cannot use ctx after reload");
        notifications.push({ message, level });
      },
    },
    async reload() {
      assert.equal(stale, false, "Cannot reload a stale ctx");
      reloadCount += 1;
      stale = true;
      if (reloadError) throw reloadError;
    },
  });

  return { execCalls, notifications, reloadCount };
}

function execResult(overrides: Partial<ExecResult> = {}): ExecResult {
  return { code: 0, stdout: "Updated packages\nUpdated pi from 1.0.0 to 1.1.0", stderr: "", killed: false, ...overrides };
}

describe("update extension", () => {
  it("updates Pi and packages, notifies before reload, and never reuses stale context", async () => {
    const result = await runUpdate(execResult());

    assert.deepEqual(result.execCalls, [
      { command: "pi", args: ["update", "--all"], options: { timeout: 240_000 } },
    ]);
    assert.equal(result.reloadCount, 1);
    assert.deepEqual(result.notifications, [
      { message: "Updating Pi and extensions...", level: "info" },
      { message: "Pi and extensions are up to date. Restart Pi to use a new Pi version. Reloading configuration...", level: "info" },
    ]);
  });

  it("reloads updated extensions even when Pi is already current", async () => {
    const result = await runUpdate(execResult({ stdout: "Updated packages\npi is already up to date (v1.1.0)" }));

    assert.equal(result.reloadCount, 1);
    assert.equal(result.notifications.at(-1)?.level, "info");
  });

  for (const output of [
    { stderr: "registry unavailable" },
    { stdout: "registry unavailable" },
    { stdout: "Updated packages", stderr: "Pi self-update failed" },
    { stdout: "pi is already up to date", stderr: "extension update failed" },
    { stdout: "", stderr: "" },
  ]) {
    it(`reports a nonzero exit without claiming success: ${JSON.stringify(output)}`, async () => {
      const result = await runUpdate(execResult({ stdout: "", code: 1, ...output }));

      assert.equal(result.reloadCount, 0);
      assert.deepEqual(result.notifications.at(-1), {
        message: `Pi update failed: ${output.stderr || output.stdout || "Unknown error"}. Some updates may have completed. Resolve the error, then run /update again.`,
        level: "error",
      });
    });
  }

  it("reports timeouts even with exit code zero and up-to-date output", async () => {
    const result = await runUpdate(execResult({ killed: true, stdout: "pi is already up to date" }));

    assert.equal(result.reloadCount, 0);
    assert.deepEqual(result.notifications.at(-1), {
      message: "Pi update timed out. Some updates may have completed. Run /update again.",
      level: "error",
    });
  });

  for (const error of [new Error("spawn failed"), "spawn failed"]) {
    it(`reports execution errors (${typeof error}) without reloading`, async () => {
      const result = await runUpdate(error);

      assert.equal(result.reloadCount, 0);
      assert.deepEqual(result.notifications.at(-1), {
        message: "Pi update failed: spawn failed",
        level: "error",
      });
    });
  }

  it("reports reload errors without using stale context or marking the update as failed", async () => {
    const cause = new Error("reload failed");
    await assert.rejects(runUpdate(execResult(), cause), {
      message: "Pi and extensions are up to date, but configuration reload failed: reload failed. Restart Pi.",
      cause,
    });
  });
});
