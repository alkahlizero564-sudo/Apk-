// Opens a prepared HTML app (www/index.html) in headless Chrome like the phone will, and fails on JavaScript
// errors (a broken script still builds an APK, but the app would be broken). Usage: node check_html.js <www>
// Needs playwright-core (NODE_PATH) and Chrome (CHROME_PATH or the runner's google-chrome).
const path = require("path");
const fs = require("fs");

(async () => {
  const dir = path.resolve(process.argv[2] || "www");
  const index = path.join(dir, "index.html");
  if (!fs.existsSync(index)) {
    console.error("index.html missing");
    process.exit(1);
  }
  // Syntax check of every script first (works without a browser).
  const vm = require("vm");
  let bad = 0;
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".js"))) {
    try {
      new vm.Script(fs.readFileSync(path.join(dir, f), "utf8"), { filename: f });
    } catch (e) {
      console.error(`${f}: ${e.message}`);
      bad++;
    }
  }
  if (bad) process.exit(1);
  let chromium;
  try {
    ({ chromium } = require("playwright-core"));
  } catch (e) {
    console.log("playwright-core not installed: syntax check only (OK)");
    return;
  }
  const exe = process.env.CHROME_PATH || ["/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser"].find((p) => fs.existsSync(p));
  if (!exe) {
    console.log("No Chrome found: syntax check only (OK)");
    return;
  }
  const browser = await chromium.launch({ executablePath: exe, args: ["--no-sandbox"] });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => {
    if (m.type() === "error" && !/Failed to load resource|net::ERR|fetch/i.test(m.text())) errors.push(m.text());
  });
  await page.goto("file://" + index);
  await page.waitForTimeout(2500);
  // Click through the bottom tabs: each screen must render without errors.
  const tabs = await page.$$("[data-tab]");
  for (let i = 0; i < tabs.length; i++) {
    const t = (await page.$$("[data-tab]"))[i];
    if (t) await t.click().catch(() => {});
    await page.waitForTimeout(400);
  }
  await browser.close();
  if (errors.length) {
    console.error("JavaScript errors:\n" + errors.join("\n"));
    process.exit(1);
  }
  console.log(`HTML check OK (${tabs.length} tabs opened, no JavaScript errors)`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
