import { useTranslations } from "next-intl";
import { getTranslations } from "next-intl/server";
import { buildAlternates, openGraphDefaults, twitterSummary } from "@/i18n/seo";
import { blogPostSeoCopy } from "@/i18n/audited-seo";
import { BlogSchema } from "../blog-schema";
import { Link } from "@/i18n/navigation";
import { BlogPostMeta } from "@/app/[locale]/components/blog-author";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "blog.introducingHmux" });
  const post = await getTranslations({ locale, namespace: "blog.posts.introducingHmux" });
  const siteMeta = await getTranslations({ locale, namespace: "meta" });
  const alternates = buildAlternates(locale, "/blog/introducing-hmux");
  const { title, description } = blogPostSeoCopy(locale, "introducingHmux", t, post, siteMeta);
  return {
    title: { absolute: title },
    description,
    openGraph: {
      ...openGraphDefaults(locale, "article"),
      title,
      description,
      url: alternates.canonical,
      publishedTime: "2026-02-12T00:00:00Z",
    },
    twitter: twitterSummary(locale, title, description),
    alternates,
  };
}

export default function IntroducingHmuxPage() {
  const t = useTranslations("blog.posts.introducingHmux");
  const tc = useTranslations("common");

  return (
    <>
      <BlogSchema postKey="introducingHmux" seoKey="introducingHmux" path="/blog/introducing-hmux" datePublished="2026-02-12T00:00:00Z" />
      <div className="mb-8">
        <Link
          href="/blog"
          className="text-sm text-muted hover:text-foreground transition-colors"
        >
          &larr; {tc("backToBlog")}
        </Link>
      </div>

      <h1>{t("title")}</h1>
      <BlogPostMeta date={t("date")} dateTime="2026-02-12" />

      <p className="mt-6">{t("p1")}</p>

      <h2>{t("whyTitle")}</h2>
      <p>{t("whyP")}</p>

      <h2>{t("featuresTitle")}</h2>
      <ul>
        <li><strong>{t("featureVerticalTabsLabel")}</strong>: {t("featureVerticalTabsDesc")}</li>
        <li><strong>{t("featureNotificationsLabel")}</strong>: {t("featureNotificationsDesc")}</li>
        <li><strong>{t("featureSplitPanesLabel")}</strong>: {t("featureSplitPanesDesc")}</li>
        <li><strong>{t("featureSocketApiLabel")}</strong>: {t("featureSocketApiDesc")}</li>
        <li><strong>{t("featureGpuLabel")}</strong>: {t("featureGpuDesc")}</li>
      </ul>

      <h2>{t("getStartedTitle")}</h2>
      <p>
        {t.rich("getStartedP", {
          link: (chunks) => <Link href="/docs/getting-started">{chunks}</Link>,
        })}
      </p>
    </>
  );
}
