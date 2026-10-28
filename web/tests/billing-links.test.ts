import { describe, expect, test } from "bun:test";
import {
  appPricingCheckoutRelayURL,
  appPricingCheckoutURL,
  withCheckoutInterval,
  withCheckoutExternalBrowserIntent,
} from "../app/lib/billing";

describe("billing links", () => {
  test("marks relative checkout URLs for system-browser handoff", () => {
    expect(withCheckoutExternalBrowserIntent("/api/billing/checkout")).toBe(
      "/api/billing/checkout?hmux_external_browser=1",
    );
  });

  test("preserves existing query strings and hash fragments", () => {
    expect(
      withCheckoutExternalBrowserIntent(
        "https://cmux.com/api/billing/checkout?plan=pro#pay",
      ),
    ).toBe(
      "https://cmux.com/api/billing/checkout?plan=pro&hmux_external_browser=1#pay",
    );
  });

  test("app pricing checkout uses the request origin", () => {
    expect(appPricingCheckoutURL("pro", "http://localhost:9210")).toBe(
      "http://localhost:9210/api/billing/checkout?plan=pro&hmux_external_browser=1",
    );
    expect(appPricingCheckoutURL("team", "https://cmux.com")).toBe(
      "https://cmux.com/api/billing/checkout?plan=team&hmux_external_browser=1",
    );
  });

  test("app pricing checkout can carry the native callback scheme", () => {
    expect(appPricingCheckoutURL("pro", "http://localhost:9210", "hmux-dev-test")).toBe(
      "http://localhost:9210/api/billing/checkout?plan=pro&hmux_external_browser=1&hmux_scheme=hmux-dev-test",
    );
  });

  test("annual checkout carries the selected billing interval for every paid plan", () => {
    expect(withCheckoutInterval("/api/billing/checkout?plan=pro", "year")).toBe(
      "/api/billing/checkout?plan=pro&interval=year",
    );
    expect(
      appPricingCheckoutURL(
        "pro",
        "http://localhost:9210",
        "hmux-dev-test",
        "year",
      ),
    ).toBe(
      "http://localhost:9210/api/billing/checkout?plan=pro&hmux_external_browser=1&hmux_scheme=hmux-dev-test&interval=year",
    );
    expect(
      appPricingCheckoutURL(
        "team",
        "http://localhost:9210",
        "hmux-dev-test",
        "year",
      ),
    ).toBe(
      "http://localhost:9210/api/billing/checkout?plan=team&hmux_external_browser=1&hmux_scheme=hmux-dev-test&interval=year",
    );
  });

  test("relay forwards attribution unsigned next to the signed plan and scheme", () => {
    const previous = process.env.HMUX_APP_PRICING_CHECKOUT_URL;
    process.env.HMUX_APP_PRICING_CHECKOUT_URL = "https://billing.example/checkout";
    try {
      const relay = appPricingCheckoutRelayURL(
        new URL(
          "http://localhost:9210/api/billing/checkout?plan=pro&interval=year&hmux_app_checkout=1" +
            "&hmux_source=mac_help_menu&hmux_client=mac&hmux_channel=dev&hmux_app_version=0.65.1",
        ),
        { plan: "pro", interval: "year", hmuxScheme: "hmux" },
      );
      expect(relay?.origin).toBe("https://billing.example");
      expect(relay?.searchParams.get("hmux_source")).toBe("mac_help_menu");
      expect(relay?.searchParams.get("hmux_client")).toBe("mac");
      expect(relay?.searchParams.get("hmux_channel")).toBe("dev");
      expect(relay?.searchParams.get("hmux_app_version")).toBe("0.65.1");
      expect(relay?.searchParams.get("plan")).toBe("pro");
    } finally {
      if (previous === undefined) {
        delete process.env.HMUX_APP_PRICING_CHECKOUT_URL;
      } else {
        process.env.HMUX_APP_PRICING_CHECKOUT_URL = previous;
      }
    }
  });

  test("app pricing checkout relays an explicit override through its trusted origin", () => {
    const previous = process.env.HMUX_APP_PRICING_CHECKOUT_URL;
    process.env.HMUX_APP_PRICING_CHECKOUT_URL = "https://billing.example/checkout";
    try {
      expect(appPricingCheckoutURL("pro", "http://localhost:9210")).toBe(
        "http://localhost:9210/api/billing/checkout?plan=pro&hmux_external_browser=1&hmux_app_checkout=1",
      );
    } finally {
      if (previous === undefined) {
        delete process.env.HMUX_APP_PRICING_CHECKOUT_URL;
      } else {
        process.env.HMUX_APP_PRICING_CHECKOUT_URL = previous;
      }
    }
  });
});
