import { useLocale, useTranslations } from "next-intl";
import { getTranslations } from "next-intl/server";
import { buildAlternates, openGraphDefaults, twitterSummary } from "@/i18n/seo";
import { hmuxHistorySeoCopy } from "@/i18n/audited-seo";
import { BlogSchema } from "../blog-schema";
import { Link } from "@/i18n/navigation";
import { CodeBlock } from "@/app/[locale]/components/code-block";
import { BlogPostMeta } from "@/app/[locale]/components/blog-author";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "blog.hmuxHistory" });
  const post = await getTranslations({
    locale,
    namespace: "blog.posts.hmuxHistory",
  });
  const siteMeta = await getTranslations({ locale, namespace: "meta" });
  const alternates = buildAlternates(locale, "/blog/hmux-history");
  const { title, description } = hmuxHistorySeoCopy(
    locale,
    t,
    post,
    siteMeta,
  );
  return {
    title: { absolute: title },
    description,
    openGraph: {
      ...openGraphDefaults(locale, "article"),
      title,
      description,
      url: alternates.canonical,
      publishedTime: "2026-06-02T00:00:00Z",
    },
    twitter: twitterSummary(locale, title, description),
    alternates,
  };
}

export default function HmuxHistoryBlogPage() {
  const t = useTranslations("blog.posts.hmuxHistory");
  const tm = useTranslations("blog.hmuxHistory");
  const siteMeta = useTranslations("meta");
  const tc = useTranslations("common");
  const locale = useLocale();
  const seoCopy = hmuxHistorySeoCopy(locale, tm, t, siteMeta);

  return (
    <>
      <BlogSchema
        postKey="hmuxHistory"
        path="/blog/hmux-history"
        datePublished="2026-06-02T00:00:00Z"
        headline={seoCopy.title}
        description={seoCopy.description}
      />
      <div className="mb-8">
        <Link
          href="/blog"
          className="text-sm text-muted hover:text-foreground transition-colors"
        >
          &larr; {tc("backToBlog")}
        </Link>
      </div>

      <h1>{t("title")}</h1>
      <BlogPostMeta date={t("date")} dateTime="2026-06-02" />

      <p className="mt-6">{t("p1")}</p>

      <video
        src="/blog/hmux-history.mp4"
        width={1280}
        height={990}
        autoPlay
        loop
        muted
        playsInline
        className="my-6 rounded-lg w-full h-auto"
      />

      <h2>{t("reopenTitle")}</h2>
      <p>
        {t.rich("reopenP", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </p>

      <h2>{t("agentTitle")}</h2>
      <p>
        {t.rich("agentP", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </p>
      <CodeBlock lang="bash">{`hmux hooks setup`}</CodeBlock>
      <p>
        {t.rich("agentP2", {
          link: (chunks) => <Link href="/blog/session-restore">{chunks}</Link>,
        })}
      </p>

      <h2>{t("focusTitle")}</h2>
      <p>
        {t.rich("focusP", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </p>

      <h2>{t("fullHistoryTitle")}</h2>
      <p>{t("fullHistoryP")}</p>

      <p className="mt-6">
        {t.rich("docsCta", {
          link: (chunks) => <Link href="/docs/keyboard-shortcuts">{chunks}</Link>,
        })}
      </p>
    </>
  );
}
