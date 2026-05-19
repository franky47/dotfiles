import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { StringEnum } from "@earendil-works/pi-ai";

// ── .env parser ──────────────────────────────────────────────────────────────

interface EnvVars {
  SEARXNG_URL: string;
}

function loadEnv(): EnvVars {
  const fs = require("node:fs");
  const os = require("node:os");
  const path = require("node:path");

  const envPath = path.join(os.homedir(), ".pi", "agent", ".env");
  try {
    const raw = fs.readFileSync(envPath, "utf8");
    const vars: Record<string, string> = {};
    for (const line of raw.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eqIndex = trimmed.indexOf("=");
      if (eqIndex === -1) continue;
      const key = trimmed.slice(0, eqIndex).trim();
      let value = trimmed.slice(eqIndex + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      vars[key] = value;
    }
    return { SEARXNG_URL: vars.SEARXNG_URL ?? "" };
  } catch {
    return { SEARXNG_URL: "" };
  }
}

// ── Config ───────────────────────────────────────────────────────────────────

const CONFIG = loadEnv();
const SEARXNG_URL = CONFIG.SEARXNG_URL;
const DEFAULT_NUM_RESULTS = 8;
const SEARCH_CATEGORIES = "general,it";
const SEARCH_LANGUAGE = "en";
const FETCH_TIMEOUT_MS = 30_000;
const SNIPPET_MAX_CHARS = 400;

// ── Resolution layer: fetch URL via markdown.new → jina.ai fallback ──────────

interface FetchedResult {
  url: string;
  content: string;
  title?: string;
  error?: string;
}

async function fetchMarkdown(
  url: string,
  signal?: AbortSignal,
): Promise<FetchedResult> {
  // Try markdown.new first
  const markdownNewUrl = `https://markdown.new/${url}`;
  try {
    const response = await fetch(markdownNewUrl, {
      signal,
      headers: { Accept: "text/markdown" },
      redirect: "follow",
    });

    if (response.ok) {
      return { url, content: await response.text() };
    }
  } catch {
    // Fall through to jina.ai
  }

  // Fallback: r.jina.ai
  const jinaUrl = `https://r.jina.ai/${url}`;
  try {
    const response = await fetch(jinaUrl, {
      signal,
      headers: {
        Accept: "text/markdown",
        "X-Return-Format": "markdown",
      },
      redirect: "follow",
    });

    if (response.ok) {
      let content = await response.text();
      // Strip Jina metadata headers
      content = content.replace(/^URL:.*\n?/gm, "");
      const titleMatch = content.match(/^Title: (.*)$/m);
      const title = titleMatch ? titleMatch[1] : undefined;
      if (titleMatch) {
        content = content.replace(/^Title:.*\n?/gm, "");
      }
      return { url, content, title };
    }
  } catch {
    // Fall through to raw fetch
  }

  // Final fallback: raw fetch + cleanup
  try {
    const response = await fetch(url, {
      signal,
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; pi-extension/1.0)",
        Accept: "text/html,application/xhtml+xml",
      },
      redirect: "follow",
    });

    if (response.ok) {
      const html = await response.text();
      const titleMatch = html.match(
        /<title[^>]*>([^<]*)<\/title>/i,
      );
      const title = titleMatch?.[1]?.trim();
      let content = html
        .replace(/<script[\s\S]*?<\/script>/gi, "")
        .replace(/<style[\s\S]*?<\/style>/gi, "")
        .replace(
          /<(script|style|nav|header|footer|aside|button|form)[^>]*>[\s\S]*?<\/\1>/gi,
          "",
        )
        .replace(/<[^>]+>/g, " ")
        .replace(/\s+/g, " ")
        .trim();
      return { url, content, title };
    }
  } catch {
    // All methods failed
  }

  return { url, content: "", error: "Failed to fetch content" };
}

async function fetchHtml(
  url: string,
  signal?: AbortSignal,
): Promise<FetchedResult> {
  try {
    const response = await fetch(url, {
      signal,
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; pi-extension/1.0)",
        Accept: "text/html,application/xhtml+xml",
      },
      redirect: "follow",
    });

    if (response.ok) {
      return { url, content: await response.text() };
    }
  } catch {
    // Return the error result
  }

  return { url, content: "", error: "Failed to fetch content" };
}

// ── SearXNG search ───────────────────────────────────────────────────────────

interface SearXNGResult {
  url: string;
  title: string;
  content: string;
  engine: string;
  engines: string[];
  score: number;
  category: string;
  publishedDate: string | null;
}

interface SearXNGResponse {
  query: string;
  number_of_results: number;
  results: SearXNGResult[];
  answers: string[];
  infoboxes: object[];
  suggestions: string[];
  corrections: string[];
  unresponsive_engines: string[];
}

async function searchSearXNG(
  query: string,
  numResults: number,
  signal?: AbortSignal,
): Promise<SearXNGResponse> {
  if (!SEARXNG_URL) {
    throw new Error(
      "SearXNG URL not configured. Set SEARXNG_URL in ~/.pi/agent/.env",
    );
  }

  const url = new URL(`${SEARXNG_URL}/search`);
  url.searchParams.set("q", query);
  url.searchParams.set("format", "json");
  url.searchParams.set("categories", SEARCH_CATEGORIES);
  url.searchParams.set("language", SEARCH_LANGUAGE);
  url.searchParams.set("pageno", "1");
  url.searchParams.set(
    "number_of_results",
    String(numResults),
  );

  const response = await fetch(url.toString(), {
    signal,
    headers: { Accept: "application/json" },
    redirect: "follow",
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `SearXNG search failed (${response.status}): ${text}`,
    );
  }

  return response.json() as Promise<SearXNGResponse>;
}

// ── Tool: websearch ──────────────────────────────────────────────────────────

async function executeWebSearch(
  _toolCallId: string,
  params: { query: string; numResults?: number },
  _signal: AbortSignal | undefined,
  _onUpdate: ((update: unknown) => void) | undefined,
  ctx: { cwd: string; signal: AbortSignal },
) {
  const numResults = params.numResults ?? DEFAULT_NUM_RESULTS;

  const searchResults = await searchSearXNG(
    params.query,
    numResults,
    ctx.signal ?? undefined,
  );

  if (searchResults.results.length === 0) {
    return {
      content: [
        {
          type: "text",
          text: "No search results found. Please try a different query.",
        },
      ],
      details: { truncated: false },
    };
  }

  const parts: string[] = [];
  for (const r of searchResults.results) {
    let entry = `Source: ${r.url}\n\n`;
    if (r.title) {
      entry += `## ${r.title}\n\n`;
    }
    const snippet = (r.content ?? "").slice(0, SNIPPET_MAX_CHARS);
    if (snippet) {
      entry += snippet;
    }
    parts.push(entry);
  }

  const output = parts.join("\n\n---\n\n");

  return {
    content: [
      {
        type: "text",
        text: output,
      },
    ],
    details: { truncated: false },
  };
}

// ── Tool: webfetch ───────────────────────────────────────────────────────────

async function executeWebFetch(
  _toolCallId: string,
  params: {
    url: string;
    format: "markdown" | "html";
    timeout?: number;
  },
  _signal: AbortSignal | undefined,
  _onUpdate: ((update: unknown) => void) | undefined,
  ctx: { cwd: string; signal: AbortSignal },
) {
  const timeout = Math.min(
    (params.timeout ?? FETCH_TIMEOUT_MS / 1000) * 1000,
    120_000,
  );
  const timeoutController = new AbortController();
  const timeoutId = setTimeout(
    () => timeoutController.abort(),
    timeout,
  );

  try {
    let result: FetchedResult;

    if (params.format === "html") {
      result = await fetchHtml(
        params.url,
        timeoutController.signal,
      );
    } else {
      // markdown format
      result = await fetchMarkdown(
        params.url,
        timeoutController.signal,
      );
    }

    clearTimeout(timeoutId);

    if (result.error || !result.content) {
      return {
        content: [
          {
            type: "text",
            text: `Failed to fetch ${params.url}`,
          },
        ],
        details: { truncated: false },
      };
    }

    const output = `Source: ${params.url}\n\n${result.content}`;

    return {
      content: [{ type: "text", text: output }],
      details: { truncated: false },
    };
  } catch (error) {
    clearTimeout(timeoutId);
    if (error instanceof Error && error.name === "AbortError") {
      throw new Error("Fetch request timed out");
    }
    throw error;
  }
}

// ── Extension entry point ────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "websearch",
    label: "Web Search",
    description:
      "Search the web and return result metadata. Returns title, snippet, and URL for each result. Use webfetch to read full page content from promising URLs.",
    promptSnippet:
      "Search the web and return result metadata",
    promptGuidelines: [
      "Use websearch for web queries requiring up-to-date information, rather than relying on training data.",
      "The current year is 2026. Include the year in queries for recent information.",
      "Use websearch to get result metadata, then webfetch on specific URLs for full content.",
    ],
    parameters: Type.Object({
      query: Type.String({
        description: "Web search query",
      }),
      numResults: Type.Optional(
        Type.Number({
          description:
            "Number of search results to return (default: 8)",
        }),
      ),
    }),
    async execute(
      toolCallId,
      params,
      signal,
      onUpdate,
      ctx,
    ) {
      return executeWebSearch(
        toolCallId,
        params,
        signal,
        onUpdate,
        ctx,
      );
    },
  });

  pi.registerTool({
    name: "webfetch",
    label: "Web Fetch",
    description:
      "Fetch content from a URL and convert to markdown or HTML. Returns the page content in the requested format.",
    promptSnippet:
      "Fetch content from a URL and return markdown or HTML",
    promptGuidelines: [
      "Use webfetch to read a specific URL's content when you have the exact URL.",
      "Default format is markdown — use html only if you need raw HTML structure.",
    ],
    parameters: Type.Object({
      url: Type.String({
        description: "The URL to fetch content from",
      }),
      format: StringEnum(
        ["markdown", "html"] as const,
        {
          description:
            "The format to return content in (markdown or html). Defaults to markdown.",
        },
      ),
      timeout: Type.Optional(
        Type.Number({
          description:
            "Optional timeout in seconds (max 120)",
        }),
      ),
    }),
    async execute(
      toolCallId,
      params,
      signal,
      onUpdate,
      ctx,
    ) {
      return executeWebFetch(
        toolCallId,
        params,
        signal,
        onUpdate,
        ctx,
      );
    },
  });
}
