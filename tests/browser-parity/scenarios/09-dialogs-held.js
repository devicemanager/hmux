// Dialogs without a listener stay open: the snapshot shows them, page script
// calls fail with the way out, and page.dialog() answers them.
// oracle: skip (Playwright dismisses dialogs nobody listens for)
await page.goto(`${PRIMARY}/dialogs.html`);
await page.locator("#confirm").click();
emitHmux("snapshot", (await snapshot()).tree);
const d = page.dialog();
emitHmux("dialog", { type: d.type, message: d.message, defaultValue: d.defaultValue });
try {
  await page.locator("#r").textContent();
  emitHmux("blocked", "no error");
} catch (e) {
  emitHmux("blocked", e.message);
}
try {
  await page.evaluate(() => 1);
  emitHmux("blocked-evaluate", "no error");
} catch (e) {
  emitHmux("blocked-evaluate", e.message);
}
await d.accept();
emitHmux("after-accept", await page.locator("#r").textContent());
emitHmux("closed", page.dialog());
await page.locator("#prompt").click();
emitHmux("prompt-line", (await snapshot()).tree.split("\n")[2]);
await page.dialog().accept("from agent");
emitHmux("after-prompt", await page.locator("#r").textContent());
await page.locator("#prompt").click();
await page.dialog().dismiss();
emitHmux("prompt-dismissed", await page.locator("#r").textContent());
await page.locator("#alert").focus();
await page.keyboard.press("Enter");
emitHmux("keyboard-opened", page.dialog() && page.dialog().type);
await page.dialog().dismiss();
emitHmux("after-alert", await page.locator("#r").textContent());
await page.evaluate(() => setTimeout(() => confirm("Later"), 50));
await page.waitForTimeout(300);
emitHmux("timer-dialog", page.dialog() && page.dialog().message);
await page.dialog().dismiss();
emitHmux("after-timer", (await snapshot()).tree.split("\n").length > 2);
