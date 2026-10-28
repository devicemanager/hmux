// Ref identity: a ref names one DOM node for the node's life. It survives a
// name change and moves, is never reused, fails fast once the node is gone,
// and never rebinds to another element.
// oracle: skip (ref identity is hmux-defined)
await page.goto(`${PRIMARY}/`);
await page.evaluate(() => {
  document.body.innerHTML = '<ul id=L><li><button id=a>Alpha</button></li><li><button id=b>Beta</button></li></ul><button id=out onclick="this.textContent=\'Out clicked\'">Out</button>';
});
const s1 = await snapshot({ interactive: true });
emitHmux("s1", s1.tree);
await page.evaluate(() => {
  document.getElementById("b").textContent = "Beta renamed";
  document.getElementById("L").insertAdjacentHTML("afterbegin", "<li><button>Zero</button></li>");
  document.getElementById("a").remove();
});
const s2 = await snapshot({ interactive: true });
emitHmux("s2", s2.tree);
emitHmux("s2-printed", String(s2));
const stale = async (ref) => {
  try {
    await page.locator(ref).click({ timeout: 2000 });
    return "clicked";
  } catch (e) {
    return e.message;
  }
};
emitHmux("removed", await stale("e1"));
emitHmux("unknown", await stale("e99"));
emitHmux("unknown-frame", await stale("f9e1"));
await page.evaluate(() => document.getElementById("L").append(document.getElementById("out")));
await page.locator("e3").click();
emitHmux("moved-still-works", await page.locator("#out").textContent());
emitHmux("renamed-still-works", await page.ref("e2").textContent());
await page.evaluate(() => { document.getElementById("L").insertAdjacentHTML("beforeend", "<li><button>New</button></li>"); });
emitHmux("never-reused", (await snapshot({ interactive: true })).tree.match(/button "New" \[ref=(\w+)\]/)[1]);
emitHmux("scoped", (await snapshot("e2")).tree);
emitHmux("not-invalidated-by-scope", await page.locator("e3").textContent());
try {
  page.ref("button");
  emitHmux("ref-validates", "no error");
} catch (e) {
  emitHmux("ref-validates", e.message);
}
emitHmux("is-visible-stale", await page.locator("e1").isVisible());
await page.goto(`${PRIMARY}/`);
emitHmux("after-navigation", await stale("e2"));
emitHmux("new-document-continues", (await snapshot({ interactive: true })).tree.match(/\[ref=(e\d+)\]/)[1]);
