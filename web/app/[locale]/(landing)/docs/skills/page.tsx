import { useTranslations } from "next-intl";
import { auditedDocsMetadata } from "../audited-docs-metadata";
import { DocsSchema } from "../docs-schema";
import { DocsLink as Link } from "@/app/[locale]/components/docs-link";
import { CodeBlock } from "@/app/[locale]/components/code-block";
import { Callout } from "@/app/[locale]/components/callout";
import { DocsHeading } from "@/app/[locale]/components/docs-heading";

const skills = [
  {
    id: "hmux",
    path: "skills/hmux/SKILL.md",
    command: "hmux identify --json",
    nameKey: "hmuxName",
    descriptionKey: "hmuxDescription",
    useKey: "hmuxUse",
  },
  {
    id: "hmux-workspace",
    path: "skills/hmux-workspace/SKILL.md",
    command: "hmux current-workspace --json",
    nameKey: "workspaceName",
    descriptionKey: "workspaceDescription",
    useKey: "workspaceUse",
  },
  {
    id: "hmux-settings",
    path: "skills/hmux-settings/SKILL.md",
    command: "skills/hmux-settings/scripts/hmux-settings list-supported",
    nameKey: "settingsName",
    descriptionKey: "settingsDescription",
    useKey: "settingsUse",
  },
  {
    id: "hmux-customization",
    path: "skills/hmux-customization/SKILL.md",
    command: "hmux reload-config",
    nameKey: "customizationName",
    descriptionKey: "customizationDescription",
    useKey: "customizationUse",
  },
  {
    id: "hmux-diagnostics",
    path: "skills/hmux-diagnostics/SKILL.md",
    command: "skills/hmux-diagnostics/scripts/hmux-diagnostics",
    nameKey: "diagnosticsName",
    descriptionKey: "diagnosticsDescription",
    useKey: "diagnosticsUse",
  },
  {
    id: "hmux-browser",
    path: "skills/hmux-browser/SKILL.md",
    command: "hmux browser surface:2 snapshot --interactive",
    nameKey: "browserName",
    descriptionKey: "browserDescription",
    useKey: "browserUse",
  },
  {
    id: "hmux-markdown",
    path: "skills/hmux-markdown/SKILL.md",
    command: "hmux markdown open plan.md",
    nameKey: "markdownName",
    descriptionKey: "markdownDescription",
    useKey: "markdownUse",
  },
] as const;

const skillCoverage = [
  {
    id: "hmux",
    nameKey: "hmuxName",
    scopeKey: "hmuxScope",
    referencesKey: "hmuxReferences",
  },
  {
    id: "hmux-workspace",
    nameKey: "workspaceName",
    scopeKey: "workspaceScope",
    referencesKey: "workspaceReferences",
  },
  {
    id: "hmux-settings",
    nameKey: "settingsName",
    scopeKey: "settingsScope",
    referencesKey: "settingsReferences",
  },
  {
    id: "hmux-customization",
    nameKey: "customizationName",
    scopeKey: "customizationScope",
    referencesKey: "customizationReferences",
  },
  {
    id: "hmux-diagnostics",
    nameKey: "diagnosticsName",
    scopeKey: "diagnosticsScope",
    referencesKey: "diagnosticsReferences",
  },
  {
    id: "hmux-browser",
    nameKey: "browserName",
    scopeKey: "browserScope",
    referencesKey: "browserReferences",
  },
  {
    id: "hmux-markdown",
    nameKey: "markdownName",
    scopeKey: "markdownScope",
    referencesKey: "markdownReferences",
  },
] as const;

const suggestedSkills = [
  {
    id: "hmux-ssh",
    nameKey: "suggestSshName",
    useKey: "suggestSshUse",
    whyKey: "suggestSshWhy",
  },
  {
    id: "hmux-cloud-vm",
    nameKey: "suggestCloudVmName",
    useKey: "suggestCloudVmUse",
    whyKey: "suggestCloudVmWhy",
  },
  {
    id: "hmux-vault",
    nameKey: "suggestVaultName",
    useKey: "suggestVaultUse",
    whyKey: "suggestVaultWhy",
  },
] as const;

const customizationExamples = [
  {
    id: "worktree-agents",
    nameKey: "exampleWorktreeName",
    surfaceKey: "exampleWorktreeSurface",
    useKey: "exampleWorktreeUse",
  },
  {
    id: "full-stack-dev",
    nameKey: "exampleFullStackName",
    surfaceKey: "exampleFullStackSurface",
    useKey: "exampleFullStackUse",
  },
  {
    id: "ssh-devbox",
    nameKey: "exampleSshName",
    surfaceKey: "exampleSshSurface",
    useKey: "exampleSshUse",
  },
  {
    id: "review-pr",
    nameKey: "exampleReviewName",
    surfaceKey: "exampleReviewSurface",
    useKey: "exampleReviewUse",
  },
  {
    id: "docs-workspace",
    nameKey: "exampleDocsName",
    surfaceKey: "exampleDocsSurface",
    useKey: "exampleDocsUse",
  },
  {
    id: "ci-watch",
    nameKey: "exampleCiName",
    surfaceKey: "exampleCiSurface",
    useKey: "exampleCiUse",
  },
  {
    id: "quick-agent-buttons",
    nameKey: "exampleAgentButtonsName",
    surfaceKey: "exampleAgentButtonsSurface",
    useKey: "exampleAgentButtonsUse",
  },
] as const;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  return auditedDocsMetadata({
    locale,
    pageKey: "skills",
    path: "/docs/skills",
  });
}

export default function SkillsPage() {
  const t = useTranslations("docs.skills");

  return (
    <>
      <DocsSchema namespace="docs.skills" path="/docs/skills" />
      <DocsHeading level={1} id="title">{t("title")}</DocsHeading>
      <p>{t("intro")}</p>

      <DocsHeading level={2} id="install-title">{t("installTitle")}</DocsHeading>
      <p>
        {t.rich("installIntro", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </p>
      <CodeBlock title={t("installWithVercel")} lang="bash">{`# Install all hmux skills
npx skills add manaflow-ai/cmux -g -y

# Or install just diagnostics
npx skills add manaflow-ai/cmux --skill hmux-diagnostics -g -y`}</CodeBlock>
      <CodeBlock title={t("installWithSkillsSh")} lang="bash">{`curl -fsSL https://raw.githubusercontent.com/manaflow-ai/cmux/main/skills.sh | bash`}</CodeBlock>
      <Callout type="info">
        {t.rich("installDestination", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </Callout>

      <DocsHeading level={3} id="local-install-title">{t("localInstallTitle")}</DocsHeading>
      <p>{t("localInstallIntro")}</p>
      <CodeBlock title={t("localInstallCommands")} lang="bash">{`./skills.sh
./skills.sh --list
./skills.sh --skill hmux --skill hmux-browser
./skills.sh --dest ~/.codex/skills
./skills.sh --dry-run`}</CodeBlock>
      <p>{t("pinRefIntro")}</p>
      <CodeBlock lang="bash">{`curl -fsSL https://raw.githubusercontent.com/manaflow-ai/cmux/main/skills.sh | bash -s -- --ref main`}</CodeBlock>

      <DocsHeading level={2} id="included-title">{t("includedTitle")}</DocsHeading>
      <p>{t("includedIntro")}</p>
      <table>
        <thead>
          <tr>
            <th>{t("skillHeader")}</th>
            <th>{t("useHeader")}</th>
            <th>{t("commandHeader")}</th>
          </tr>
        </thead>
        <tbody>
          {skills.map((skill) => (
            <tr key={skill.id}>
              <td>
                <strong>{t(skill.nameKey)}</strong>
                <br />
                <code>{skill.path}</code>
              </td>
              <td>
                <p>{t(skill.descriptionKey)}</p>
                <p>{t(skill.useKey)}</p>
              </td>
              <td>
                <code>{skill.command}</code>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <DocsHeading level={2} id="coverage-title">{t("coverageTitle")}</DocsHeading>
      <p>{t("coverageIntro")}</p>
      <table>
        <thead>
          <tr>
            <th>{t("skillHeader")}</th>
            <th>{t("scopeHeader")}</th>
            <th>{t("referencesHeader")}</th>
          </tr>
        </thead>
        <tbody>
          {skillCoverage.map((skill) => (
            <tr key={skill.id}>
              <td>
                <strong>{t(skill.nameKey)}</strong>
                <br />
                <code>{skill.id}</code>
              </td>
              <td>{t(skill.scopeKey)}</td>
              <td>{t(skill.referencesKey)}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <DocsHeading level={2} id="customization-examples-title">{t("customizationExamplesTitle")}</DocsHeading>
      <p>{t("customizationExamplesIntro")}</p>
      <table>
        <thead>
          <tr>
            <th>{t("exampleHeader")}</th>
            <th>{t("exampleSurfaceHeader")}</th>
            <th>{t("exampleUseHeader")}</th>
          </tr>
        </thead>
        <tbody>
          {customizationExamples.map((example) => (
            <tr key={example.id}>
              <td>
                <strong>{t(example.nameKey)}</strong>
                <br />
                <code>{example.id}</code>
              </td>
              <td>{t(example.surfaceKey)}</td>
              <td>{t(example.useKey)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <Callout type="info">
        {t.rich("customizationExamplesCallout", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </Callout>
      <CodeBlock title={t("customizationExamplePrompts")} lang="text">{[
        t("customizationPromptWorktree"),
        t("customizationPromptFullStack"),
        t("customizationPromptAgentButtons"),
      ].join("\n")}</CodeBlock>

      <DocsHeading level={2} id="help-menu-title">{t("helpMenuTitle")}</DocsHeading>
      <p>
        {t.rich("helpMenuIntro", {
          help: (chunks) => <strong>{chunks}</strong>,
          skills: (chunks) => <strong>{chunks}</strong>,
        })}
      </p>

      <DocsHeading level={2} id="authoring-title">{t("authoringTitle")}</DocsHeading>
      <p>{t("authoringIntro")}</p>
      <CodeBlock lang="text">{`skills/<name>/SKILL.md
skills/<name>/agents/openai.yaml
skills/<name>/references/*.md
skills/<name>/scripts/*
skills/<name>/templates/*`}</CodeBlock>
      <Callout>
        {t.rich("authoringCallout", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </Callout>

      <DocsHeading level={2} id="suggestions-title">{t("suggestionsTitle")}</DocsHeading>
      <p>{t("suggestionsIntro")}</p>
      <table>
        <thead>
          <tr>
            <th>{t("suggestionHeader")}</th>
            <th>{t("suggestionUseHeader")}</th>
            <th>{t("suggestionWhyHeader")}</th>
          </tr>
        </thead>
        <tbody>
          {suggestedSkills.map((skill) => (
            <tr key={skill.id}>
              <td>
                <strong>{t(skill.nameKey)}</strong>
                <br />
                <code>{skill.id}</code>
              </td>
              <td>{t(skill.useKey)}</td>
              <td>{t(skill.whyKey)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <Callout type="info">{t("suggestionsCallout")}</Callout>

      <DocsHeading level={2} id="related-title">{t("relatedTitle")}</DocsHeading>
      <ul>
        <li>
          <Link href="/docs/browser-automation">{t("relatedBrowserAutomation")}</Link>
        </li>
        <li>
          <Link href="/docs/api">{t("relatedApi")}</Link>
        </li>
        <li>
          <Link href="/docs/custom-commands">{t("relatedCustomCommands")}</Link>
        </li>
      </ul>
    </>
  );
}
