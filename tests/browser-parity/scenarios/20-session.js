// One-shot runs close their tabs unless kept; named sessions keep bindings
// and tabs across calls.
// oracle: skip (session lifetime is hmux-defined)
await page.goto(`${PRIMARY}/aria.html?oneshot`);
const kept = await tabs.open(`${PRIMARY}/dynamic.html?kept`);
await kept.keep();
await tabs.open(`${PRIMARY}/dynamic.html?closed`, { background: true });
emitHmux("open-during-run", (await tabs.list()).filter((t) => t.url.startsWith(PRIMARY)).map((t) => t.url).sort());
// ---- cell
emitHmux("after-one-shot", (await tabs.list()).filter((t) => t.url.startsWith(PRIMARY)).map((t) => t.url).sort());
const keptTab = (await tabs.list()).find((t) => t.url.endsWith("?kept"));
await tabs.use(keptTab.id);
emitHmux("attach-kept", await page.title());
await page.close();
// ---- cell session=work
emitHmux("session-name", await session.name("parity work"));
emitHmux("guide", /snapshot\(/.test(session.guide()));
const counter = { n: 1 };
let label = "first";
await page.goto(`${PRIMARY}/aria.html?named`);
// ---- cell session=work
counter.n++;
emitHmux("bindings-persist", [counter.n, label]);
emitHmux("page-persists", page.url().endsWith("?named"));
function helper() { return counter.n * 10; }
// ---- cell session=work
emitHmux("functions-persist", helper());
emitHmux("session-id", typeof session.id);
// ---- cell
emitHmux("named-tabs-open", (await tabs.list()).filter((t) => t.url.startsWith(PRIMARY)).map((t) => t.url).sort());
