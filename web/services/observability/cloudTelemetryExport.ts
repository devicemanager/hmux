import { createHmac } from "node:crypto";
import type { CloudTelemetryAuth, CloudTelemetrySpan } from "./cloudTelemetryContract";
import type { StoredCloudDiagnostic } from "./cloudTelemetryRepository";

/** The keyed account hash shared by exported diagnostics and the ingest route span. */
export function cloudTelemetryAccountKey(identityKey: string, userId: string): string {
  return createHmac("sha256", identityKey).update(userId).digest("hex");
}

export type CloudAxiomConfiguration = {
  readonly origin: string;
  readonly token: string;
  readonly identityKey: string;
  readonly tracesDataset: string;
  readonly errorsDataset: string;
  readonly environment: string;
  readonly revision: string;
  readonly tag?: string;
  readonly sourceSha256?: string;
};

export function cloudAxiomConfiguration(env = process.env): CloudAxiomConfiguration | null {
  const token = env.HMUX_CLOUD_AXIOM_TOKEN?.trim();
  const identityKey = env.HMUX_CLOUD_TELEMETRY_ID_KEY?.trim();
  if (!token || !identityKey || identityKey.length < 32) return null;
  const origin = trustedAxiomOrigin(env.HMUX_CLOUD_AXIOM_ORIGIN);
  if (!origin) return null;
  const production = env.VERCEL_ENV === "production";
  const development = isDevelopmentBuild(env);
  return {
    origin, token, identityKey,
    tracesDataset: telemetryDataset(development, production, false),
    errorsDataset: telemetryDataset(development, production, true),
    environment: production ? "production" : env.VERCEL_ENV === "preview" ? "preview" : "development",
    tag: development ? env.HMUX_DEV_BUILD_TAG : undefined,
    sourceSha256: development ? env.HMUX_DEV_BUILD_SOURCE_SHA256?.match(/^[0-9a-f]{64}$/)?.[0] : undefined,
    revision: (development ? env.HMUX_DEV_BUILD_COMMIT : env.VERCEL_GIT_COMMIT_SHA)?.match(/^[0-9a-f]{7,64}$/)?.[0] ?? "unknown",
  };
}

function isDevelopmentBuild(env: NodeJS.ProcessEnv): boolean {
  return !env.VERCEL_ENV && !!env.HMUX_DEV_BUILD_TAG?.trim();
}

function telemetryDataset(development: boolean, production: boolean, errors: boolean): string {
  if (development) return "hmux-dev-otel-traces";
  if (production) return errors ? "hmux-cloud-errors-prod" : "hmux-prod-otel-traces";
  return errors ? "hmux-cloud-errors-preview" : "hmux-preview-otel-traces";
}

export async function exportCloudDiagnostics(
  rows: readonly StoredCloudDiagnostic[], configuration: CloudAxiomConfiguration, doFetch: typeof fetch = fetch,
): Promise<void> {
  if (rows.length === 0) return;
  const resourceSpans = rows.filter((row) => row.payload.source !== "server").map((row) => ({
    resource: { attributes: otlpAttributes(resourceAttributes(row, configuration)) },
    scopeSpans: [{ scope: { name: "hmux-cloud-native", version: "1" }, spans: [cloudSpanToOtlp(row.payload.span, row.payload.sampleWeight)] }],
  }));
  // Sign-in rate-limit records are auth signals, not Cloud errors; they live only in traces.
  const errors = rows.filter((row) => !row.payload.span.auth && ["failure", "timeout"].includes(row.payload.span.outcome)).map((row) => ({
    _time: new Date(row.payload.span.endedAtMs).toISOString(),
    client_channel: row.payload.client.channel,
    client_tag: row.payload.client.tag,
    client_version: row.payload.client.version,
    client_build: row.payload.client.build,
    client_revision: row.payload.client.revision,
    record_type: "cloud_error",
    backend_environment: configuration.environment,
    backend_tag: row.payload.backend?.tag,
    backend_source_sha256: row.payload.backend?.sourceSha256,
    backend_revision: row.payload.backend?.revision ?? "unknown",
    account_key: cloudTelemetryAccountKey(configuration.identityKey, row.userId),
    source: row.payload.source ?? "client",
    event_id: row.eventId, operation_id: row.payload.span.operationId,
    trace_id: row.payload.span.traceId, span_id: row.payload.span.spanId,
    parent_span_id: row.payload.span.parentSpanId,
    operation: row.payload.span.operation, phase: row.payload.span.phase,
    outcome: row.payload.span.outcome, failure: row.payload.span.failure,
    error_number: row.payload.span.errorNumber, http_status: row.payload.span.httpStatus,
    duration_ms: row.payload.span.endedAtMs - row.payload.span.startedAtMs,
    attempt: row.payload.span.attempt,
    source_file: row.payload.span.sourceFile, source_line: row.payload.span.sourceLine,
    error_code: row.payload.serverErrorCode,
  }));
  // Independent destinations run together; failure leaves the durable lease retryable.
  // An ambiguous network acknowledgement can repeat a span. Queries deduplicate event_id.
  await Promise.all([
    ...(resourceSpans.length ? [send("/v1/traces", { resourceSpans }, configuration.tracesDataset)] : []),
    ...(errors.length ? [send(`/v1/ingest/${configuration.errorsDataset}`, errors)] : []),
  ]);

  async function send(path: string, body: unknown, dataset?: string): Promise<void> {
    const result = await doFetch(`${configuration.origin}${path}`, {
      method: "POST", redirect: "error", signal: AbortSignal.timeout(10_000),
      headers: {
        authorization: `Bearer ${configuration.token}`, "content-type": "application/json",
        ...(dataset ? { "x-axiom-dataset": dataset } : {}),
      },
      body: JSON.stringify(body),
    });
    if (!result.ok) throw new Error(`cloud_diagnostic_export_http_${result.status}`);
    const text = await result.text();
    if (!text) return;
    const receipt = JSON.parse(text) as { failed?: number; partialSuccess?: { rejectedSpans?: string | number } };
    if (Number(receipt.failed ?? 0) > 0 || Number(receipt.partialSuccess?.rejectedSpans ?? 0) > 0) {
      throw new Error("cloud_diagnostic_export_partial_failure");
    }
  }
}

function resourceAttributes(row: StoredCloudDiagnostic, configuration: CloudAxiomConfiguration) {
  const client = row.payload.client;
  return {
    "service.name": row.payload.source === "server" ? "hmux-web" : "hmux-mac", "service.version": row.payload.source === "server" ? configuration.revision : client.version,
    "hmux.client.version": client.version,
    "deployment.environment.name": configuration.environment,
    "hmux.backend.revision": row.payload.backend?.revision ?? "unknown",
    "hmux.backend.tag": row.payload.backend?.tag,
    "hmux.backend.source_sha256": row.payload.backend?.sourceSha256,
    "hmux.client.channel": client.channel, "hmux.client.tag": client.tag, "hmux.client.build": client.build,
    "hmux.client.revision": client.revision,
    "service.instance.id": row.payload.source === "server" ? undefined : client.instanceId,
    "os.version": row.payload.source === "server" ? undefined : client.osVersion,
    "host.arch": row.payload.source === "server" ? undefined : client.architecture,
    "hmux.account_key": cloudTelemetryAccountKey(configuration.identityKey, row.userId),
    "hmux.observation.source": row.payload.source ?? "client",
  };
}

/**
 * Preserve the originating span, including time and parent, through the HTTP gateway.
 * `hmux.telemetry.sample_weight` is how many submitted spans this one stands for after
 * ingest sampling; estimate counts with `sum(sample_weight)`, not `count()`.
 */
type OtlpSpan = {
  readonly traceId: string; readonly spanId: string; readonly parentSpanId?: string;
  readonly name: string; readonly kind: number;
  readonly startTimeUnixNano: string; readonly endTimeUnixNano: string;
  readonly attributes: ReturnType<typeof otlpAttributes>; readonly status: { readonly code: number };
};

export function cloudSpanToOtlp(span: CloudTelemetrySpan, sampleWeight = 1): OtlpSpan {
  if (span.auth) return authSpanToOtlp(span, span.auth, sampleWeight);
  const attributes = {
    "hmux.subsystem": "vm-cloud", "hmux.observation.source": "client",
    "hmux.event_id": span.eventId, "hmux.operation_id": span.operationId,
    "hmux.cloud.operation": span.operation, "hmux.cloud.phase": span.phase,
    "hmux.cloud.outcome": span.outcome, "hmux.cloud.attempt": span.attempt,
    "error.type": span.failure, "http.response.status_code": span.httpStatus,
    "hmux.error_number": span.errorNumber, "hmux.telemetry.dropped_count": span.droppedCount,
    "code.file.name": span.sourceFile, "code.line.number": span.sourceLine,
    "hmux.telemetry.sample_weight": sampleWeight,
  };
  return {
    traceId: span.traceId, spanId: span.spanId,
    ...(span.parentSpanId ? { parentSpanId: span.parentSpanId } : {}),
    name: `hmux.cloud.${span.operation}.${span.phase}`,
    kind: span.phase === "request" ? 3 : 1,
    startTimeUnixNano: (BigInt(span.startedAtMs) * BigInt(1_000_000)).toString(),
    endTimeUnixNano: (BigInt(span.endedAtMs) * BigInt(1_000_000)).toString(),
    attributes: otlpAttributes(attributes),
    status: { code: span.outcome === "failure" || span.outcome === "timeout" ? 2 : 1 },
  };
}

/**
 * A sign-in service rate-limit record. The span name and `hmux.auth.*` attributes are the
 * contract of the "hmux Stack Auth health" dashboard and the client rate-limit monitor.
 */
function authSpanToOtlp(span: CloudTelemetrySpan, auth: CloudTelemetryAuth, sampleWeight: number): OtlpSpan {
  const limited = auth.event === "stack_rate_limited";
  const attributes = {
    "hmux.observation.source": "client", "hmux.event_id": span.eventId,
    "hmux.auth.phase": auth.phase,
    "hmux.auth.retry_after_s": auth.retryAfterS, "hmux.auth.backoff_s": auth.backoffS,
    "hmux.auth.attempt": limited ? span.attempt : undefined,
    "hmux.auth.body_kind": auth.bodyKind, "http.status_code": limited ? span.httpStatus : undefined,
    "hmux.auth.endpoint": auth.endpoint, "hmux.auth.limited_for_s": auth.limitedForS,
    "hmux.telemetry.dropped_count": span.droppedCount, "hmux.telemetry.sample_weight": sampleWeight,
  };
  return {
    traceId: span.traceId, spanId: span.spanId,
    name: `hmux.auth.${auth.event}`, kind: 3,
    startTimeUnixNano: (BigInt(span.startedAtMs) * BigInt(1_000_000)).toString(),
    endTimeUnixNano: (BigInt(span.endedAtMs) * BigInt(1_000_000)).toString(),
    attributes: otlpAttributes(attributes),
    status: { code: limited ? 2 : 1 },
  };
}

export function otlpAttributes(values: Record<string, string | number | undefined>) {
  return Object.entries(values).flatMap(([key, value]) => value === undefined ? [] : [{
    key, value: typeof value === "number" ? { intValue: String(value) } : { stringValue: value },
  }]);
}

function trustedAxiomOrigin(value: string | undefined): string | null {
  try {
    const url = new URL(value ?? "https://us-east-1.aws.edge.axiom.co");
    if (url.protocol !== "https:" || !url.hostname.endsWith(".axiom.co") || url.username || url.password || url.port) return null;
    return url.origin;
  } catch { return null; }
}
