import { describe, expect, mock, test } from "bun:test";
import { renderToStaticMarkup } from "react-dom/server";

const capture = mock(() => undefined);

mock.module("posthog-js", () => ({
  default: { capture },
}));

const { ProCtaLink } = await import(
  "../app/[locale]/components/pro-cta-link"
);

describe("Pro pricing CTA", () => {
  test("routes the initial monthly selection to Stripe checkout", () => {
    const html = renderToStaticMarkup(
        <ProCtaLink
          checkoutHref="/api/billing/checkout?plan=pro&interval=month"
        >
          Get Pro
        </ProCtaLink>
      ,
    );

    expect(html).toContain(
      'href="/api/billing/checkout?plan=pro&amp;interval=month&amp;hmux_placement=pricing_page"',
    );
    expect(html).not.toContain("interval=year");
    expect(html).not.toContain('href="/download/confirmation?dl=1"');
  });

});


test("a pricing fallback click preserves inbound attribution before account data streams", async () => {
  const { PricingCheckoutButton } = await import("../app/components/pricing-checkout");
  const previous = Object.getOwnPropertyDescriptor(globalThis, "window");
  Object.defineProperty(globalThis, "window", { configurable: true, value: { location: { search: "?hmux_source=cli_free_access_expiry&utm_campaign=sept&plan=go" } } });
  try {
    for (const requiresSignIn of [false, true]) {
      const element = PricingCheckoutButton({ href: "/api/billing/checkout?plan=max&hmux_scheme=hmux-dev-test&hmux_external_browser=1", requiresSignIn,
        plan: "max", location: "pricing_page", children: "Get Max" });
      let href = element.props.resolveHref();
      if (requiresSignIn) {
        href = new URL(href, "https://cmux.com").searchParams.get("after_auth_return_to")!;
        href = new URL(href, "https://cmux.com").searchParams.get("after_auth_return_to")!;
      }
      const query = new URL(href, "https://cmux.com").searchParams;
      expect(query.get("plan")).toBe("max");
      expect(query.get("hmux_scheme")).toBe("hmux-dev-test");
      expect(query.get("hmux_source")).toBe("cli_free_access_expiry");
      expect(query.get("utm_campaign")).toBe("sept");
      expect(query.get("hmux_placement")).toBe("pricing_page");
    }
  } finally {
    if (previous) Object.defineProperty(globalThis, "window", previous);
    else Reflect.deleteProperty(globalThis, "window");
  }
});
