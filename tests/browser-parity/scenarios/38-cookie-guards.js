// The session's domain policy covers cookies as it covers pages: a blocked
// URL's cookies cannot be read, set or cleared, and a blocked site's cookies
// are left out of every listing. The driver decides which site a clear
// covers, from the tab, and never clears the whole of the user's profile.
// oracle: skip (cookie scope and the domain policy are hmux-defined)
// ---- cell session=cookieguard hmux-only
const outcome = async (f) => {
  try {
    await f();
    return "done";
  } catch (e) {
    if (e.code === "blocked" || /blocked/.test(e.message)) return "blocked";
    if (e.code === "closed" || /has been closed/.test(e.message)) return "closed";
    if (/profile/.test(e.message)) return "refused: profile";
    return `error: ${e.message}`;
  }
};
const peerHost = new URL(PEER).hostname;
const peerCookies = async () => (await page.context().cookies([`${PEER}/`])).map((c) => c.name).sort();
await page.goto(`${PRIMARY}/set-cookie`);
const primaryTab = page;
const peerTab = await tabs.open(`${PEER}/set-cookie`);
await tabs.use(primaryTab);
session.prohibitedDomains([PEER]);
emitHmux("get-blocked-url", await outcome(() => page.context().cookies([`${PEER}/`])));
emitHmux("get-hides-blocked-site", (await page.context().cookies()).filter((c) => String(c.domain).replace(/^\./, "") === peerHost).length);
emitHmux("set-blocked-site", await outcome(() => page.context().addCookies([{ name: "blocked", value: "1", url: `${PEER}/` }])));
// The narrowed policy may close the blocked tab; tabs.list() lets that close
// land. A clear through the tab then fails (blocked, or closed once the tab
// is gone) and never falls back to the current tab's site.
await tabs.list();
const clearBlocked = await outcome(() => peerTab.context().clearCookies());
emitHmux("clear-blocked-tab", clearBlocked === "blocked" || clearBlocked === "closed" ? "refused" : clearBlocked);
emitHmux("primary-kept-after-blocked-clear", (await page.context().cookies([`${PRIMARY}/`])).map((c) => c.name).sort());
session.prohibitedDomains(null);
emitHmux("peer-cookies-after-policy", await peerCookies());
// A runtime (or agent code calling the driver) names another site; the
// driver clears the target tab's own site instead.
await page._session.call("cookies.clear", { targetId: primaryTab._targetId, site: peerHost });
emitHmux("named-site-ignored", await peerCookies());
emitHmux("clear-all-profile", await outcome(() => page.context().clearCookies({ all: true })));
emitHmux("profile-kept-after-clear-all", await peerCookies());
await peerTab.close();
// A cookie set on a parent domain reaches every subdomain, so with one host
// allowed a cookie for its parent (and so its siblings) is refused; one for
// the allowed host itself is not.
session.allowedDomains(["https://www.parent.test"]);
emitHmux("set-parent-of-allowed", await outcome(() => page.context().addCookies([{ name: "wide", value: "1", domain: ".parent.test", path: "/" }])));
emitHmux("set-allowed-host", await outcome(() => page.context().addCookies([{ name: "narrow", value: "1", domain: "www.parent.test", path: "/" }])));
session.allowedDomains(null);
