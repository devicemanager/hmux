import {
  withSpan,
  type MaybeAttributes,
  type SpanCallback,
} from "../telemetry";

/**
 * Time one Stack Auth SDK or API operation. Stack currently sends these
 * server calls through its Hexclave-compatible API headers, so the transport
 * is recorded as an attribute without exposing credentials or request data.
 */
export function withStackAuthSpan<T>(
  operation: string,
  fn: SpanCallback<T>,
  attributes: MaybeAttributes = {},
): Promise<T> {
  return withSpan(
    "hmux-stack-auth",
    `hmux.stack_auth.${operation}`,
    {
      "hmux.external.service": "stack-auth",
      "hmux.external.transport": "hexclave",
      "hmux.external.operation": operation,
      ...attributes,
    },
    fn,
  );
}
