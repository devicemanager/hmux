import { trace } from "@opentelemetry/api";
import type { PushSendSummary } from "./response";
import { recordSpanError, withApiRouteSpan, type MaybeAttributes } from "../telemetry";

export async function withApnsApiRoute(
  request: Request,
  route: string,
  operation: string,
  handler: () => Promise<Response>,
): Promise<Response> {
  return withApiRouteSpan(
    request,
    route,
    {
      "hmux.subsystem": "apns",
      "hmux.apns.operation": operation,
    } satisfies MaybeAttributes,
    async (span) => {
      try {
        return await handler();
      } catch (error) {
        recordSpanError(span, error);
        console.error(`${route} ${operation} failed`, error);
        return new Response(JSON.stringify({ error: "push_internal_error" }), {
          status: 500,
          headers: { "content-type": "application/json" },
        });
      }
    },
  );
}

/** Records aggregate delivery evidence without tokens, payload text, or APNs reasons. */
export function recordApnsRouteOutcome(
  summary: PushSendSummary,
  correlationId: string,
): void {
  trace.getActiveSpan()?.setAttributes({
    "hmux.push.correlation_id": correlationId,
    "hmux.apns.devices": summary.devices,
    "hmux.apns.sent": summary.sent,
    "hmux.apns.pruned": summary.pruned,
    "hmux.apns.transient_failures": summary.transientFailures,
    "hmux.apns.permanent_failures": summary.permanentFailures,
  });
}

/** Correlates a safe expected-failure stage without payload or device data. */
export function recordApnsEncryptionKeyRejection(): void {
  trace.getActiveSpan()?.setAttributes({
    "hmux.apns.failure_stage": "push_e2e_key_missing_or_invalid",
    "hmux.push.protocol": "notification-e2e-v1",
  });
}

/** Correlates a safe expected-failure stage without payload or device data. */
export function recordApnsRouteFailure(
  correlationId: string,
  stage: string,
): void {
  trace.getActiveSpan()?.setAttributes({
    "hmux.push.correlation_id": correlationId,
    "hmux.apns.failure_stage": stage,
  });
}
