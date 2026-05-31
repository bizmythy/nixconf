import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
	const formatTool = defineTool({
		name: "format",
		label: "Format",
		description:
			"Run the repository formatter with nix fmt. Optionally provide paths to format only those files/directories; omit paths to format the full repo.",
		promptSnippet: "Run nix fmt for the full repo or selected paths",
		promptGuidelines: [
			"Use format after editing files when formatting is requested or required by repository instructions.",
			"Call format with specific paths when only a small set of files changed; omit paths only when the user asks to format the whole repository.",
		],
		parameters: Type.Object({
			paths: Type.Optional(
				Type.Array(Type.String(), {
					description:
						"Optional file or directory paths to pass to nix fmt after --. Omit or pass an empty array to format the full repository.",
				}),
			),
		}),

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const root = process.env.NIXCONF_ROOT ?? ctx.cwd;

			const paths = (params.paths ?? [])
				.map((path) => path.trim())
				.filter((path) => path.length > 0)
				.map((path) => (path.startsWith("@") ? path.slice(1) : path));

			const args = paths.length > 0 ? ["fmt", "--", ...paths] : ["fmt"];
			onUpdate?.({
				content: [
					{
						type: "text",
						text: `Running nix ${args.join(" ")} from ${root}...`,
					},
				],
				details: { cwd: root, command: "nix", args },
			});

			const result = await pi.exec("nix", args, { cwd: root, signal });
			const output = [result.stdout, result.stderr]
				.filter((text) => text.trim().length > 0)
				.join("\n");

			if (result.code !== 0) {
				throw new Error(
					`nix ${args.join(" ")} failed with exit code ${result.code}.\n${output}`.trim(),
				);
			}

			return {
				content: [
					{
						type: "text",
						text:
							paths.length > 0
								? `Formatted ${paths.length} path(s).`
								: "Formatted the full repository.",
					},
				],
				details: {
					cwd: root,
					command: "nix",
					args,
					stdout: result.stdout,
					stderr: result.stderr,
				},
			};
		},
	});

	pi.registerTool(formatTool);
}
