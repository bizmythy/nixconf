import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

type SearchMode = "options" | "programs";

type ManixEntry = {
	kind: string;
	source: string;
	name: string;
	documentation: unknown | null;
};

type ManixJson = {
	entries?: ManixEntry[];
	key_only_entries?: ManixEntry[];
};

type Truncation = {
	content: string;
	truncated: boolean;
	truncatedBy: "lines" | "bytes" | null;
	totalLines: number;
	totalBytes: number;
	outputLines: number;
	outputBytes: number;
	firstLineExceedsLimit: boolean;
	maxLines: number;
	maxBytes: number;
};

const DEFAULT_MAX_LINES = 2000;
const DEFAULT_MAX_BYTES = 50 * 1024;

const PARAMS = Type.Object({
	mode: Type.Union([Type.Literal("options"), Type.Literal("programs")], {
		description:
			"What to query for. Use 'options' to return manix JSON's entries key; use 'programs' to return key_only_entries.",
	}),
	query: Type.String({
		description:
			"Query string to pass to manix, for example 'services.openssh.enable', 'programs.git.enable', or 'ripgrep'.",
	}),
	strict: Type.Optional(
		Type.Boolean({
			description:
				"Pass --strict to manix. This is often useful for program/package searches to avoid very broad matches.",
			default: false,
		}),
	),
	maxResults: Type.Optional(
		Type.Integer({
			description:
				"Maximum number of selected results to include in the inline JSON. Defaults to 100 to avoid flooding the agent context. When more results exist, the complete selected JSON is saved to a temp file.",
			minimum: 1,
			maximum: 1000,
			default: 100,
		}),
	),
});

function runManix(args: string[], signal?: AbortSignal): Promise<string> {
	return new Promise((resolve, reject) => {
		const child = execFile(
			"manix",
			args,
			{
				encoding: "utf8",
				maxBuffer: 64 * 1024 * 1024,
				signal,
			},
			(error, stdout, stderr) => {
				if (error) {
					reject(
						new Error(
							[
								`manix ${args.map((arg) => JSON.stringify(arg)).join(" ")} failed`,
								stderr.trim(),
								error.message,
							]
								.filter(Boolean)
								.join("\n"),
						),
					);
					return;
				}

				resolve(stdout);
			},
		);

		signal?.addEventListener(
			"abort",
			() => {
				child.kill("SIGTERM");
			},
			{ once: true },
		);
	});
}

function splitLinesForCounting(content: string): string[] {
	if (content.length === 0) {
		return [];
	}

	const lines = content.split("\n");
	if (content.endsWith("\n")) {
		lines.pop();
	}
	return lines;
}

function formatSize(bytes: number): string {
	if (bytes < 1024) {
		return `${bytes}B`;
	}
	if (bytes < 1024 * 1024) {
		return `${(bytes / 1024).toFixed(1)}KB`;
	}
	return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
}

function truncateHead(
	content: string,
	maxLines = DEFAULT_MAX_LINES,
	maxBytes = DEFAULT_MAX_BYTES,
): Truncation {
	const totalBytes = Buffer.byteLength(content, "utf-8");
	const lines = splitLinesForCounting(content);
	const totalLines = lines.length;

	if (totalLines <= maxLines && totalBytes <= maxBytes) {
		return {
			content,
			truncated: false,
			truncatedBy: null,
			totalLines,
			totalBytes,
			outputLines: totalLines,
			outputBytes: totalBytes,
			firstLineExceedsLimit: false,
			maxLines,
			maxBytes,
		};
	}

	const firstLineBytes = Buffer.byteLength(lines[0] ?? "", "utf-8");
	if (firstLineBytes > maxBytes) {
		return {
			content: "",
			truncated: true,
			truncatedBy: "bytes",
			totalLines,
			totalBytes,
			outputLines: 0,
			outputBytes: 0,
			firstLineExceedsLimit: true,
			maxLines,
			maxBytes,
		};
	}

	const outputLines: string[] = [];
	let outputBytes = 0;
	let truncatedBy: "lines" | "bytes" = "lines";

	for (let i = 0; i < lines.length && i < maxLines; i++) {
		const line = lines[i];
		const lineBytes = Buffer.byteLength(line, "utf-8") + (i > 0 ? 1 : 0);
		if (outputBytes + lineBytes > maxBytes) {
			truncatedBy = "bytes";
			break;
		}
		outputLines.push(line);
		outputBytes += lineBytes;
	}

	const output = outputLines.join("\n");
	return {
		content: output,
		truncated: true,
		truncatedBy,
		totalLines,
		totalBytes,
		outputLines: outputLines.length,
		outputBytes: Buffer.byteLength(output, "utf-8"),
		firstLineExceedsLimit: false,
		maxLines,
		maxBytes,
	};
}

async function writeTempJson(prefix: string, content: string): Promise<string> {
	const id = randomBytes(8).toString("hex");
	const path = join(tmpdir(), `${prefix}-${id}.json`);
	await writeFile(path, content, "utf8");
	return path;
}

function buildArgs(mode: SearchMode, query: string, strict: boolean): string[] {
	const args = ["--json"];

	if (strict) {
		args.push("--strict");
	}

	if (mode === "options") {
		args.push("--source", "hm-options,nixos-options,nd-options");
	} else {
		args.push("--source", "nixpkgs-tree");
	}

	args.push(query);
	return args;
}

export default function nixSearchExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "nix_search",
		label: "Nix Search",
		description:
			"Search Nix options or Nixpkgs programs/packages using manix --json and return the selected JSON result key.",
		promptSnippet:
			"Search Nix options or Nixpkgs programs/packages using manix --json",
		promptGuidelines: [
			"Use nix_search instead of ad-hoc manix shell commands when looking up NixOS/Home Manager/nix-darwin options or Nixpkgs package/program attribute names.",
			"When calling nix_search, set mode to 'options' for module options and 'programs' for Nixpkgs packages/programs.",
			"For nix_search program queries, consider strict=true for exact package names such as 'ripgrep' or 'firefox'.",
		],
		parameters: PARAMS,
		async execute(_toolCallId, params, signal) {
			const mode = params.mode as SearchMode;
			const query = params.query.trim();
			const maxResults = params.maxResults ?? 100;
			const strict = params.strict ?? false;

			if (!query) {
				throw new Error("nix_search query must not be empty");
			}

			const args = buildArgs(mode, query, strict);
			const stdout = await runManix(args, signal);

			let parsed: ManixJson;
			try {
				parsed = JSON.parse(stdout) as ManixJson;
			} catch (error) {
				throw new Error(
					`manix produced invalid JSON: ${error instanceof Error ? error.message : String(error)}`,
				);
			}

			const selectedKey = mode === "options" ? "entries" : "key_only_entries";
			const allResults = parsed[selectedKey] ?? [];
			const fullResponse = {
				query,
				mode,
				selectedKey,
				count: allResults.length,
				[selectedKey]: allResults,
			};

			let results = allResults.slice(0, maxResults);
			let inlineText = "";
			let truncation: Truncation;
			let contentLimitReducedResults = false;

			while (true) {
				const inlineResponse = {
					query,
					mode,
					selectedKey,
					count: allResults.length,
					resultLimitReached:
						allResults.length > results.length ? results.length : undefined,
					[selectedKey]: results,
				};
				inlineText = JSON.stringify(inlineResponse, null, 2);
				truncation = truncateHead(inlineText);

				if (!truncation.truncated || results.length === 0) {
					break;
				}

				contentLimitReducedResults = true;
				results = results.slice(0, Math.floor(results.length / 2));
			}

			const resultLimitReached = allResults.length > results.length;
			const fullText = JSON.stringify(fullResponse, null, 2);
			let fullOutputPath: string | undefined;

			if (resultLimitReached || truncation.truncated) {
				fullOutputPath = await writeTempJson("pi-nix-search", fullText);
			}

			let text = truncation.truncated ? truncation.content : inlineText;
			const notices: string[] = [];
			if (resultLimitReached) {
				notices.push(
					`showing ${results.length} of ${allResults.length} results`,
				);
			}
			if (contentLimitReducedResults) {
				notices.push(
					`inline results reduced to fit ${formatSize(DEFAULT_MAX_BYTES)} limit`,
				);
			}
			if (truncation.truncated) {
				if (truncation.firstLineExceedsLimit) {
					notices.push(
						`first JSON line exceeds ${formatSize(DEFAULT_MAX_BYTES)} limit`,
					);
				} else if (truncation.truncatedBy === "lines") {
					notices.push(
						`showing ${truncation.outputLines} of ${truncation.totalLines} lines`,
					);
				} else {
					notices.push(`${formatSize(DEFAULT_MAX_BYTES)} limit reached`);
				}
			}
			if (fullOutputPath) {
				notices.push(`full selected JSON: ${fullOutputPath}`);
			}
			if (notices.length > 0) {
				text += `\n\n[Truncated: ${notices.join("; ")}]`;
			}

			return {
				content: [{ type: "text", text }],
				details: {
					query,
					mode,
					selectedKey,
					count: allResults.length,
					resultLimitReached: resultLimitReached ? results.length : undefined,
					contentLimitReducedResults,
					truncation: truncation.truncated ? truncation : undefined,
					fullOutputPath,
				},
			};
		},
	});
}
