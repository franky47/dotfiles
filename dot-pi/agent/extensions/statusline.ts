import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

/**
 * Claude Code-inspired statusline footer.
 *
 * Line 1: location | ctx: XX% | model
 * Line 2: dirty(+~?| -?) | cost/tokens
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
interface DirtyState { m: number; a: number; d: number; u: number }

class StatuslineState {
	constructor(private pi: ExtensionAPI) {}

	/** Current working directory */
	cwd = "";
	/** Current git branch */
	branch: string | null = null;
	/** Git dirty counts */
	dirty: DirtyState = { m: 0, a: 0, d: 0, u: 0 };
	/** Token/cost accumulators */
	input = 0;
	output = 0;
	cost = 0;
	private dirtyTimer: ReturnType<typeof setTimeout> | null = null;
	private requestRender: (() => void) | null = null;

	setRequestRender(fn: () => void): void {
		this.requestRender = fn;
	}

	refreshDirty(): void {
		if (this.dirtyTimer || !this.requestRender) return;
		this.dirtyTimer = setTimeout(async () => {
			this.dirtyTimer = null;
			try {
				const { stdout } = await this.pi.exec("bash", [
					"-c",
					`git -C "${this.cwd}" status --porcelain 2>/dev/null | awk '{ x=substr($0,1,1); y=substr($0,2,1); if(x=="M"||y=="M") m++; if(x=="A") a++; if(x=="D"||y=="D") d++; if(x=="?"&&y=="?") u++ } END { printf "%d %d %d %d", m, a, d, u }'`,
				], { timeout: 2000 });
				const parts = stdout.trim().split(/\s+/).map(Number);
				if (parts.length === 4 && !parts.some(isNaN)) {
					this.dirty = { m: parts[0], a: parts[1], d: parts[2], u: parts[3] };
				}
			} catch { /* not a git repo */ }
			this.requestRender?.();
		}, 500);
	}

	refreshUsage(ctx: { sessionManager: { getBranch(): any[] } }): void {
		this.input = 0;
		this.output = 0;
		this.cost = 0;
		for (const e of ctx.sessionManager.getBranch()) {
			if (e.type === "message" && (e.message as any).role === "assistant") {
				const m = (e.message as any).usage;
				if (m) {
					this.input += m.input || 0;
					this.output += m.output || 0;
					this.cost += m.cost?.total || 0;
				}
			}
		}
	}

	invalidate(): void {
		if (this.dirtyTimer) { clearTimeout(this.dirtyTimer); this.dirtyTimer = null; }
		this.requestRender = null;
	}
}

export default function (pi: ExtensionAPI) {
	const state = new StatuslineState(pi);

	pi.on("session_start", async (_event, ctx) => {
		state.cwd = ctx.cwd;

		const { stdout } = await pi.exec("bash", ["-c", `git -C "${state.cwd}" rev-parse --abbrev-ref HEAD 2>/dev/null`], { timeout: 1000 });
		state.branch = stdout.trim() || null;

		ctx.ui.setFooter((tui, theme, footerData) => {
			state.setRequestRender(() => tui.requestRender());

			const refreshState = () => {
				state.refreshUsage(ctx);
				state.refreshDirty();
			};

			const unsubBranch = footerData.onBranchChange(() => {
				pi.exec("bash", ["-c", `git -C "${state.cwd}" rev-parse --abbrev-ref HEAD 2>/dev/null`], { timeout: 1000 })
					.then((r) => { state.branch = r.stdout.trim() || null; })
					.catch(() => {});
				refreshState();
			});

			const interval = setInterval(refreshState, 3000);

			return {
				dispose() {
					unsubBranch();
					clearInterval(interval);
					state.invalidate();
				},
				invalidate() { state.invalidate(); },
				render(width: number): string[] {
					refreshState();

					// --- Helpers ---

					const fmt = (n: number) => (n < 1000 ? String(n) : (n / 1000).toFixed(1) + "k");

					const shortCwd = state.cwd.startsWith(process.env.HOME || "")
						? state.cwd.replace(process.env.HOME || "", "~")
						: state.cwd;

					const basename = shortCwd.split("/").pop() || shortCwd;

					// --- Line 1: location | ctx: XX% | model ---

					let location: string;
					if (state.branch) {
						location = `${DIM}${shortCwd}${RESET}:${CYAN}${state.branch}${RESET}`;
					} else {
						location = basename;
					}

					// Context percentage — use theme for dim styling
					let ctxStr: string;
					const usage = ctx.getContextUsage();
					if (usage && usage.percent != null) {
						const pct = Math.round(usage.percent);
						const color = pct >= 75 ? RED : pct >= 50 ? YELLOW : "";
						ctxStr = `${color}ctx: ${pct}%${RESET}`;
					} else {
						ctxStr = `${DIM}ctx: --${RESET}`;
					}

					// Model name — use theme dim styling
					const modelName = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no model";
					const modelStr = theme.fg("dim", modelName);

					// Build line 1 with centered padding
					const sepW = visibleWidth(SEP);
					const totalW = visibleWidth(location) + sepW + visibleWidth(ctxStr) + sepW + visibleWidth(modelStr) + 4;
					const pad = " ".repeat(Math.max(1, width - totalW));
					const line1 = truncateToWidth(location + pad + SEP + " " + ctxStr + " " + SEP + " " + modelStr, width);

					// --- Line 2: dirty | cost/tokens (no location prefix) ---

					// Git dirty state
					const dirtyParts: string[] = [];
					if (state.dirty.m) dirtyParts.push(`${YELLOW}${state.dirty.m}~${RESET}`);
					if (state.dirty.a) dirtyParts.push(`${GREEN}${state.dirty.a}+${RESET}`);
					if (state.dirty.d) dirtyParts.push(`${RED}${state.dirty.d}-${RESET}`);
					if (state.dirty.u) dirtyParts.push(`${MAGENTA}${state.dirty.u}?${RESET}`);
					const dirty = dirtyParts.length > 0 ? SEP + " " + dirtyParts.join(" ") : "";

					// Cost/tokens
					let costInfo = "";
					if (state.cost > 0 || state.input > 0) {
						costInfo = SEP + ` ${DIM}$${state.cost.toFixed(3)}${RESET} ${DIM}${fmt(state.input)}k↓/${fmt(state.output)}k↑${RESET}`;
					}

					const line2 = truncateToWidth(dirty + costInfo, width);

					return [line1, line2];
				},
			};
		});
	});
}
