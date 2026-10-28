import { useTranslations } from "next-intl";
import { getTranslations } from "next-intl/server";
import { buildAlternates, openGraphDefaults, twitterSummary } from "@/i18n/seo";
import { blogPostSeoCopy } from "@/i18n/audited-seo";
import { BlogSchema } from "../blog-schema";
import { Link } from "@/i18n/navigation";
import { BlogPostMeta } from "@/app/[locale]/components/blog-author";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "blog.zenOfHmux" });
  const post = await getTranslations({ locale, namespace: "blog.posts.zenOfHmux" });
  const siteMeta = await getTranslations({ locale, namespace: "meta" });
  const alternates = buildAlternates(locale, "/blog/zen-of-hmux");
  const { title, description } = blogPostSeoCopy(locale, "zenOfHmux", t, post, siteMeta);
  return {
    title: { absolute: title },
    description,
    openGraph: {
      ...openGraphDefaults(locale, "article"),
      title,
      description,
      url: alternates.canonical,
      publishedTime: "2026-02-27T00:00:00Z",
    },
    twitter: twitterSummary(locale, title, description),
    alternates,
  };
}

export default function ZenOfHmuxPage() {
  const t = useTranslations("blog.posts.zenOfHmux");
  const tc = useTranslations("common");

  return (
    <>
      <BlogSchema postKey="zenOfHmux" seoKey="zenOfHmux" path="/blog/zen-of-hmux" datePublished="2026-02-27T00:00:00Z" />
      <div className="mb-8">
        <Link
          href="/blog"
          className="text-sm text-muted hover:text-foreground transition-colors"
        >
          &larr; {tc("backToBlog")}
        </Link>
      </div>

      <h1>{t("title")}</h1>
      <BlogPostMeta date={t("date")} dateTime="2026-02-27" />

      <p className="mt-6">{t("p1")}</p>
      <p>{t("p2")}</p>
      <p>{t("p3")}</p>
      <p>{t("p4")}</p>
    </>
  );
}
