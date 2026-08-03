// ∅ 2026 lil org

"use strict";

function normalizedRPCResponse(response, correlationId) {
    if (!response ||
        typeof response !== "object" ||
        Array.isArray(response) ||
        typeof response.id !== "number" ||
        !Number.isFinite(response.id) ||
        !("result" in response || "error" in response)) {
        return undefined;
    }

    if (typeof correlationId !== "undefined" &&
        (typeof correlationId !== "number" ||
            !Number.isFinite(correlationId) ||
            response.id !== correlationId)) {
        return undefined;
    }

    return response;
}

export { normalizedRPCResponse };
