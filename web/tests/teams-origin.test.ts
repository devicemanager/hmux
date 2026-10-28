import { describe, expect, test } from "bun:test";
import {
  DEFAULT_TEAM_INVITE_ORIGIN,
  safeTeamLocale,
  teamInviteAcceptUrl,
  teamInviteLinkUrl,
  trustedTeamInviteOrigin,
} from "../services/teams/origin";

function request(url: string, headers: Record<string, string> = {}): Request {
  return new Request(url, { headers });
}

describe("trusted invite origin", () => {
  const spoofed = request("https://evil.example/api/teams/x/invitations", { host: "evil.example" });

  test("prefers HMUX_TEAM_INVITE_ORIGIN, then HMUX_APP_ORIGIN, as bare origins", () => {
    expect(trustedTeamInviteOrigin(spoofed, {
      HMUX_TEAM_INVITE_ORIGIN: "https://team.hmux.test/some/path",
      HMUX_APP_ORIGIN: "https://app.hmux.test",
      NODE_ENV: "production",
    })).toBe("https://team.hmux.test");
    expect(trustedTeamInviteOrigin(spoofed, { HMUX_APP_ORIGIN: "https://app.hmux.test", NODE_ENV: "production" }))
      .toBe("https://app.hmux.test");
  });

  test("never trusts the request host in production", () => {
    expect(trustedTeamInviteOrigin(spoofed, { NODE_ENV: "production" })).toBe(DEFAULT_TEAM_INVITE_ORIGIN);
    expect(trustedTeamInviteOrigin(spoofed, { VERCEL_ENV: "production", NODE_ENV: "development" })).toBe("https://cmux.com");
  });

  test("falls back to the default for an unusable configured origin", () => {
    expect(trustedTeamInviteOrigin(spoofed, { HMUX_TEAM_INVITE_ORIGIN: "javascript:alert(1)" })).toBe(DEFAULT_TEAM_INVITE_ORIGIN);
    expect(trustedTeamInviteOrigin(spoofed, { HMUX_APP_ORIGIN: "not a url" })).toBe(DEFAULT_TEAM_INVITE_ORIGIN);
  });

  test("uses the request origin only in development", () => {
    expect(trustedTeamInviteOrigin(request("http://localhost:3801/api/teams"), { NODE_ENV: "development" }))
      .toBe("http://localhost:3801");
  });
});

describe("invite URLs", () => {
  const environment = { HMUX_APP_ORIGIN: "https://cmux.com", NODE_ENV: "production" };

  test("allow-lists the locale so request data cannot change the host or path", () => {
    expect(safeTeamLocale("ja")).toBe("ja");
    for (const value of ["//evil.com", "..%2f", "en/../../x", "xx", "", null, undefined]) {
      expect(safeTeamLocale(value)).toBe("en");
    }
    const hostile = request("https://app.hmux.test/api/teams", {
      "x-next-intl-locale": "//evil.com",
      referer: "https://evil.com/..%2f/dashboard",
      cookie: "NEXT_LOCALE=//evil.com",
    });
    const url = new URL(teamInviteAcceptUrl(hostile, environment));
    expect(url.origin).toBe("https://cmux.com");
    expect(url.pathname).toBe("/en/dashboard/team/accept");
  });

  test("uses the caller's supported locale", () => {
    const japanese = request("https://app.hmux.test/api/teams", { referer: "https://app.hmux.test/ja/dashboard/teams/x" });
    expect(teamInviteAcceptUrl(japanese, environment)).toBe("https://cmux.com/ja/dashboard/team/accept");
  });

  test("builds the join URL on the trusted origin", () => {
    const token = "A".repeat(43);
    expect(teamInviteLinkUrl(request("https://evil.example/x"), token, environment)).toBe(`https://cmux.com/en/join/${token}`);
  });
});
