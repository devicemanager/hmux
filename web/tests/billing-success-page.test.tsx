import { describe, expect, mock, test } from "bun:test";
import { renderToStaticMarkup } from "react-dom/server";
import { createNextNavigationMock } from "./helpers/next-navigation-mock";

const purchaseModule = await import("../services/billing/purchase");
const stripeModule = await import("../services/billing/stripe");

const redirect = mock((href: unknown) => {
  throw Object.assign(new Error("redirect"), { href });
});

let nativeCallbackScheme: string | undefined;
let checkoutApp = "hmux";
const retrieveSession = mock(async () => ({
  client_reference_id: "stack-user-1",
  customer_details: { email: "buyer@example.com" },
  subscription: { status: "active" },
  metadata: {
    app: checkoutApp,
    plan: "pro",
    ...(nativeCallbackScheme ? { nativeCallbackScheme } : {}),
  },
}));

mock.module("next/navigation", () => createNextNavigationMock(redirect));

let acceptLanguage = "en";

mock.module("next/headers", () => ({
  headers: async () =>
    new Headers({
      "accept-language": acceptLanguage,
      host: "hmux.test",
      "x-forwarded-proto": "https",
    }),
  cookies: async () => ({
    get: () => undefined,
    getAll: () => [],
    has: () => false,
  }),
  draftMode: async () => ({ isEnabled: false }),
}));

mock.module("../services/billing/stripe", () => ({
  ...stripeModule,
  isStripeBillingConfigured: () => true,
  stripe: () => ({
    checkout: {
      sessions: {
        retrieve: retrieveSession,
      },
    },
  }),
}));

mock.module("../services/billing/purchase", () => ({
  ...purchaseModule,
  latestStripeSubscriptionForSession: mock(async () => null),
}));

const { default: BillingSuccessPage } = await import("../app/billing/success/page");

describe("billing success page", () => {
  test("falls back to English copy for a locale without billingSuccess", async () => {
    acceptLanguage = "fr";
    try {
      const element = await BillingSuccessPage({
        searchParams: Promise.resolve({ session_id: "cs_123" }),
      });
      const html = renderToStaticMarkup(element);
      expect(html).toContain("hmux Pro is active");
      expect(html).toContain("You&#x27;re all set");
      expect(html).toContain("What you unlocked");
    } finally {
      acceptLanguage = "en";
    }
  });

  test("renders welcome sections and links after an active purchase", async () => {
    const element = await BillingSuccessPage({
      searchParams: Promise.resolve({ session_id: "cs_123" }),
    });
    const html = renderToStaticMarkup(element);

    expect(html).toContain("hmux Pro is active");
    expect(html).toContain("buyer@example.com");
    expect(html).toContain("What you unlocked");
    expect(html).toContain("Cloud agents on Cloud VMs");
    expect(html).toContain("Run agents in isolated remote sandboxes.");
    expect(html).toContain("Model gateway");
    expect(html).toContain("Hosted model routing across your connected provider accounts.");
    expect(html).toContain("Connect your AI accounts");
    expect(html).toContain("Add provider accounts so hmux can route work through them.");
    expect(html).toContain("hmux iOS app");
    expect(html).toContain("Use hmux on your phone.");
    expect(html).toContain('href="https://hmux.test/handler/after-sign-in?native_app_return_to=hmux%3A%2F%2Fauth-callback"');
    expect(html).toContain('target="_blank"');
    expect(html).toContain('href="/dashboard/coderouter"');
    expect(html).toContain('href="/dashboard/ai-accounts"');
    expect(html).toContain('href="/dashboard/testflight"');
    expect(html).toContain('href="/dashboard/billing"');
    expect(html).toContain('href="/handler/account-settings"');
    expect(html).toContain("Manage billing");
    expect(html).toContain("Open hmux");
    expect(html).toContain("Manage sign-in methods");
    expect(redirect).not.toHaveBeenCalled();
    expect(retrieveSession).toHaveBeenCalledWith("cs_123", {
      expand: ["subscription", "customer"],
    });
  });

  test("opens the tagged app recorded by the trusted checkout", async () => {
    const previousSecret = process.env.HMUX_APP_PRICING_RELAY_SECRET;
    process.env.HMUX_APP_PRICING_RELAY_SECRET =
      "pricing-relay-test-secret-with-at-least-32-bytes";
    nativeCallbackScheme = "hmux-dev-test";
    try {
      const element = await BillingSuccessPage({
        searchParams: Promise.resolve({
          session_id: "cs_123",
          hmux_scheme: "hmux-dev-test",
        }),
      });
      const html = renderToStaticMarkup(element);

      expect(html).toContain(
        "native_app_return_to=hmux-dev-test%3A%2F%2Fauth-callback",
      );
      expect(html).toContain("hmux_checkout_session=cs_123");
      expect(html).toContain("hmux_native_return_expires=");
      expect(html).toMatch(/hmux_native_return_signature=[a-f0-9]{64}/);
    } finally {
      nativeCallbackScheme = undefined;
      if (previousSecret === undefined) {
        delete process.env.HMUX_APP_PRICING_RELAY_SECRET;
      } else {
        process.env.HMUX_APP_PRICING_RELAY_SECRET = previousSecret;
      }
    }
  });

  test("rejects a foreign Stripe session before signing a tagged callback", async () => {
    checkoutApp = "other";
    nativeCallbackScheme = "hmux-dev-attacker";
    try {
      await expect(
        BillingSuccessPage({
          searchParams: Promise.resolve({
            session_id: "cs_foreign",
            hmux_scheme: "hmux-dev-attacker",
          }),
        }),
      ).rejects.toMatchObject({ href: "/pricing?billing=error" });
    } finally {
      checkoutApp = "hmux";
      nativeCallbackScheme = undefined;
    }
  });
});
