import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

/**
 * Claude Code-inspired statusline footer.
 *
 * Line 1: location | ctx: XX% | model · reasoning
 * Line 2: extension statuses | dirty(+~?| -?) | cost/tokens
 *
 * Inspired by: dot-claude/statusline-command.sh
 */

// ANSI color codes (same palette as Claude Code's statusline)
const DIM = "\x1b[2m";
const CYAN = "\x1b[36m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const GREEN = "\x1b[32m";
const MAGENTA = "\x1b[35m";
const RESET = "\x1b[0m";

const SEP = `${DIM}|${RESET}`;

/** Git porcelain status counts */
export interface DirtyState { m: number; a: number; d: number; u: number }

const emptyDirtyState = (): DirtyState => ({ m: 0, a: 0, d: 0, u: 0 });

export function parseDirtyState(output: string): DirtyState {
	const dirty = emptyDirtyState();
	for (const line of output.split(/\r?\n/)) {
		const x = line[0];
		const y = line[1];
		if (!x || !y) continue;
		if (x === "M" || y === "M") dirty.m++;
		if (x === "A") dirty.a++;
		if (x === "D" || y === "D") dirty.d++;
		if (x === "?" && y === "?") dirty.u++;
	}
	return dirty;
}

export function formatTokens(count: number): string {
	if (count < 1000) return String(count);
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

export function sanitizeStatusText(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

function dirtyStatesEqual(a: DirtyState, b: DirtyState): boolean {
	return a.m === b.m && a.a === b.a && a.d === b.d && a.u === b.u;
}

class StatuslineState {
	constructor(private pi: ExtensionAPI) {}

	/** Current working directory */
	cwd = "";
	/** Git dirty counts */
	dirty: DirtyState = emptyDirtyState();
	/** Token/cost accumulators */
	input = 0;
	output = 0;
	cost = 0;
	private dirtyRefreshInFlight = false;
	private generation = 0;
	private requestRender: (() => void) | null = null;

	start(cwd: string, requestRender: () => void): void {
		this.generation++;
		this.cwd = cwd;
		this.dirty = emptyDirtyState();
		this.requestRender = requestRender;
	}

	requestRerender(): void {
		this.requestRender?.();
	}

	async refreshDirty(): Promise<void> {
		if (this.dirtyRefreshInFlight || !this.requestRender) return;
		this.dirtyRefreshInFlight = true;
		const generation = this.generation;
		let nextDirty = emptyDirtyState();

		try {
			const result = await this.pi.exec(
				"git",
				["--no-optional-locks", "-C", this.cwd, "status", "--porcelain=v1"],
				{ timeout: 2000 },
			);
			if (result.code === 0) nextDirty = parseDirtyState(result.stdout);
		} catch {
			// Git is unavailable or the working directory is not a repository.
		} finally {
			this.dirtyRefreshInFlight = false;
		}

		if (generation !== this.generation || !this.requestRender) return;
		if (!dirtyStatesEqual(this.dirty, nextDirty)) {
			this.dirty = nextDirty;
			this.requestRender();
		}
	}

	refreshUsage(ctx: ExtensionContext): void {
		this.input = 0;
		this.output = 0;
		this.cost = 0;
		for (const e of ctx.sessionManager.getBranch()) {
			if (e.type === "message" && e.message.role === "assistant") {
				const message = e.message as AssistantMessage;
				this.input += message.usage.input || 0;
				this.output += message.usage.output || 0;
				this.cost += message.usage.cost.total || 0;
			}
		}
	}

	dispose(): void {
		this.generation++;
		this.requestRender = null;
	}
}

export default function (pi: ExtensionAPI) {
	const state = new StatuslineState(pi);

	pi.on("model_select", () => state.requestRerender());
	pi.on("thinking_level_select", () => state.requestRerender());

	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			state.start(ctx.cwd, () => tui.requestRender());

			const refreshDirty = () => void state.refreshDirty();
			const unsubBranch = footerData.onBranchChange(() => tui.requestRender());
			const interval = setInterval(refreshDirty, 3000);
			refreshDirty();

			return {
				dispose() {
					unsubBranch();
					clearInterval(interval);
					state.dispose();
				},
				invalidate() {},
				render(width: number): string[] {
					state.refreshUsage(ctx);

					const shortCwd = state.cwd.startsWith(process.env.HOME || "")
						? state.cwd.replace(process.env.HOME || "", "~")
						: state.cwd;

					const basename = shortCwd.split("/").pop() || shortCwd;

					// --- Line 1: location | ctx: XX% | model · reasoning ---

					const branch = footerData.getGitBranch();
					const location = branch
						? `${DIM}${shortCwd}${RESET}:${CYAN}${branch}${RESET}`
						: basename;

					let ctxStr: string;
					const usage = ctx.getContextUsage();
					if (usage && usage.percent != null) {
						const pct = Math.round(usage.percent);
						const color = pct >= 75 ? RED : pct >= 50 ? YELLOW : "";
						ctxStr = `${color}ctx: ${pct}%${RESET}`;
					} else {
						ctxStr = `${DIM}ctx: --${RESET}`;
					}

					const modelName = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no model";
					let modelStr = theme.fg("dim", modelName);
					if (ctx.model?.reasoning) {
						const level = pi.getThinkingLevel();
						modelStr += ` ${theme.fg("dim", "·")} ${theme.getThinkingBorderColor(level)(level)}`;
					}

					const sepW = visibleWidth(SEP);
					const totalW = visibleWidth(location) + sepW + visibleWidth(ctxStr) + sepW + visibleWidth(modelStr) + 4;
					const pad = " ".repeat(Math.max(1, width - totalW));
					const line1 = truncateToWidth(location + pad + SEP + " " + ctxStr + " " + SEP + " " + modelStr, width);

					// --- Line 2: extension statuses | dirty | cost/tokens ---

					const statuses = [...footerData.getExtensionStatuses().values()]
						.map(sanitizeStatusText)
						.filter((status) => visibleWidth(status) > 0)
						.join(" ");

					const dirtyParts: string[] = [];
					if (state.dirty.m) dirtyParts.push(`${YELLOW}${state.dirty.m}~${RESET}`);
					if (state.dirty.a) dirtyParts.push(`${GREEN}${state.dirty.a}+${RESET}`);
					if (state.dirty.d) dirtyParts.push(`${RED}${state.dirty.d}-${RESET}`);
					if (state.dirty.u) dirtyParts.push(`${MAGENTA}${state.dirty.u}?${RESET}`);

					const line2Parts = statuses ? [statuses] : [];
					if (dirtyParts.length > 0) line2Parts.push(dirtyParts.join(" "));

					if (state.cost > 0 || state.input > 0 || state.output > 0) {
						line2Parts.push(
							`${DIM}$${state.cost.toFixed(3)}${RESET} ${DIM}${formatTokens(state.input)}↓/${formatTokens(state.output)}↑${RESET}`,
						);
					}

					const line2 = truncateToWidth(line2Parts.join(` ${SEP} `), width);
					return visibleWidth(line2) > 0 ? [line1, line2] : [line1];
				},
			};
		});
	});
}
