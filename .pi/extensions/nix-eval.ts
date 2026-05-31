/**
 * Project-local Nix evaluation tool for pi.
 *
 * Provides a small wrapper around `nix eval` so agents can quickly test Nix
 * expressions while working in this flake repository.
 */

import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	formatSize,
	type TruncationResult,
	truncateHead,
	truncateTail,
	withFileMutationQueue,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const OutputFormat = StringEnum(["json", "raw"] as const, {
	description:
		"Output format: json uses `nix eval --json`; raw uses `nix eval --raw` for string-like values.",
	default: "json",
});

const NixEvalParams = Type.Object({
	expression: Type.String({
		description: "Nix expression to evaluate with `nix eval --expr`.",
	}),
	outputFormat: Type.Optional(OutputFormat),
	impure: Type.Optional(
		Type.Boolean({
			description:
				"Pass `--impure`. Useful when evaluating the current dirty/unlocked checkout with builtins.getFlake.",
		}),
	),
	timeoutSeconds: Type.Optional(
		Type.Number({
			description: "Evaluation timeout in seconds (default: 60, max: 600).",
			minimum: 1,
			maximum: 600,
		}),
	),
});

type OutputFormat = "json" | "raw";

interface NixEvalDetails {
	expression: string;
	outputFormat: OutputFormat;
	impure: boolean;
	command: string[];
	validJson?: boolean;
	truncation?: TruncationResult;
	fullOutputPath?: string;
	stderr?: string;
}

function summarizeExpression(expression: unknown): string {
	if (typeof expression !== "string") return "";
	const singleLine = expression.replace(/\s+/g, " ").trim();
	return singleLine.length > 96 ? `${singleLine.slice(0, 93)}...` : singleLine;
}

async function truncateForTool(output: string, details: NixEvalDetails) {
	const truncation = truncateHead(output, {
		maxLines: DEFAULT_MAX_LINES,
		maxBytes: DEFAULT_MAX_BYTES,
	});

	if (!truncation.truncated) return truncation.content;

	const tempDir = await mkdtemp(join(tmpdir(), "pi-nix-eval-"));
	const tempFile = join(tempDir, "output.txt");
	await withFileMutationQueue(tempFile, async () => {
		await writeFile(tempFile, output, "utf8");
	});

	details.truncation = truncation;
	details.fullOutputPath = tempFile;

	return `${truncation.content}\n\n[Output truncated: showing ${truncation.outputLines} of ${truncation.totalLines} lines (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}). Full output saved to: ${tempFile}]`;
}

function formatJsonOutput(stdout: string, details: NixEvalDetails): string {
	const trimmed = stdout.trim();
	try {
		const parsed = JSON.parse(trimmed);
		details.validJson = true;
		return JSON.stringify(parsed, null, 2);
	} catch {
		details.validJson = false;
		return trimmed;
	}
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "nix_eval",
		label: "Nix Eval",
		description: `Evaluate a Nix expression with nix eval. Defaults to \`nix eval --json --expr\`; raw string output is available with outputFormat="raw". Output is truncated to ${DEFAULT_MAX_LINES} lines or ${formatSize(DEFAULT_MAX_BYTES)} (whichever is hit first).`,
		promptSnippet:
			"Evaluate small Nix expressions with `nix eval --json --expr` in this repository.",
		promptGuidelines: [
			"Use nix_eval to test Nix expressions, flake attribute access, and small module snippets instead of ad-hoc shell quoting.",
			"nix_eval defaults to JSON output; set impure=true when evaluating the current dirty/unlocked checkout with builtins.getFlake.",
		],
		parameters: NixEvalParams,

		async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
			const outputFormat = (params.outputFormat ?? "json") as OutputFormat;
			const timeoutSeconds = Math.min(
				Math.max(params.timeoutSeconds ?? 60, 1),
				600,
			);
			const args = [
				"eval",
				"--extra-experimental-features",
				"nix-command flakes",
			];

			if (outputFormat === "json") {
				args.push("--json");
			} else {
				args.push("--raw");
			}

			if (params.impure) args.push("--impure");
			args.push("--expr", params.expression);

			const details: NixEvalDetails = {
				expression: params.expression,
				outputFormat,
				impure: params.impure ?? false,
				command: ["nix", ...args],
			};

			const result = await pi.exec("nix", args, {
				signal,
				timeout: timeoutSeconds * 1000,
			});

			if (result.code !== 0) {
				const stdout = result.stdout?.trim();
				const stderr = result.stderr?.trim();
				const errorOutput = [stdout, stderr].filter(Boolean).join("\n\n");
				const truncated = truncateTail(errorOutput || "nix eval failed", {
					maxLines: 200,
					maxBytes: 12 * 1024,
				}).content;
				throw new Error(
					`nix eval failed with exit code ${result.code}:\n${truncated}`,
				);
			}

			if (result.stderr?.trim()) details.stderr = result.stderr.trim();

			const formatted =
				outputFormat === "json"
					? formatJsonOutput(result.stdout, details)
					: result.stdout.trimEnd();
			const content = await truncateForTool(formatted, details);

			return {
				content: [{ type: "text", text: content }],
				details,
			};
		},

		renderCall(args, theme, _context) {
			let text = theme.fg("toolTitle", theme.bold("nix_eval "));
			text += theme.fg("accent", summarizeExpression(args.expression));
			if (args.impure) text += theme.fg("warning", " --impure");
			if (args.outputFormat === "raw") text += theme.fg("muted", " --raw");
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded, isPartial }, theme, _context) {
			if (isPartial) {
				return new Text(
					theme.fg("warning", "Evaluating Nix expression..."),
					0,
					0,
				);
			}

			const details = result.details as NixEvalDetails | undefined;
			let text = theme.fg("success", "Nix expression evaluated");

			if (details?.truncation?.truncated) {
				text += theme.fg("warning", " (truncated)");
			}

			if (expanded) {
				const content = result.content[0];
				if (content?.type === "text") {
					text += `\n${theme.fg("dim", content.text)}`;
				}
				if (details?.stderr) {
					text += `\n${theme.fg("warning", `stderr: ${details.stderr}`)}`;
				}
				if (details?.fullOutputPath) {
					text += `\n${theme.fg("dim", `Full output: ${details.fullOutputPath}`)}`;
				}
			}

			return new Text(text, 0, 0);
		},
	});
}
