// A file chooser without a listener stays open: the snapshot shows it with
// the ref of its input, and page.fileChooser() answers it.
// oracle: skip (without a listener Playwright opens no chooser to hold)
await page.goto(`${PRIMARY}/files.html`);
await page.locator("#picker").click();
emitHmux("snapshot", (await snapshot()).tree);
const c = page.fileChooser();
emitHmux("multiple", c.multiple);
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "parity-"));
fs.writeFileSync(path.join(dir, "held.txt"), "held file");
await c.setFiles(path.join(dir, "held.txt"));
await page.waitForFunction(() => document.getElementById("files").textContent.startsWith("hidden-file:"));
emitHmux("set", await page.locator("#files").textContent());
emitHmux("answered", page.fileChooser());
await page.locator("#many").click();
emitHmux("many-line", (await snapshot()).tree.split("\n")[2]);
emitHmux("many-multiple", page.fileChooser().multiple);
await page.fileChooser().cancel();
emitHmux("cancelled", page.fileChooser());
emitHmux("unchanged", await page.locator("#files").textContent());
try {
  await c.setFiles(path.join(dir, "held.txt"));
  emitHmux("answer-twice", "no error");
} catch (e) {
  emitHmux("answer-twice", e.message);
}
fs.rmSync(dir, { recursive: true, force: true });
