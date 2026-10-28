import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";
import {
  insecureLoopbackMinterAllowed,
  parseIrohMinterUrl,
  type IrohMinterUrlPolicy,
} from "../services/iroh/minterUrlPolicy";

// Trim at the runtimeEnv source so every consumer — including paths that
// run when validation is skipped (VERCEL_ENV === "preview") — sees clean
// values. A trailing newline in Vercel env vars has tripped Stack Auth's
// UUID parser and malformed the stack-refresh-<project-id> cookie key.
const trimEnv = (value: string | undefined): string | undefined =>
  typeof value === "string" ? value.trim() : value;

const isDocsZone =
  process.env.HMUX_DOCS_CHANNEL === "release" ||
  process.env.HMUX_DOCS_CHANNEL === "nightly";
const skipEnvValidation =
  process.env.SKIP_ENV_VALIDATION === "1" ||
  process.env.VERCEL_ENV === "preview" ||
  isDocsZone;
const allowPreviewStackPlaceholders =
  process.env.VERCEL_ENV === "preview" || isDocsZone;
const isVercelNonPreviewDeployment =
  process.env.VERCEL === "1" &&
  typeof process.env.VERCEL_ENV === "string" &&
  process.env.VERCEL_ENV !== "preview" &&
  !isDocsZone;
const irohMinterUrlPolicy: IrohMinterUrlPolicy = {
  allowInsecureLoopback:
    trimEnv(process.env.HMUX_IROH_DEV_ALLOW_INSECURE_LOOPBACK_MINTER) === "1",
  deploymentEnvironment:
    process.env.VERCEL_ENV ?? process.env.NODE_ENV ?? "development",
  isVercelDeployment: process.env.VERCEL === "1",
};
const requireVercelNonPreviewValue = (
  name: string,
  schema: z.ZodType<string> = z.string().min(1),
): z.ZodType<string | undefined> =>
  schema.optional().superRefine((value, context) => {
    if (isVercelNonPreviewDeployment && !value) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: `${name} is required for deployed non-preview runtimes`,
      });
    }
  });
const requireVercelRelayValue = (
  schema: z.ZodString = z.string().min(1),
): z.ZodType<string | undefined> =>
  schema.optional().superRefine((value, context) => {
    if (isVercelNonPreviewDeployment && !value) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Self-hosted relay runtime configuration is incomplete",
      });
    }
  });
const retiredEnvValue = (
  name: string,
  replacement: string,
): z.ZodType<string | undefined> =>
  z.string().optional().superRefine((value, context) => {
    if (value) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: `${name} is retired; use ${replacement}`,
      });
    }
  });
const privateRelayEnvNames = new Set([
  "HMUX_RELAY_JWT_PRIVATE_KEY_PEM",
  "HMUX_RELAY_POLICY_KEY_ID",
  "HMUX_RELAY_POLICY_PRIVATE_KEY_PEM",
]);
const publicEnvValidationIssues = (issues: readonly unknown[]): readonly unknown[] => {
  const publicIssues: unknown[] = [];
  let hasPrivateRelayIssue = false;
  for (const issue of issues) {
    const path = (issue as { path?: unknown } | null)?.path;
    const firstSegment = Array.isArray(path) ? path[0] : undefined;
    const pathKey = typeof firstSegment === "string"
      ? firstSegment
      : typeof firstSegment === "object" && firstSegment !== null && "key" in firstSegment
      ? String((firstSegment as { key: unknown }).key)
      : undefined;
    if (pathKey && privateRelayEnvNames.has(pathKey)) {
      hasPrivateRelayIssue = true;
    } else {
      publicIssues.push(issue);
    }
  }
  if (hasPrivateRelayIssue) {
    publicIssues.push({
      code: "custom",
      message: "Self-hosted relay runtime configuration is incomplete",
      path: ["relayRuntimeConfiguration"],
    });
  }
  return publicIssues;
};
const localDevelopmentOptIn = (name: string) =>
  z.enum(["0", "1"]).optional().superRefine((value, context) => {
    if (
      value === "1" &&
      !insecureLoopbackMinterAllowed({
        ...irohMinterUrlPolicy,
        allowInsecureLoopback: true,
      })
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: `${name} is only allowed in local development`,
      });
    }
  });
const irohMinterUrl = z.string().url().superRefine((value, context) => {
  try {
    parseIrohMinterUrl(value, irohMinterUrlPolicy);
  } catch {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message:
        "HMUX_IROH_MINT_URL must use HTTPS, except for an opted-in local loopback development minter",
    });
  }
});
const bareHttpsOrigin = (name: string) => z.string().url().superRefine((value, context) => {
  let parsed: URL | null = null;
  try {
    parsed = new URL(value);
  } catch {
    parsed = null;
  }
  if (
    !parsed ||
    parsed.protocol !== "https:" ||
    !parsed.hostname ||
    parsed.username ||
    parsed.password ||
    parsed.pathname !== "/" ||
    parsed.search ||
    parsed.hash
  ) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message:
        `${name} must be a bare https:// origin with no path, query, or credentials`,
    });
  }
});
const publicationAuthOrigin = bareHttpsOrigin("HMUX_VM_PUBLICATION_AUTH_ORIGIN");
const publicationForwardAuthOrigin = z.preprocess(
  (value) => typeof value === "string" && value.trim() === "" ? undefined : value,
  bareHttpsOrigin("HMUX_VM_PUBLICATION_FORWARD_AUTH_ORIGIN").optional(),
);
const irohBindingLimit = z.string().regex(/^[1-9][0-9]{0,3}$/).superRefine((value, context) => {
  if (Number(value) > 4_096) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Iroh binding limits must not exceed 4096",
    });
  }
});
const coderouterPublicOrigin = z.string().url().superRefine((value, context) => {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message: "HMUX_CODEROUTER_PUBLIC_ORIGIN must be a valid origin",
    });
    return;
  }
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash
  ) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message:
        "HMUX_CODEROUTER_PUBLIC_ORIGIN must be an origin-only HTTPS URL",
    });
  }
});
const stackEnv = (
  value: string | undefined,
  fallback: string
): string | undefined => {
  const trimmed = trimEnv(value);
  if (trimmed) return trimmed;
  return allowPreviewStackPlaceholders ? fallback : undefined;
};
const positiveSafeIntegerEnv = (name: string) =>
  z.string()
    .regex(/^\d+$/)
    .refine((value) => {
      const parsed = Number(value);
      return Number.isSafeInteger(parsed) && parsed > 0;
    }, { message: `${name} must be a positive safe integer` });
const coderouterHeadersTimeoutEnv = z.string()
  .regex(/^\d+$/)
  .refine((value) => {
    const parsed = Number(value);
    return Number.isSafeInteger(parsed) && parsed >= 1_000 && parsed <= 30 * 60_000;
  }, {
    message: "CODEROUTER_UPSTREAM_HEADERS_TIMEOUT_MS must be between 1000 and 1800000",
  });

export const env = createEnv({
  server: {
    RESEND_API_KEY: z.string().min(1),
    HMUX_FEEDBACK_FROM_EMAIL: z.string().email(),
    HMUX_TEAM_INVITE_FROM_EMAIL: z.string().email().optional(),
    // Rate-limit rule ids are all optional: an unset id means that route runs
    // without rate limiting (the operator removed the limits deliberately).
    HMUX_BILLING_RECOVERY_RATE_LIMIT_ID: z.string().min(1).optional(),
    HMUX_FEEDBACK_RATE_LIMIT_ID: z.string().min(1).optional(),
    HMUX_CLIENT_CONFIG_RATE_LIMIT_ID: z.string().min(1).optional(),
    HMUX_ANALYTICS_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Team invite, invite-link, team-create, join, and accept routes.
    HMUX_TEAM_INVITE_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Cloud VM firewall rule create and delete, per signed-in user.
    HMUX_VM_FIREWALL_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Native ingress gates run before Stack verification, so provider outages
    // cannot turn reconnect/readiness fan-out into an auth-request storm.
    HMUX_PUSH_RATE_LIMIT_ID: z.string().min(1).optional(),
    HMUX_DEVICE_REGISTRY_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Native app and CodeRouter handoff routes fail closed when this limiter
    // (and the existing feedback fallback) is absent.
    HMUX_APP_SESSION_HANDOFF_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Canonical origin returned with CodeRouter route tokens. Deployed
    // non-preview runtimes must set this; handoff exchange never trusts a
    // forwarded/request host in production.
    HMUX_CODEROUTER_PUBLIC_ORIGIN: requireVercelNonPreviewValue(
      "HMUX_CODEROUTER_PUBLIC_ORIGIN",
      coderouterPublicOrigin,
    ),
    STACK_SECRET_SERVER_KEY: z.string().min(1),
    // APNs push (iOS notifications). Optional: the app boots without them; the
    // push route returns a clear "not configured" error until they are set.
    // HMUX_APNS_KEY_P8 holds the .p8 PEM (literal "\n" escapes are normalized
    // by the sender).
    HMUX_APNS_KEY_P8: z.string().min(1).optional(),
    HMUX_APNS_KEY_ID: z.string().min(1).optional(),
    HMUX_APNS_TEAM_ID: z.string().min(1).optional(),
    // hmux Founder's Edition welcome email (Stripe webhook -> Resend). Optional:
    // the /api/stripe/founders-welcome route returns "not configured" until the
    // webhook signing secret is set. HMUX_FOUNDERS_FROM_EMAIL overrides the
    // sender (defaults to austin@manaflow.ai) so the verified Resend domain can
    // change without a code edit.
    STRIPE_FOUNDERS_WEBHOOK_SECRET: z.string().min(1).optional(),
    // The dedicated personal Pro welcome endpoint is opt-in. Keep the legacy
    // billing-webhook sender active until the Stripe endpoint is registered
    // and verified in production.
    HMUX_PERSONAL_PRO_WELCOME_ENABLED: z.enum(["0", "1"]).optional(),
    HMUX_FOUNDERS_FROM_EMAIL: z.string().email().optional(),
    HMUX_PRO_FROM_EMAIL: z.string().email().optional(),
    // Direct Stripe billing for hmux Pro. Optional: when unset, checkout is
    // unavailable.
    STRIPE_SECRET_KEY: z.string().min(1).optional(),
    STRIPE_WEBHOOK_SECRET: z.string().min(1).optional(),
    // iOS in-app purchases (docs/billing/ios-in-app-purchases.md). Read by
    // services/billing/apple/config.ts. Without the key, transactions are
    // still verified but not refreshed from the App Store Server API.
    APPLE_IAP_KEY_ID: z.string().min(1).optional(),
    APPLE_IAP_ISSUER_ID: z.string().min(1).optional(),
    APPLE_IAP_PRIVATE_KEY: z.string().min(1).optional(),
    APPLE_IAP_BUNDLE_IDS: z.string().min(1).optional(),
    APPLE_IAP_APP_APPLE_ID: z.string().regex(/^\d+$/).optional(),
    APPLE_IAP_SANDBOX_ENTITLEMENTS: z.string().min(1).optional(),
    APPLE_IAP_ONLINE_CHECKS: z.enum(["0", "1"]).optional(),
    // Svix signing secret (`whsec_...`) for the Stack Auth webhook endpoint
    // `/api/webhooks/stack`. Optional: when unset the route answers 503 and
    // team removal is enforced only by the reconcile cron.
    STACK_WEBHOOK_SECRET: z.string().min(1).optional(),
    // Price-id overrides carry the amount in their name, and every retired
    // name fails env validation instead of silently pinning checkout to a
    // grandfathered Price (Stripe amounts are immutable; see plans.ts).
    STRIPE_PRO_MONTHLY_PRICE_ID: retiredEnvValue(
      "STRIPE_PRO_MONTHLY_PRICE_ID",
      "STRIPE_PRO_MONTHLY_50_PRICE_ID",
    ),
    STRIPE_PRO_MONTHLY_50_PRICE_ID: z.string().min(1).optional(),
    STRIPE_PRO_YEARLY_PRICE_ID: retiredEnvValue(
      "STRIPE_PRO_YEARLY_PRICE_ID",
      "STRIPE_PRO_YEARLY_480_PRICE_ID",
    ),
    STRIPE_PRO_YEARLY_288_PRICE_ID: retiredEnvValue(
      "STRIPE_PRO_YEARLY_288_PRICE_ID",
      "STRIPE_PRO_YEARLY_480_PRICE_ID",
    ),
    STRIPE_PRO_YEARLY_480_PRICE_ID: z.string().min(1).optional(),
    STRIPE_MAX_MONTHLY_200_PRICE_ID: z.string().min(1).optional(),
    STRIPE_MAX_YEARLY_1920_PRICE_ID: z.string().min(1).optional(),
    STRIPE_GO_MONTHLY_10_PRICE_ID: z.string().min(1).optional(),
    // Optional pin for the Pro <-> Max portal configuration; otherwise the
    // configuration is found by its metadata (see services/billing/stripe.ts).
    STRIPE_PERSONAL_PLAN_SWITCH_PORTAL_CONFIGURATION_ID: z.string().min(1).optional(),
    STRIPE_TEAM_MONTHLY_PRICE_ID: retiredEnvValue(
      "STRIPE_TEAM_MONTHLY_PRICE_ID",
      "STRIPE_TEAM_MONTHLY_60_PRICE_ID",
    ),
    STRIPE_TEAM_MONTHLY_60_PRICE_ID: z.string().min(1).optional(),
    STRIPE_TEAM_YEARLY_PRICE_ID: retiredEnvValue(
      "STRIPE_TEAM_YEARLY_PRICE_ID",
      "STRIPE_TEAM_YEARLY_576_PRICE_ID",
    ),
    STRIPE_TEAM_YEARLY_576_PRICE_ID: z.string().min(1).optional(),
    HMUX_APP_PRICING_CHECKOUT_URL: z.string().url().optional(),
    HMUX_APP_PRICING_RELAY_SECRET: z.string().min(32).optional(),
    // App Store Connect API for server-side TestFlight enrollment. Optional:
    // the dashboard shows enrollment unavailable until these credentials are set.
    // ASC_PRIVATE_KEY accepts PEM contents with literal "\n" escapes;
    // ASC_PRIVATE_KEY_PATH is a local-dev fallback path.
    ASC_KEY_ID: z.string().min(1).optional(),
    ASC_ISSUER_ID: z.string().min(1).optional(),
    ASC_PRIVATE_KEY: z.string().min(1).optional(),
    ASC_PRIVATE_KEY_PATH: z.string().min(1).optional(),
    HMUX_TESTFLIGHT_APP_ID: z.string().min(1).optional(),
    HMUX_PRO_TESTFLIGHT_GROUP_ID: z.string().min(1).optional(),
    SENTRY_DSN: z.string().url().optional(),
    // Cloud VM provisioning is paid-plan-only by default. The allow switch is
    // intentionally opt-in for controlled demos/rollbacks; the legacy require
    // flag remains accepted by the entitlement layer for migration parity.
    HMUX_VM_ALLOW_FREE_PROVISIONING: z.string().optional(),
    HMUX_VM_REQUIRE_PRO: z.string().optional(),
    HMUX_VM_DEFAULT_PLAN: z.string().optional(),
    // Freestyle authenticates every protected-domain subrequest with this
    // write-only token. Publication routes fail closed while it is absent.
    HMUX_VM_PUBLICATION_FORWARD_AUTH_SECRET:
      z.string().min(32).max(512).optional(),
    // Canonical HMUX web origin used for the cross-domain sign-in handoff and
    // pushed to Freestyle as the account-wide forward-auth target. It is never
    // derived from a request; protected publications fail closed without it.
    HMUX_VM_PUBLICATION_AUTH_ORIGIN: publicationAuthOrigin.optional(),
    // Optional origin Freestyle calls for forward-auth when it differs from
    // the sign-in origin, e.g. a tunnel to a development stack the edge can't
    // reach. Unset in production: the auth origin serves both.
    HMUX_VM_PUBLICATION_FORWARD_AUTH_ORIGIN: publicationForwardAuthOrigin.optional(),
    // Zone generated Cloud VM publication hostnames are minted under
    // (<random>.<zone>). The HMUX Freestyle account must own it: verify the
    // zone, CNAME `*` to the Freestyle edge, delegate `_acme-challenge`, and
    // request its wildcard certificate. Defaults to cmux.sh.
    HMUX_VM_PUBLICATION_GENERATED_DOMAIN: z
      .string()
      .regex(
        /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$/u,
        "HMUX_VM_PUBLICATION_GENERATED_DOMAIN must be a lowercase DNS zone with at least two labels",
      )
      // A hostname is at most 253 characters; leave room for the generated label.
      .max(200, "HMUX_VM_PUBLICATION_GENERATED_DOMAIN must leave room for a generated label")
      .optional(),
    // Vercel Firewall rule id that throttles sign-in transaction creation per
    // client and hostname on the Freestyle forward-auth route. Unset (or off
    // Vercel) applies no limit.
    HMUX_VM_PUBLICATION_SIGN_IN_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Hosted coderouter and Subrouter have no plan, permission, or team
    // allow-list gate: team membership is the only access requirement.
    CRON_SECRET: z.string().min(1).optional(),
    HMUX_ALERTS_SLACK_WEBHOOK_URL: z.string().url().optional(),
    // Preserve the legacy VM alert range. The VM consumers already apply
    // their compatibility fallback for zero and unsafe values.
    HMUX_VM_ALERT_CREATE_FAILURES_15M: z.string().regex(/^\d+$/).optional(),
    HMUX_VM_ALERT_EXPIRED_LEASES: z.string().regex(/^\d+$/).optional(),
    // Coderouter alert thresholds (per five-minute window) and the bound on
    // time-to-headers for upstream model calls. Defaults live next to the code.
    HMUX_CODEROUTER_ALERT_OPERATOR_FAILURES_5M: positiveSafeIntegerEnv("HMUX_CODEROUTER_ALERT_OPERATOR_FAILURES_5M").optional(),
    HMUX_CODEROUTER_ALERT_UPSTREAM_FAILURES_5M: positiveSafeIntegerEnv("HMUX_CODEROUTER_ALERT_UPSTREAM_FAILURES_5M").optional(),
    HMUX_CODEROUTER_ALERT_NO_ACCOUNT_5M: positiveSafeIntegerEnv("HMUX_CODEROUTER_ALERT_NO_ACCOUNT_5M").optional(),
    HMUX_CODEROUTER_ALERT_AUTH_REJECTED_5M: positiveSafeIntegerEnv("HMUX_CODEROUTER_ALERT_AUTH_REJECTED_5M").optional(),
    CODEROUTER_UPSTREAM_HEADERS_TIMEOUT_MS: coderouterHeadersTimeoutEnv.optional(),
    // Slack Incoming Webhook for the #website-waitlist channel. Optional: the
    // /api/waitlist route silently skips the Slack ping when it is unset.
    SLACK_WAITLIST_WEBHOOK_URL: z.string().url().optional(),
    // Slack Incoming Webhook for Enterprise contact requests. Optional: the
    // /api/enterprise/contact route falls back to the waitlist webhook, then
    // skips Slack if neither is set.
    SLACK_ENTERPRISE_WEBHOOK_URL: z.string().url().optional(),
    // Slack Incoming Webhook for support requests. Optional: the
    // /api/support/contact route falls back to the enterprise webhook, then
    // the waitlist webhook, then skips Slack if none is set.
    SLACK_SUPPORT_WEBHOOK_URL: z.string().url().optional(),
    // Temporary retirement credentials for DB-mapped tenants created before
    // hosted Stack onboarding. Remove after subrouter_tenants is empty.
    SUBROUTER_BASE_URL: z.string().url().optional(),
    SUBROUTER_ADMIN_TOKEN: z.string().min(1).max(1_024).optional(),
    SUBROUTER_HOSTED_URL: z.string().url().optional(),
    SUBROUTER_STACK_TENANT_DELETE_TOKEN: requireVercelNonPreviewValue(
      "SUBROUTER_STACK_TENANT_DELETE_TOKEN",
      z.string().min(32).max(1_024),
    ),
    SUBROUTER_STACK_AUTH_TIMEOUT_MS: z.string()
      .regex(/^[1-9][0-9]{0,4}$/)
      .refine((value) => Number(value) <= 30_000, {
        message: "SUBROUTER_STACK_AUTH_TIMEOUT_MS must not exceed 30000",
      })
      .optional(),
    // Iroh trust broker. The Services API key deliberately has no TypeScript
    // env entry: only the isolated Rust relay minter may hold it. These values
    // are server-only and routes fail closed when an operation's key is absent.
    HMUX_IROH_LAN_DISCOVERY_SECRET_B64: requireVercelNonPreviewValue(
      "HMUX_IROH_LAN_DISCOVERY_SECRET_B64",
      z.string().max(512).regex(/^[A-Za-z0-9+/]{43,}={0,2}$/),
    ),
    HMUX_IROH_ACCOUNT_SUBJECT_SECRET_B64: requireVercelNonPreviewValue(
      "HMUX_IROH_ACCOUNT_SUBJECT_SECRET_B64",
      z.string().max(512).regex(/^[A-Za-z0-9+/]{43,}={0,2}$/),
    ),
    HMUX_IROH_GRANT_SIGNING_KEY_P8: requireVercelNonPreviewValue(
      "HMUX_IROH_GRANT_SIGNING_KEY_P8",
      z.string().min(64).max(16_384),
    ),
    HMUX_IROH_GRANT_SIGNING_KID: requireVercelNonPreviewValue(
      "HMUX_IROH_GRANT_SIGNING_KID",
      z.string().regex(/^[A-Za-z0-9._-]{1,64}$/),
    ),
    HMUX_IROH_GRANT_VERIFICATION_KEYS_JSON: requireVercelNonPreviewValue(
      "HMUX_IROH_GRANT_VERIFICATION_KEYS_JSON",
      z.string().min(2).max(32_768),
    ),
    // Optional compatibility path for n0-hosted relay credentials. The
    // self-hosted fleet mints endpoint-bound JWTs through /api/relay/token.
    HMUX_IROH_MINT_URL: irohMinterUrl.optional(),
    HMUX_IROH_MINT_HMAC_SECRET_B64:
      z.string().max(512).regex(/^[A-Za-z0-9+/]{43,}={0,2}$/).optional(),
    // Optional: leave unset to disable iroh rate limiting entirely. When unset,
    // the firewall gate in routeHandler.ts is skipped. Matches the other
    // optional rate-limit IDs (for example
    // HMUX_RELAY_PREFERENCES_RATE_LIMIT_ID).
    HMUX_IROH_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Account-scoped route invalidations. The payload is revision-only; apps
    // reconcile through /api/connectivity/v2/sync. Optional so previews and
    // local tests can run without a presence worker.
    HMUX_PRESENCE_BASE_URL: z.string().url().optional(),
    // Server-to-worker authentication for revision publication. Native clients
    // hold only their Stack access token and can never mint invalidations.
    HMUX_CONNECTIVITY_INVALIDATION_SECRET: z.string().min(32).max(512).optional(),
    // Server-to-worker authentication for Cloud machine list (`vms` sync)
    // publication. Must equal the presence Worker's VMS_PUBLISHER_SECRET.
    // Optional: unset skips publication and the Mac list keeps polling.
    HMUX_PRESENCE_VMS_PUBLISHER_SECRET: z.string().min(32).max(512).optional(),
    HMUX_IROH_DEV_ALLOW_INSECURE_LOOPBACK_MINTER: localDevelopmentOptIn(
      "HMUX_IROH_DEV_ALLOW_INSECURE_LOOPBACK_MINTER",
    ),
    HMUX_IROH_DEV_BINDING_OVERRIDE_ENABLED: z.enum(["0", "1"]).optional(),
    HMUX_IROH_DEV_BINDING_OVERRIDE_USER_IDS: z.string().max(8_192).optional(),
    HMUX_IROH_DEV_BINDING_OVERRIDE_ENVIRONMENTS: z.string().max(256).optional(),
    HMUX_IROH_DEV_BINDING_ACCOUNT_LIMIT: irohBindingLimit.optional(),
    HMUX_IROH_DEV_BINDING_DEVICE_LIMIT: irohBindingLimit.optional(),
    // Explicit opt-in for the hosted DEV relay limiter exemption. The route
    // still requires the development Stack project, a tagged debug namespace,
    // and membership in HMUX_IROH_DEV_RATE_LIMIT_BYPASS_TEAM_IDS.
    HMUX_IROH_DEV_RATE_LIMIT_BYPASS_ENABLED: z.enum(["0", "1"]).optional(),
    HMUX_IROH_DEV_RATE_LIMIT_BYPASS_TEAM_IDS: z.string().max(8_192).optional(),
    // Self-hosted relay fleet. Preview and local builds remain credential-free,
    // while every deployed non-preview runtime must be able to mint endpoint-
    // bound credentials, sign the fleet policy, and enforce its account limit.
    HMUX_RELAY_JWT_PRIVATE_KEY_PEM: requireVercelRelayValue(
      z.string().min(64).max(16_384),
    ),
    HMUX_RELAY_POLICY_KEY_ID: requireVercelRelayValue(
      z.string().regex(/^[A-Za-z0-9](?:[A-Za-z0-9._-]{0,62}[A-Za-z0-9])?$/),
    ),
    HMUX_RELAY_POLICY_PRIVATE_KEY_PEM: requireVercelRelayValue(
      z.string().min(64).max(16_384),
    ),
    // Optional: leave unset to disable relay-token rate limiting entirely.
    // When unset, enforceRelayRateLimit skips the firewall gate. Matches
    // HMUX_IROH_RATE_LIMIT_ID and HMUX_RELAY_PREFERENCES_RATE_LIMIT_ID.
    HMUX_RELAY_TOKEN_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Optional dedicated rule. Preferences deliberately fall back to the token
    // rule so existing deployments keep one shared account-scoped limiter.
    HMUX_RELAY_PREFERENCES_RATE_LIMIT_ID: z.string().min(1).optional(),
    // Shared secret for the relay fleet's per-connection access-control hook
    // (POST /api/relay/allow). Optional: when unset the route answers 503 and
    // the fleet fails closed for new endpoint admissions. Same base64 shape as
    // HMUX_IROH_MINT_HMAC_SECRET_B64.
    HMUX_RELAY_ALLOW_HMAC_SECRET_B64:
      z.string().max(512).regex(/^[A-Za-z0-9+/]{43,}={0,2}$/).optional(),
  },
  client: {
    NEXT_PUBLIC_STACK_PROJECT_ID: z.string().min(1),
    NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY: z.string().min(1),
  },
  runtimeEnv: {
    RESEND_API_KEY: trimEnv(process.env.RESEND_API_KEY),
    HMUX_BILLING_RECOVERY_RATE_LIMIT_ID: trimEnv(
      process.env.HMUX_BILLING_RECOVERY_RATE_LIMIT_ID,
    ),
    HMUX_FEEDBACK_FROM_EMAIL: trimEnv(process.env.HMUX_FEEDBACK_FROM_EMAIL),
    HMUX_TEAM_INVITE_FROM_EMAIL: trimEnv(process.env.HMUX_TEAM_INVITE_FROM_EMAIL),
    HMUX_FEEDBACK_RATE_LIMIT_ID: trimEnv(process.env.HMUX_FEEDBACK_RATE_LIMIT_ID),
    HMUX_CLIENT_CONFIG_RATE_LIMIT_ID: trimEnv(process.env.HMUX_CLIENT_CONFIG_RATE_LIMIT_ID),
    HMUX_ANALYTICS_RATE_LIMIT_ID: trimEnv(process.env.HMUX_ANALYTICS_RATE_LIMIT_ID),
    HMUX_TEAM_INVITE_RATE_LIMIT_ID: trimEnv(process.env.HMUX_TEAM_INVITE_RATE_LIMIT_ID),
    HMUX_VM_FIREWALL_RATE_LIMIT_ID: trimEnv(process.env.HMUX_VM_FIREWALL_RATE_LIMIT_ID),
    HMUX_PUSH_RATE_LIMIT_ID: trimEnv(process.env.HMUX_PUSH_RATE_LIMIT_ID),
    HMUX_DEVICE_REGISTRY_RATE_LIMIT_ID: trimEnv(
      process.env.HMUX_DEVICE_REGISTRY_RATE_LIMIT_ID,
    ),
    HMUX_APP_SESSION_HANDOFF_RATE_LIMIT_ID: trimEnv(
      process.env.HMUX_APP_SESSION_HANDOFF_RATE_LIMIT_ID,
    ),
    HMUX_CODEROUTER_PUBLIC_ORIGIN: trimEnv(
      process.env.HMUX_CODEROUTER_PUBLIC_ORIGIN,
    ),
    HMUX_APNS_KEY_P8: trimEnv(process.env.HMUX_APNS_KEY_P8),
    HMUX_APNS_KEY_ID: trimEnv(process.env.HMUX_APNS_KEY_ID),
    HMUX_APNS_TEAM_ID: trimEnv(process.env.HMUX_APNS_TEAM_ID),
    STRIPE_FOUNDERS_WEBHOOK_SECRET: trimEnv(process.env.STRIPE_FOUNDERS_WEBHOOK_SECRET),
    HMUX_PERSONAL_PRO_WELCOME_ENABLED: trimEnv(
      process.env.HMUX_PERSONAL_PRO_WELCOME_ENABLED,
    ),
    HMUX_FOUNDERS_FROM_EMAIL: trimEnv(process.env.HMUX_FOUNDERS_FROM_EMAIL),
    HMUX_PRO_FROM_EMAIL: trimEnv(process.env.HMUX_PRO_FROM_EMAIL),
    STRIPE_SECRET_KEY: trimEnv(process.env.STRIPE_SECRET_KEY),
    STRIPE_WEBHOOK_SECRET: trimEnv(process.env.STRIPE_WEBHOOK_SECRET),
    APPLE_IAP_KEY_ID: trimEnv(process.env.APPLE_IAP_KEY_ID),
    APPLE_IAP_ISSUER_ID: trimEnv(process.env.APPLE_IAP_ISSUER_ID),
    APPLE_IAP_PRIVATE_KEY: trimEnv(process.env.APPLE_IAP_PRIVATE_KEY),
    APPLE_IAP_BUNDLE_IDS: trimEnv(process.env.APPLE_IAP_BUNDLE_IDS),
    APPLE_IAP_APP_APPLE_ID: trimEnv(process.env.APPLE_IAP_APP_APPLE_ID),
    APPLE_IAP_SANDBOX_ENTITLEMENTS: trimEnv(process.env.APPLE_IAP_SANDBOX_ENTITLEMENTS),
    APPLE_IAP_ONLINE_CHECKS: trimEnv(process.env.APPLE_IAP_ONLINE_CHECKS),
    STACK_WEBHOOK_SECRET: trimEnv(process.env.STACK_WEBHOOK_SECRET),
    STRIPE_PRO_MONTHLY_PRICE_ID: trimEnv(process.env.STRIPE_PRO_MONTHLY_PRICE_ID),
    STRIPE_PRO_MONTHLY_50_PRICE_ID: trimEnv(process.env.STRIPE_PRO_MONTHLY_50_PRICE_ID),
    STRIPE_PRO_YEARLY_PRICE_ID: trimEnv(process.env.STRIPE_PRO_YEARLY_PRICE_ID),
    STRIPE_PRO_YEARLY_288_PRICE_ID: trimEnv(
      process.env.STRIPE_PRO_YEARLY_288_PRICE_ID,
    ),
    STRIPE_PRO_YEARLY_480_PRICE_ID: trimEnv(process.env.STRIPE_PRO_YEARLY_480_PRICE_ID),
    STRIPE_MAX_MONTHLY_200_PRICE_ID: trimEnv(process.env.STRIPE_MAX_MONTHLY_200_PRICE_ID),
    STRIPE_MAX_YEARLY_1920_PRICE_ID: trimEnv(process.env.STRIPE_MAX_YEARLY_1920_PRICE_ID),
    STRIPE_GO_MONTHLY_10_PRICE_ID: trimEnv(process.env.STRIPE_GO_MONTHLY_10_PRICE_ID),
    STRIPE_PERSONAL_PLAN_SWITCH_PORTAL_CONFIGURATION_ID: trimEnv(
      process.env.STRIPE_PERSONAL_PLAN_SWITCH_PORTAL_CONFIGURATION_ID,
    ),
    STRIPE_TEAM_MONTHLY_PRICE_ID: trimEnv(process.env.STRIPE_TEAM_MONTHLY_PRICE_ID),
    STRIPE_TEAM_MONTHLY_60_PRICE_ID: trimEnv(process.env.STRIPE_TEAM_MONTHLY_60_PRICE_ID),
    STRIPE_TEAM_YEARLY_PRICE_ID: trimEnv(process.env.STRIPE_TEAM_YEARLY_PRICE_ID),
    STRIPE_TEAM_YEARLY_576_PRICE_ID: trimEnv(process.env.STRIPE_TEAM_YEARLY_576_PRICE_ID),
    HMUX_APP_PRICING_CHECKOUT_URL: trimEnv(
      process.env.HMUX_APP_PRICING_CHECKOUT_URL,
    ),
    HMUX_APP_PRICING_RELAY_SECRET: trimEnv(
      process.env.HMUX_APP_PRICING_RELAY_SECRET,
    ),
    ASC_KEY_ID: trimEnv(process.env.ASC_KEY_ID),
    ASC_ISSUER_ID: trimEnv(process.env.ASC_ISSUER_ID),
    ASC_PRIVATE_KEY: trimEnv(process.env.ASC_PRIVATE_KEY),
    ASC_PRIVATE_KEY_PATH: trimEnv(process.env.ASC_PRIVATE_KEY_PATH),
    HMUX_TESTFLIGHT_APP_ID: trimEnv(process.env.HMUX_TESTFLIGHT_APP_ID),
    HMUX_PRO_TESTFLIGHT_GROUP_ID: trimEnv(process.env.HMUX_PRO_TESTFLIGHT_GROUP_ID),
    SENTRY_DSN: trimEnv(process.env.SENTRY_DSN),
    HMUX_VM_ALLOW_FREE_PROVISIONING: trimEnv(process.env.HMUX_VM_ALLOW_FREE_PROVISIONING),
    HMUX_VM_REQUIRE_PRO: trimEnv(process.env.HMUX_VM_REQUIRE_PRO),
    HMUX_VM_DEFAULT_PLAN: trimEnv(process.env.HMUX_VM_DEFAULT_PLAN),
    HMUX_VM_PUBLICATION_FORWARD_AUTH_SECRET: trimEnv(
      process.env.HMUX_VM_PUBLICATION_FORWARD_AUTH_SECRET,
    ),
    HMUX_VM_PUBLICATION_AUTH_ORIGIN: trimEnv(
      process.env.HMUX_VM_PUBLICATION_AUTH_ORIGIN,
    ),
    // Blank (as in .env.example) means unset, not an invalid origin.
    HMUX_VM_PUBLICATION_FORWARD_AUTH_ORIGIN: trimEnv(
      process.env.HMUX_VM_PUBLICATION_FORWARD_AUTH_ORIGIN,
    ) || undefined,
    HMUX_VM_PUBLICATION_GENERATED_DOMAIN: trimEnv(
      process.env.HMUX_VM_PUBLICATION_GENERATED_DOMAIN,
    ),
    HMUX_VM_PUBLICATION_SIGN_IN_RATE_LIMIT_ID: trimEnv(
      process.env.HMUX_VM_PUBLICATION_SIGN_IN_RATE_LIMIT_ID,
    ),
    CRON_SECRET: trimEnv(process.env.CRON_SECRET),
    HMUX_ALERTS_SLACK_WEBHOOK_URL: trimEnv(process.env.HMUX_ALERTS_SLACK_WEBHOOK_URL),
    HMUX_VM_ALERT_CREATE_FAILURES_15M: trimEnv(process.env.HMUX_VM_ALERT_CREATE_FAILURES_15M),
    HMUX_VM_ALERT_EXPIRED_LEASES: trimEnv(process.env.HMUX_VM_ALERT_EXPIRED_LEASES),
    HMUX_CODEROUTER_ALERT_OPERATOR_FAILURES_5M: trimEnv(process.env.HMUX_CODEROUTER_ALERT_OPERATOR_FAILURES_5M),
    HMUX_CODEROUTER_ALERT_UPSTREAM_FAILURES_5M: trimEnv(process.env.HMUX_CODEROUTER_ALERT_UPSTREAM_FAILURES_5M),
    HMUX_CODEROUTER_ALERT_NO_ACCOUNT_5M: trimEnv(process.env.HMUX_CODEROUTER_ALERT_NO_ACCOUNT_5M),
    HMUX_CODEROUTER_ALERT_AUTH_REJECTED_5M: trimEnv(process.env.HMUX_CODEROUTER_ALERT_AUTH_REJECTED_5M),
    CODEROUTER_UPSTREAM_HEADERS_TIMEOUT_MS: trimEnv(process.env.CODEROUTER_UPSTREAM_HEADERS_TIMEOUT_MS),
    SLACK_WAITLIST_WEBHOOK_URL: trimEnv(process.env.SLACK_WAITLIST_WEBHOOK_URL),
    SLACK_ENTERPRISE_WEBHOOK_URL: trimEnv(process.env.SLACK_ENTERPRISE_WEBHOOK_URL),
    SLACK_SUPPORT_WEBHOOK_URL: trimEnv(process.env.SLACK_SUPPORT_WEBHOOK_URL),
    SUBROUTER_BASE_URL: trimEnv(process.env.SUBROUTER_BASE_URL),
    SUBROUTER_ADMIN_TOKEN: trimEnv(process.env.SUBROUTER_ADMIN_TOKEN),
    SUBROUTER_HOSTED_URL: trimEnv(process.env.SUBROUTER_HOSTED_URL),
    SUBROUTER_STACK_TENANT_DELETE_TOKEN: trimEnv(
      process.env.SUBROUTER_STACK_TENANT_DELETE_TOKEN,
    ),
    SUBROUTER_STACK_AUTH_TIMEOUT_MS: trimEnv(
      process.env.SUBROUTER_STACK_AUTH_TIMEOUT_MS,
    ),
    HMUX_IROH_LAN_DISCOVERY_SECRET_B64: trimEnv(process.env.HMUX_IROH_LAN_DISCOVERY_SECRET_B64),
    HMUX_IROH_ACCOUNT_SUBJECT_SECRET_B64: trimEnv(process.env.HMUX_IROH_ACCOUNT_SUBJECT_SECRET_B64),
    HMUX_IROH_GRANT_SIGNING_KEY_P8: trimEnv(process.env.HMUX_IROH_GRANT_SIGNING_KEY_P8),
    HMUX_IROH_GRANT_SIGNING_KID: trimEnv(process.env.HMUX_IROH_GRANT_SIGNING_KID),
    HMUX_IROH_GRANT_VERIFICATION_KEYS_JSON: trimEnv(process.env.HMUX_IROH_GRANT_VERIFICATION_KEYS_JSON),
    HMUX_IROH_MINT_URL: trimEnv(process.env.HMUX_IROH_MINT_URL),
    HMUX_IROH_MINT_HMAC_SECRET_B64: trimEnv(process.env.HMUX_IROH_MINT_HMAC_SECRET_B64),
    HMUX_IROH_RATE_LIMIT_ID: trimEnv(process.env.HMUX_IROH_RATE_LIMIT_ID),
    HMUX_PRESENCE_BASE_URL: trimEnv(process.env.HMUX_PRESENCE_BASE_URL),
    HMUX_CONNECTIVITY_INVALIDATION_SECRET: trimEnv(
      process.env.HMUX_CONNECTIVITY_INVALIDATION_SECRET,
    ),
    HMUX_PRESENCE_VMS_PUBLISHER_SECRET: trimEnv(
      process.env.HMUX_PRESENCE_VMS_PUBLISHER_SECRET,
    ),
    HMUX_IROH_DEV_ALLOW_INSECURE_LOOPBACK_MINTER: trimEnv(
      process.env.HMUX_IROH_DEV_ALLOW_INSECURE_LOOPBACK_MINTER,
    ),
    HMUX_IROH_DEV_BINDING_OVERRIDE_ENABLED: trimEnv(process.env.HMUX_IROH_DEV_BINDING_OVERRIDE_ENABLED),
    HMUX_IROH_DEV_BINDING_OVERRIDE_USER_IDS: trimEnv(process.env.HMUX_IROH_DEV_BINDING_OVERRIDE_USER_IDS),
    HMUX_IROH_DEV_BINDING_OVERRIDE_ENVIRONMENTS: trimEnv(process.env.HMUX_IROH_DEV_BINDING_OVERRIDE_ENVIRONMENTS),
    HMUX_IROH_DEV_BINDING_ACCOUNT_LIMIT: trimEnv(process.env.HMUX_IROH_DEV_BINDING_ACCOUNT_LIMIT),
    HMUX_IROH_DEV_BINDING_DEVICE_LIMIT: trimEnv(process.env.HMUX_IROH_DEV_BINDING_DEVICE_LIMIT),
    HMUX_IROH_DEV_RATE_LIMIT_BYPASS_ENABLED: trimEnv(
      process.env.HMUX_IROH_DEV_RATE_LIMIT_BYPASS_ENABLED,
    ),
    HMUX_IROH_DEV_RATE_LIMIT_BYPASS_TEAM_IDS: trimEnv(
      process.env.HMUX_IROH_DEV_RATE_LIMIT_BYPASS_TEAM_IDS,
    ),
    HMUX_RELAY_JWT_PRIVATE_KEY_PEM: trimEnv(process.env.HMUX_RELAY_JWT_PRIVATE_KEY_PEM),
    HMUX_RELAY_POLICY_KEY_ID: trimEnv(process.env.HMUX_RELAY_POLICY_KEY_ID),
    HMUX_RELAY_POLICY_PRIVATE_KEY_PEM: trimEnv(process.env.HMUX_RELAY_POLICY_PRIVATE_KEY_PEM),
    HMUX_RELAY_TOKEN_RATE_LIMIT_ID: trimEnv(process.env.HMUX_RELAY_TOKEN_RATE_LIMIT_ID),
    HMUX_RELAY_PREFERENCES_RATE_LIMIT_ID: trimEnv(
      process.env.HMUX_RELAY_PREFERENCES_RATE_LIMIT_ID,
    ),
    HMUX_RELAY_ALLOW_HMAC_SECRET_B64: trimEnv(
      process.env.HMUX_RELAY_ALLOW_HMAC_SECRET_B64,
    ),
    NEXT_PUBLIC_STACK_PROJECT_ID: stackEnv(
      process.env.NEXT_PUBLIC_STACK_PROJECT_ID,
      "00000000-0000-4000-8000-000000000000"
    ),
    NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY: stackEnv(
      process.env.NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY,
      "preview-publishable-client-key"
    ),
    STACK_SECRET_SERVER_KEY: stackEnv(
      process.env.STACK_SECRET_SERVER_KEY,
      "preview-secret-server-key"
    ),
  },
  skipValidation: skipEnvValidation,
  onValidationError: (issues) => {
    console.error("❌ Invalid environment variables:", publicEnvValidationIssues(issues));
    throw new Error("Invalid environment variables");
  },
});
