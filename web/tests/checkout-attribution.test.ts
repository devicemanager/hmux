import { describe, expect, test } from "bun:test";

import {
  checkoutAttributionFromMetadata,
  checkoutAttributionFromRequest,
  checkoutAttributionMetadata,
  checkoutAttributionProperties,
  forwardCheckoutAttribution,
  withCheckoutAttribution,
} from "../services/analytics/checkoutAttribution";

describe("checkout attribution", () => {
  test("normalizes request parameters and falls back to unknown/web", () => {
    const attribution = checkoutAttributionFromRequest({
      searchParams: new URLSearchParams(
        "hmux_source=Mac_Sidebar_Badge&hmux_placement=<script>&hmux_client=MAC" +
          "&hmux_channel=beta&hmux_app_version=0.65.1&hmux_app_build=x y&utm_source=" +
          "%20Newsletter%20",
      ),
      referer: "https://cmux.com/app-pricing?cmux_app=1&secret=1",
    });

    expect(attribution).toEqual({
      source: "mac_sidebar_badge",
      placement: null,
      client: "mac",
      channel: null,
      appVersion: "0.65.1",
      appBuild: null,
      referrerHost: "cmux.com",
      referrerPath: "/app-pricing",
      utmSource: "Newsletter",
      utmMedium: null,
      utmCampaign: null,
      utmContent: null,
      utmTerm: null,
    });
  });

  test("defaults an untagged request to an unknown web checkout with no referrer", () => {
    const attribution = checkoutAttributionFromRequest({
      searchParams: new URLSearchParams("plan=pro"),
      referer: "javascript:alert(1)",
    });
    expect(attribution.source).toBe("unknown");
    expect(attribution.client).toBe("web");
    expect(attribution.referrerHost).toBeNull();
    expect(attribution.referrerPath).toBeNull();
  });

  test("round-trips through Stripe metadata", () => {
    const attribution = checkoutAttributionFromRequest({
      searchParams: new URLSearchParams(
        "hmux_source=pricing_page&hmux_placement=hero&hmux_client=web&utm_campaign=launch",
      ),
      referer: "https://cmux.com/pricing",
    });
    const metadata = checkoutAttributionMetadata(attribution);
    expect(metadata).toEqual({
      hmuxSource: "pricing_page",
      hmuxPlacement: "hero",
      hmuxClient: "web",
      hmuxReferrerHost: "cmux.com",
      hmuxReferrerPath: "/pricing",
      utmCampaign: "launch",
    });
    expect(checkoutAttributionFromMetadata(metadata)).toEqual(attribution);
    expect(Object.keys(checkoutAttributionProperties(attribution))).toEqual([
      "checkout_source",
      "checkout_placement",
      "checkout_client",
      "checkout_channel",
      "checkout_app_version",
      "checkout_app_build",
      "checkout_referrer_host",
      "checkout_referrer_path",
      "utm_source",
      "utm_medium",
      "utm_campaign",
      "utm_content",
      "utm_term",
    ]);
  });

  test("reads sessions created before attribution existed as unknown", () => {
    const attribution = checkoutAttributionFromMetadata({ plan: "pro", app: "hmux" });
    expect(attribution.source).toBe("unknown");
    expect(attribution.client).toBe("web");
    expect(attribution.channel).toBeNull();
  });

  test("appends attribution to a link and keeps the hash", () => {
    expect(
      withCheckoutAttribution("/api/billing/checkout?plan=pro#top", {
        hmux_source: "dashboard_billing",
        hmux_placement: null,
        utm_source: undefined,
      }),
    ).toBe("/api/billing/checkout?plan=pro&hmux_source=dashboard_billing#top");
  });

  test("forwards only attribution parameters onto a relay target", () => {
    const target = new URL("https://checkout.hmux.test/api/billing/checkout?plan=pro");
    forwardCheckoutAttribution(
      new URLSearchParams("hmux_source=mac_help_menu&hmux_channel=nightly&hmux_scheme=hmux&plan=team"),
      target,
    );
    expect(target.searchParams.get("hmux_source")).toBe("mac_help_menu");
    expect(target.searchParams.get("hmux_channel")).toBe("nightly");
    expect(target.searchParams.get("plan")).toBe("pro");
    expect(target.searchParams.has("hmux_scheme")).toBe(false);
  });
});
