import { getTranslations } from "next-intl/server";
import { auditedDocsMetadata } from "../../audited-docs-metadata";
import { DocsSchema } from "../../docs-schema";
import { CodeBlock } from "@/app/[locale]/components/code-block";
import { DocsHeading } from "@/app/[locale]/components/docs-heading";
import { DocsLink as Link } from "@/app/[locale]/components/docs-link";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  return auditedDocsMetadata({
    locale,
    pageKey: "cloudWorkspaces",
    path: "/docs/cloud/workspaces",
  });
}

const linkClass =
  "underline underline-offset-2 decoration-link-underline hover:decoration-foreground transition-colors";

export default async function CloudWorkspacesPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "docs.cloudWorkspaces" });

  return (
    <>
      <DocsSchema namespace="docs.cloudWorkspaces" path="/docs/cloud/workspaces" />
      <DocsHeading level={1} id="title">{t("title")}</DocsHeading>
      <p>{t("intro")}</p>

      <DocsHeading level={2} id="durable-terminals">{t("durableTitle")}</DocsHeading>
      <p>{t("durableDesc")}</p>
      <p>{t("durableReconnect")}</p>
      <p>{t("durableRestart")}</p>
      <p>{t("closeVsRemove")}</p>

      <DocsHeading level={2} id="agents">{t("agentsTitle")}</DocsHeading>
      <p>{t("agentsDesc")}</p>
      <p>{t("agentCmdDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm agent --agent claude --machine brave-otter -- "add tests for the parser"
hmux vm agent --agent codex --machine brave-otter --sync --wait -- "fix the build"
hmux vm agent --agent opencode --new --size 16g -- "profile the importer"`}</CodeBlock>
      <p>{t("agentPromptDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm prompt --open claude`}</CodeBlock>

      <DocsHeading level={2} id="run-commands">{t("runTitle")}</DocsHeading>
      <p>{t("runDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm run -- npm test
hmux vm run --sync --pull dist -- npm run build
hmux vm route --json`}</CodeBlock>
      <p>{t("execDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm exec brave-otter -- uname -a
hmux vm exec --timeout 120 brave-otter -- docker ps`}</CodeBlock>

      <DocsHeading level={2} id="dev-server">{t("devTitle")}</DocsHeading>
      <p>{t("devDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm dev brave-otter --dry-run
hmux vm dev brave-otter . --port 3000`}</CodeBlock>

      <DocsHeading level={2} id="notifications">{t("notificationsTitle")}</DocsHeading>
      <p>{t("notificationsDesc")}</p>
      <CodeBlock lang="bash">{`# Inside a Cloud machine
hmux notify --title "Build" --body "Tests passed"`}</CodeBlock>

      <DocsHeading level={2} id="paste-images">{t("imagePasteTitle")}</DocsHeading>
      <p>{t("imagePasteDesc")}</p>

      <DocsHeading level={2} id="layouts">{t("layoutsTitle")}</DocsHeading>
      <p>{t("layoutsDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm tree brave-otter
hmux vm workspace new brave-otter --name review
hmux vm terminal send brave-otter term_2f9c "npm run dev" --keys enter
hmux vm terminal wait brave-otter term_2f9c --pattern "ready" --timeout 60
hmux vm terminal read brave-otter term_2f9c
hmux vm layout export brave-otter review > layout.json
hmux vm layout apply brave-otter layout.json --open`}</CodeBlock>

      <DocsHeading level={2} id="installed-tools">{t("imageTitle")}</DocsHeading>
      <p>{t("imageDesc")}</p>
      <ul>
        <li>{t("imageLanguages")}</li>
        <li>{t("imageBrowser")}</li>
        <li>{t("imageAgents")}</li>
      </ul>
      <p>{t("imageProvisionLog")}</p>

      <DocsHeading level={2} id="model-access">{t("modelsTitle")}</DocsHeading>
      <p>{t("modelsDesc")}</p>
      <CodeBlock lang="bash">{`hmux ai-accounts list
hmux ai-accounts upload claude
hmux coderouter status`}</CodeBlock>
      <p><Link href="/docs/coderouter" className={linkClass}>{t("coderouterLink")}</Link></p>

      <DocsHeading level={2} id="guest-cli">{t("guestTitle")}</DocsHeading>
      <p>{t("guestDesc")}</p>
      <CodeBlock lang="bash">{`# Inside a Cloud machine
hmux tree
hmux new-split right
hmux self peers
hmux vm exec calm-heron -- git status`}</CodeBlock>
      <p>{t("guestHostOnly")}</p>

      <DocsHeading level={2} id="iphone">{t("iosTitle")}</DocsHeading>
      <p>{t("iosDesc")}</p>
    </>
  );
}
