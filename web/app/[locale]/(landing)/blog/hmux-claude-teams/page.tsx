import { useTranslations } from "next-intl";
import { getTranslations } from "next-intl/server";
import { buildAlternates, openGraphDefaults, seoDescription, twitterSummary } from "@/i18n/seo";
import { englishFallbackContentLocales } from "@/i18n/locale-availability";
import { BlogSchema } from "../blog-schema";
import { Link } from "@/i18n/navigation";
import { BlogPostMeta } from "@/app/[locale]/components/blog-author";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "blog.hmuxClaudeTeams" });
  const alternates = buildAlternates(
    locale,
    "/blog/hmux-claude-teams",
    englishFallbackContentLocales,
  );
  const title = t("metaTitle");
  const description = seoDescription(locale, t("metaDescription"));
  return {
    title,
    description,
    openGraph: {
      ...openGraphDefaults(locale, "article"),
      title,
      description,
      url: alternates.canonical,
      publishedTime: "2026-03-30T00:00:00Z",
    },
    twitter: twitterSummary(locale, title, description),
    alternates,
  };
}

export default function HmuxClaudeTeamsPage() {
  const t = useTranslations("blog.posts.hmuxClaudeTeams");
  const tc = useTranslations("common");

  return (
    <>
      <BlogSchema postKey="hmuxClaudeTeams" path="/blog/hmux-claude-teams" datePublished="2026-03-30T00:00:00Z" />
      <div className="mb-8">
        <Link
          href="/blog"
          className="text-sm text-muted hover:text-foreground transition-colors"
        >
          &larr; {tc("backToBlog")}
        </Link>
      </div>

      <h1>{t("title")}</h1>
      <BlogPostMeta date={t("date")} dateTime="2026-03-30" />

      <video
        src="/blog/hmux-claude-teams-demo.mp4"
        width={1824}
        height={1080}
        autoPlay
        loop
        muted
        playsInline
        className="mt-6 rounded-lg w-full h-auto"
      />

      <p className="mt-6">
        {t.rich("p1", {
          code: (chunks) => <code>{chunks}</code>,
          agentTeamsLink: (chunks) => (
            <a href="https://code.claude.com/docs/en/agent-teams">{chunks}</a>
          ),
        })}
      </p>
      <p>
        {t.rich("p2", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </p>
      <p>
        {t.rich("p3", {
          code: (chunks) => <code>{chunks}</code>,
          omoLink: (chunks) => (
            <Link href="/docs/agent-integrations/oh-my-opencode">{chunks}</Link>
          ),
        })}
      </p>

      <p className="mt-4">
        <Link href="/docs/agent-integrations/claude-code-teams">Read the docs &rarr;</Link>
      </p>
    </>
  );
}
