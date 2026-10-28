import { useTranslations } from "next-intl";
import { auditedDocsMetadata } from "../audited-docs-metadata";
import { DocsSchema } from "../docs-schema";
import { CodeBlock } from "@/app/[locale]/components/code-block";
import { DocsHeading } from "@/app/[locale]/components/docs-heading";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  return auditedDocsMetadata({
    locale,
    pageKey: "browserAutomation",
    path: "/docs/browser-automation",
  });
}

export default function BrowserAutomationPage() {
  const t = useTranslations("docs.browserAutomation");

  return (
    <>
      <DocsSchema namespace="docs.browserAutomation" path="/docs/browser-automation" />
      <DocsHeading level={1} id="title">{t("title")}</DocsHeading>
      <p>{t("intro")}</p>

      <DocsHeading level={2} id="command-index">{t("commandIndex")}</DocsHeading>
      <table>
        <thead>
          <tr>
            <th>{t("categoryHeader")}</th>
            <th>{t("subcommandsHeader")}</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>{t("navAndTargeting")}</td>
            <td>
              <code>identify</code>, <code>open</code>, <code>open-split</code>,{" "}
              <code>navigate</code>, <code>back</code>, <code>forward</code>,{" "}
              <code>reload</code>, <code>url</code>, <code>focus-webview</code>,{" "}
              <code>is-webview-focused</code>, <code>zoom</code>,{" "}
              <code>focus-mode</code>, <code>react-grab</code>, <code>devtools</code>
            </td>
          </tr>
          <tr>
            <td>{t("waiting")}</td>
            <td>
              <code>wait</code>
            </td>
          </tr>
          <tr>
            <td>{t("domInteraction")}</td>
            <td>
              <code>click</code>, <code>dblclick</code>, <code>hover</code>,{" "}
              <code>focus</code>, <code>check</code>, <code>uncheck</code>,{" "}
              <code>scroll-into-view</code>, <code>type</code>, <code>fill</code>,{" "}
              <code>press</code>, <code>keydown</code>, <code>keyup</code>,{" "}
              <code>select</code>, <code>scroll</code>
            </td>
          </tr>
          <tr>
            <td>{t("inspection")}</td>
            <td>
              <code>snapshot</code>, <code>screenshot</code>, <code>get</code>,{" "}
              <code>is</code>, <code>find</code>, <code>highlight</code>
            </td>
          </tr>
          <tr>
            <td>{t("jsAndInjection")}</td>
            <td>
              <code>eval</code>, <code>addinitscript</code>, <code>addscript</code>,{" "}
              <code>addstyle</code>
            </td>
          </tr>
          <tr>
            <td>{t("framesDialogsDownloads")}</td>
            <td>
              <code>frame</code>, <code>dialog</code>, <code>download</code>
            </td>
          </tr>
          <tr>
            <td>{t("stateAndSession")}</td>
            <td>
              <code>cookies</code>, <code>storage</code>, <code>state</code>,{" "}
              <code>history</code>
            </td>
          </tr>
          <tr>
            <td>{t("tabsAndLogs")}</td>
            <td>
              <code>tab</code>, <code>console</code>, <code>errors</code>
            </td>
          </tr>
        </tbody>
      </table>

      <DocsHeading level={2} id="targeting-surface">{t("targetingSurface")}</DocsHeading>
      <p>{t("targetingDesc")}</p>
      <CodeBlock lang="bash">{`# Open a new browser split
hmux browser open https://example.com

# Discover focused IDs and browser metadata
hmux browser identify
hmux browser identify --surface surface:2

# Positional vs flag targeting are equivalent
hmux browser surface:2 url
hmux browser --surface surface:2 url`}</CodeBlock>

      <DocsHeading level={2} id="navigation">{t("navigation")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser open https://example.com
hmux browser open-split https://news.ycombinator.com

hmux browser surface:2 navigate https://example.org/docs --snapshot-after
hmux browser surface:2 back
hmux browser surface:2 forward
hmux browser surface:2 reload --snapshot-after
hmux browser surface:2 url

hmux browser surface:2 focus-webview
hmux browser surface:2 is-webview-focused

hmux browser react-grab toggle
hmux browser devtools toggle
hmux browser devtools console
hmux browser focus-mode toggle
hmux browser zoom in
hmux browser zoom reset
hmux browser history clear --force`}</CodeBlock>

      <DocsHeading level={2} id="waiting-section">{t("waitingSection")}</DocsHeading>
      <p>{t("waitingDesc")}</p>
      <CodeBlock lang="bash">{`hmux browser surface:2 wait --load-state complete --timeout-ms 15000
hmux browser surface:2 wait --selector "#checkout" --timeout-ms 10000
hmux browser surface:2 wait --text "Order confirmed"
hmux browser surface:2 wait --url-contains "/dashboard"
hmux browser surface:2 wait --function "window.__appReady === true"`}</CodeBlock>

      <DocsHeading level={2} id="dom-section">{t("domSection")}</DocsHeading>
      <p>{t("domDesc")}</p>
      <CodeBlock lang="bash">{`hmux browser surface:2 click "button[type='submit']" --snapshot-after
hmux browser surface:2 dblclick ".item-row"
hmux browser surface:2 hover "#menu"
hmux browser surface:2 focus "#email"
hmux browser surface:2 check "#terms"
hmux browser surface:2 uncheck "#newsletter"
hmux browser surface:2 scroll-into-view "#pricing"

hmux browser surface:2 type "#search" "hmux"
hmux browser surface:2 fill "#email" --text "ops@example.com"
hmux browser surface:2 fill "#email" --text ""
hmux browser surface:2 press Enter
hmux browser surface:2 keydown Shift
hmux browser surface:2 keyup Shift
hmux browser surface:2 select "#region" "us-east"
hmux browser surface:2 scroll --dy 800 --snapshot-after
hmux browser surface:2 scroll --selector "#log-view" --dx 0 --dy 400`}</CodeBlock>

      <DocsHeading level={2} id="inspection-section">{t("inspectionSection")}</DocsHeading>
      <p>{t("inspectionDesc")}</p>
      <CodeBlock lang="bash">{`hmux browser surface:2 snapshot --interactive --compact
hmux browser surface:2 snapshot --selector "main" --max-depth 5
hmux browser surface:2 screenshot --out /tmp/hmux-page.png

hmux browser surface:2 get title
hmux browser surface:2 get url
hmux browser surface:2 get text "h1"
hmux browser surface:2 get html "main"
hmux browser surface:2 get value "#email"
hmux browser surface:2 get attr "a.primary" --attr href
hmux browser surface:2 get count ".row"
hmux browser surface:2 get box "#checkout"
hmux browser surface:2 get styles "#total" --property color

hmux browser surface:2 is visible "#checkout"
hmux browser surface:2 is enabled "button[type='submit']"
hmux browser surface:2 is checked "#terms"

hmux browser surface:2 find role button --name "Continue"
hmux browser surface:2 find text "Order confirmed"
hmux browser surface:2 find label "Email"
hmux browser surface:2 find placeholder "Search"
hmux browser surface:2 find alt "Product image"
hmux browser surface:2 find title "Open settings"
hmux browser surface:2 find testid "save-btn"
hmux browser surface:2 find first ".row"
hmux browser surface:2 find last ".row"
hmux browser surface:2 find nth 2 ".row"

hmux browser surface:2 highlight "#checkout"`}</CodeBlock>

      <DocsHeading level={2} id="js-section">{t("jsSection")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser surface:2 eval "document.title"
hmux browser surface:2 eval --script "window.location.href"

hmux browser surface:2 addinitscript "window.__hmuxReady = true;"
hmux browser surface:2 addscript "document.querySelector('#name')?.focus()"
hmux browser surface:2 addstyle "#debug-banner { display: none !important; }"`}</CodeBlock>

      <DocsHeading level={2} id="state-section">{t("stateSection")}</DocsHeading>
      <p>{t("stateDesc")}</p>
      <CodeBlock lang="bash">{`hmux browser surface:2 cookies get
hmux browser surface:2 cookies get --name session_id
hmux browser surface:2 cookies set session_id abc123 --domain example.com --path /
hmux browser surface:2 cookies clear --name session_id
hmux browser surface:2 cookies clear --all

hmux browser surface:2 storage local set theme dark
hmux browser surface:2 storage local get theme
hmux browser surface:2 storage local clear
hmux browser surface:2 storage session set flow onboarding
hmux browser surface:2 storage session get flow

hmux browser surface:2 state save /tmp/hmux-browser-state.json
hmux browser surface:2 state load /tmp/hmux-browser-state.json`}</CodeBlock>

      <DocsHeading level={2} id="tabs-section">{t("tabsSection")}</DocsHeading>
      <p>{t("tabsDesc")}</p>
      <CodeBlock lang="bash">{`hmux browser surface:2 tab list
hmux browser surface:2 tab new https://example.com/pricing

# Switch by index or by target surface
hmux browser surface:2 tab switch 1
hmux browser surface:2 tab switch surface:7

# Close current tab or a specific target
hmux browser surface:2 tab close
hmux browser surface:2 tab close surface:7`}</CodeBlock>

      <DocsHeading level={2} id="console-section">{t("consoleSection")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser surface:2 console list
hmux browser surface:2 console clear

hmux browser surface:2 errors list
hmux browser surface:2 errors clear`}</CodeBlock>

      <DocsHeading level={2} id="dialogs-section">{t("dialogsSection")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser surface:2 dialog accept
hmux browser surface:2 dialog accept "Confirmed by automation"
hmux browser surface:2 dialog dismiss`}</CodeBlock>

      <DocsHeading level={2} id="frames-section">{t("framesSection")}</DocsHeading>
      <CodeBlock lang="bash">{`# Enter an iframe context
hmux browser surface:2 frame "iframe[name='checkout']"
hmux browser surface:2 click "#pay-now"

# Return to the top-level document
hmux browser surface:2 frame main`}</CodeBlock>

      <DocsHeading level={2} id="downloads-section">{t("downloadsSection")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser surface:2 click "a#download-report"
hmux browser surface:2 download --path /tmp/report.csv --timeout-ms 30000
hmux browser surface:2 download list --limit 5 --json`}</CodeBlock>

      <DocsHeading level={2} id="common-patterns">{t("commonPatterns")}</DocsHeading>

      <DocsHeading level={3} id="pattern-navigate">{t("patternNavigate")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser open https://example.com/login
hmux browser surface:2 wait --load-state complete --timeout-ms 15000
hmux browser surface:2 snapshot --interactive --compact
hmux browser surface:2 get title`}</CodeBlock>

      <DocsHeading level={3} id="pattern-form">{t("patternForm")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser surface:2 fill "#email" --text "ops@example.com"
hmux browser surface:2 fill "#password" --text "$PASSWORD"
hmux browser surface:2 click "button[type='submit']" --snapshot-after
hmux browser surface:2 wait --text "Welcome"
hmux browser surface:2 is visible "#dashboard"`}</CodeBlock>

      <DocsHeading level={3} id="pattern-debug">{t("patternDebug")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser surface:2 console list
hmux browser surface:2 errors list
hmux browser surface:2 screenshot --out /tmp/hmux-failure.png
hmux browser surface:2 snapshot --interactive --compact`}</CodeBlock>

      <DocsHeading level={3} id="pattern-session">{t("patternSession")}</DocsHeading>
      <CodeBlock lang="bash">{`hmux browser surface:2 state save /tmp/session.json
# ...later...
hmux browser surface:2 state load /tmp/session.json
hmux browser surface:2 reload`}</CodeBlock>
    </>
  );
}
