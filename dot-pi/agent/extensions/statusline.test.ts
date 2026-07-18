import assert from "node:assert/strict";
import { describe, it } from "node:test";
import statusline, { formatTokens, parseDirtyState, sanitizeStatusText } from "./statusline.ts";

describe("parseDirtyState", () => {
	it("counts staged and unstaged porcelain states", () => {
		assert.deepEqual(
			parseDirtyState([
				" M unstaged",
				"M  staged",
				"A  added",
				"D  deleted",
				"?? untracked",
				"MM both",
				"AD added-and-deleted",
			].join("\n")),
			{ m: 3, a: 2, d: 2, u: 1 },
		);
	});

	it("ignores empty and malformed lines", () => {
		assert.deepEqual(parseDirtyState("\nX\n"), { m: 0, a: 0, d: 0, u: 0 });
	});
});

describe("formatTokens", () => {
	it("uses one unit suffix", () => {
		assert.equal(formatTokens(500), "500");
		assert.equal(formatTokens(1234), "1.2k");
		assert.equal(formatTokens(12_345), "12k");
		assert.equal(formatTokens(1_234_567), "1.2M");
	});
});

describe("sanitizeStatusText", () => {
	it("keeps statuses on one compact line", () => {
		assert.equal(sanitizeStatusText("  private\n\tmode  "), "private mode");
	});
});

describe("statusline footer", () => {
	function renderFooter(options: {
		model?: { provider: string; id: string; reasoning: boolean };
		thinkingLevel?: "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
		statuses?: ReadonlyMap<string, string>;
	} = {}) {
		const handlers = new Map<string, (...args: any[]) => any>();
		let footerFactory: ((tui: any, theme: any, footerData: any) => any) | undefined;
		let borderLevel: string | undefined;

		const pi = {
			on(event: string, handler: (...args: any[]) => any) {
				handlers.set(event, handler);
			},
			getThinkingLevel: () => options.thinkingLevel ?? "high",
			exec: async () => ({ stdout: "", stderr: "", code: 0, killed: false }),
		};

		statusline(pi as any);
		const ctx = {
			cwd: "/tmp/project",
			model: options.model,
			getContextUsage: () => null,
			sessionManager: { getBranch: () => [] },
			ui: {
				setFooter(factory: typeof footerFactory) {
					footerFactory = factory;
				},
			},
		};
		handlers.get("session_start")?.({}, ctx);
		assert.ok(footerFactory);

		const component = footerFactory(
			{ requestRender() {} },
			{
				fg: (color: string, text: string) => `[${color}:${text}]`,
				getThinkingBorderColor: (level: string) => {
					borderLevel = level;
					return (text: string) => `[bar:${text}]`;
				},
			},
			{
				getGitBranch: () => null,
				getExtensionStatuses: () => options.statuses ?? new Map(),
				onBranchChange: () => () => {},
			},
		);

		const lines = component.render(400);
		component.dispose();
		return { lines, borderLevel };
	}

	it("omits an empty optional row", () => {
		const { lines } = renderFooter({ statuses: new Map([["blank", "\n\t"]]) });
		assert.equal(lines.length, 1);
	});

	it("shows reasoning after a middle dot using the prompt-border color", () => {
		const { lines, borderLevel } = renderFooter({
			model: { provider: "test", id: "reasoner", reasoning: true },
			thinkingLevel: "high",
		});
		assert.equal(borderLevel, "high");
		assert.match(lines[0], /\[dim:test\/reasoner\] \[dim:·\] \[bar:high\]/);
	});

	it("omits reasoning for incompatible models", () => {
		const { lines, borderLevel } = renderFooter({
			model: { provider: "test", id: "plain", reasoning: false },
		});
		assert.equal(borderLevel, undefined);
		assert.doesNotMatch(lines[0], /\[bar:/);
	});
});
