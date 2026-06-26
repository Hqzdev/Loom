type DiagnosticFields = Record<string, boolean | number | string | null | undefined>;

export function logInfo(event: string, fields: DiagnosticFields = {}) {
  emit("info", event, fields);
}

export function logWarn(event: string, fields: DiagnosticFields = {}) {
  emit("warn", event, fields);
}

export function logError(event: string, error: unknown, fields: DiagnosticFields = {}) {
  emit("error", event, { ...fields, ...errorFields(error) });
}

function emit(level: "error" | "info" | "warn", event: string, fields: DiagnosticFields) {
  console[level](JSON.stringify({
    level,
    event,
    timestamp: new Date().toISOString(),
    ...fields,
  }));
}

function errorFields(error: unknown): DiagnosticFields {
  if (error instanceof Error) {
    return {
      errorName: error.name,
      errorMessage: error.message,
    };
  }

  return {
    errorMessage: String(error),
  };
}
