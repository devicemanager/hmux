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
    pageKey: "cloudCli",
    path: "/docs/cloud/cli",
  });
}

const linkClass =
  "underline underline-offset-2 decoration-link-underline hover:decoration-foreground transition-colors";

export default async function CloudCliPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "docs.cloudCli" });

  return (
    <>
      <DocsSchema namespace="docs.cloudCli" path="/docs/cloud/cli" />
      <DocsHeading level={1} id="title">{t("title")}</DocsHeading>
      <p>{t("intro")}</p>
      <p>{t("exitCodes")}</p>

      <DocsHeading level={2} id="auth">{t("authTitle")}</DocsHeading>
      <p>{t("authDesc")}</p>
      <CodeBlock lang="bash">{`hmux auth login
hmux auth status --json
hmux auth logout
hmux auth team list
hmux auth team use <team-id>`}</CodeBlock>

      <DocsHeading level={2} id="machines">{t("lifecycleTitle")}</DocsHeading>
      <p>{t("lifecycleDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm ls [--json]
hmux vm new [--size 4g|8g|16g|24g|32g|64g] [--name <label>] [--workspace <id>] [--window <id>] [--focus true|false] [--detach]
hmux vm base [open] [--detach]
hmux vm base reset [--reason <text>]
hmux vm status <id>
hmux vm stats <id>
hmux vm resize <id> [--cpu <vCPUs>] [--memory <GiB>] [--disk <GiB>]
hmux vm rename <id> <label> | --clear
hmux vm pause <id>
hmux vm resume <id>
hmux vm wait <id> [--timeout <seconds>] [--wake]
hmux vm tools <id>
hmux vm ports <id>
hmux vm rm <id>`}</CodeBlock>

      <DocsHeading level={2} id="checkpoints">{t("snapshotsTitle")}</DocsHeading>
      <p>{t("snapshotsDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm snapshot <id> [--name <name>]      # alias: checkpoint
hmux vm snapshot ls <id>
hmux vm snapshot rm <id> <snapshot-id>
hmux vm fork <id> [--name <name>] [--detach]
hmux vm restore <snapshot-id> [--detach]`}</CodeBlock>

      <DocsHeading level={2} id="open">{t("openTitle")}</DocsHeading>
      <p>{t("openDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm shell <id>                         # alias: attach
hmux vm tui <id>                           # full hmux TUI client
hmux vm desktop <id>                       # alias: vnc
hmux vm open <machine>[/<workspace>[/<terminal>[/<tab>]]] [--workspace <id>] [--focus true|false]
hmux vm open <machine>:desktop
hmux vm open <machine>:port/<n> [--print]
hmux vm open <machine> <port> [--print]`}</CodeBlock>

      <DocsHeading level={2} id="run">{t("runTitle")}</DocsHeading>
      <p>{t("runDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm exec [--timeout <seconds>] <id> -- <command...>
hmux vm run [--sync] [--pull <remote-path>] [--machine <id>] [--new] [--size <size>] [--timeout <seconds>] -- <command...>
hmux vm route [--cwd <dir>] [--new] [--provision] [--size <size>]
hmux vm agent --agent claude|codex|opencode|pi [--machine <id>] [--sync] [--cwd <dir>] [--name <name>] [--no-open] [--wait [--output] [--timeout <seconds>]] [--new] [--size <size>] -- <prompt>
hmux vm dev <machine> [<local-dir>] [--name <workspace>] [--layout <file>] [--command "<cmd>"] [--port <n>] [--remote <path>] [--sync|--no-sync] [--no-open] [--dry-run]
hmux vm prompt [--open claude|codex|opencode|pi]`}</CodeBlock>

      <DocsHeading level={2} id="workspaces">{t("workspacesTitle")}</DocsHeading>
      <p>{t("workspacesDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm tree [<machine>] [--refresh]
hmux vm workspace new <machine> [--name <name>] [--reuse] [--no-open]
hmux vm workspace open <machine> <workspace-id>
hmux vm workspace rename <machine> <workspace-id> <name>
hmux vm workspace close <machine> <workspace-id>   # terminals keep running
hmux vm workspace rm <machine> <workspace-id>      # terminals stop
hmux vm terminal send <machine> <terminal-id> [text] [--keys <k1,k2>]
hmux vm terminal read <machine> <terminal-id>
hmux vm terminal wait <machine> <terminal-id> --pattern <regex> [--timeout <seconds>]
hmux vm terminal wait-exit <machine> <terminal-id> [--timeout <seconds>]
hmux vm terminal output <machine> <terminal-id> [--after <offset>] [--max-bytes <n>]
hmux vm terminal rename <machine> <terminal-id> <name>
hmux vm terminal close <machine> <terminal-id>
hmux vm layout export <machine> [<workspace>]
hmux vm layout apply <machine> <file>|- [--name <name>] [--cwd <dir>] [--open]`}</CodeBlock>

      <DocsHeading level={2} id="files">{t("filesTitle")}</DocsHeading>
      <p>{t("filesDesc")}</p>
      <CodeBlock lang="bash">{`hmux vm push <id> <local-path> [remote-path] [--exclude <pattern>]... [--no-default-excludes] [--watch]
hmux vm push --secret <id> <local-file> [remote-path] [--mode <octal>]
hmux vm pull <id> <remote-path> [local-path]
hmux vm env set <machine> KEY=VALUE... | --from-file <.env> | -
hmux vm env ls <machine> [--show]
hmux vm env rm <machine> KEY...`}</CodeBlock>

      <DocsHeading level={2} id="domains">{t("domainsTitle")}</DocsHeading>
      <p>{t("domainsDesc")}</p>
      <CodeBlock lang="bash">{`hmux cloud domains [list]
hmux cloud domains zones
hmux cloud domains verify <domain>
hmux cloud domains publish <vm> <port> [--domain <hostname>] [--access personal|team|public] [--team <id>] [--yes]
hmux cloud domains access <hostname> personal|team|public [--yes]
hmux cloud domains grant <hostname> <email> [--expires <ISO-date>]
hmux cloud domains ungrant <hostname> <email>
hmux cloud domains grants <hostname>
hmux cloud domains rm <hostname>`}</CodeBlock>

      <DocsHeading level={2} id="vpn">{t("vpnTitle")}</DocsHeading>
      <p>{t("vpnDesc")}</p>
      <CodeBlock lang="bash">{`hmux vpn up
hmux vpn status
hmux vpn down
hmux vpn revoke`}</CodeBlock>

      <DocsHeading level={2} id="ai-accounts">{t("accountsTitle")}</DocsHeading>
      <p>{t("accountsDesc")}</p>
      <CodeBlock lang="bash">{`hmux ai-accounts list
hmux ai-accounts upload claude|codex|anthropic-key|openai-key [--label <label>] [--team <id>]
hmux coderouter status
hmux coderouter machines`}</CodeBlock>
      <p><Link href="/docs/coderouter/cli" className={linkClass}>{t("coderouterLink")}</Link></p>

      <DocsHeading level={2} id="scripting-checklist">{t("preflightTitle")}</DocsHeading>
      <p>{t("preflightDesc")}</p>
      <CodeBlock lang="bash">{`hmux auth status
hmux vm ls --json
hmux vm route --json`}</CodeBlock>
    </>
  );
}
