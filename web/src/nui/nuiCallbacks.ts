import type { NuiCallback, NuiCallbackAsync } from "@/type";

let hasWarnedMissingRuntime = false;

const canUseNuiRuntime = () => typeof GetParentResourceName === "function";

const warnMissingRuntimeOnce = () => {
	if (hasWarnedMissingRuntime) return;
	hasWarnedMissingRuntime = true;
	console.warn(
		"NUI runtime not detected (GetParentResourceName is missing). Running in browser/dev mode: NUI callbacks will no-op.",
	);
};

export const nuiCallback = (async <TResponse = unknown>(
	name: string,
	data?: unknown,
) => {
	try {
		if (!canUseNuiRuntime()) {
			if (import.meta.env.DEV) {
				warnMissingRuntimeOnce();
				return null;
			}
			throw new Error("GetParentResourceName is not defined");
		}

		const resp = await fetch(`https://${GetParentResourceName()}/${name}`, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
			},
			body: JSON.stringify(data ?? {}),
		});

		if (!resp.ok) {
			throw new Error(`NUI callback HTTP ${resp.status}: ${name}`);
		}

		// Empty/whitespace bodies would throw `Unexpected end of JSON input`.
		const text = (await resp.text()).trim();
		if (!text) return null;
		try {
			return JSON.parse(text) as TResponse;
		} catch {
			return text as unknown as TResponse;
		}
	} catch (error) {
		console.error("NUI Callback Error:", error);
		return null;
	}
}) satisfies NuiCallback;

export const nuiCallbackAsync = (async <TResponse = unknown>(
	name: string,
	data?: unknown,
) => {
	if (!canUseNuiRuntime() && import.meta.env.DEV) {
		warnMissingRuntimeOnce();
		// No NUI bridge in browser/dev mode: return a placeholder so UI interactions (e.g. ESC close) don't throw.
		return {} as TResponse;
	}

	const result = await nuiCallback<TResponse>(name, data);
	if (result === null || result === undefined) {
		throw new Error(`NUI callback failed: ${name}`);
	}
	return result;
}) satisfies NuiCallbackAsync;
