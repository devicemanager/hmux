import { useLocale, useTranslations } from "next-intl";
import { getTranslations } from "next-intl/server";
import { buildAlternates, openGraphDefaults, twitterSummary } from "@/i18n/seo";
import { communitySeoCopy } from "@/i18n/audited-seo";
import { SiteHeader } from "@/app/[locale]/components/site-header";
import { OfficialLinks } from "@/app/[locale]/components/official-links";
import {
  awesomeHmuxCategoryOrder,
  awesomeHmuxCuratedProjectRows,
  awesomeHmuxProjects,
  awesomeHmuxSourceUrl,
} from "./awesome-hmux-projects";
import { CommunityProjectBrowser } from "./project-browser";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "community" });
  const siteMeta = await getTranslations({ locale, namespace: "meta" });
  const alternates = buildAlternates(locale, "/community");
  const { title, description } = communitySeoCopy(locale, t, siteMeta);
  return {
    title,
    description,
    alternates,
    openGraph: {
      ...openGraphDefaults(locale, "website"),
      title,
      description,
      url: alternates.canonical,
    },
    twitter: twitterSummary(locale, title, description),
  };
}

const categorySummaries = awesomeHmuxCategoryOrder
  .map((category) => ({
    category,
    count: awesomeHmuxProjects.filter((project) =>
      (project.categories as readonly string[]).includes(category),
    ).length,
  }))
  .filter(({ count }) => count > 0);

const categoryPlacementCount = awesomeHmuxProjects.reduce(
  (total, project) => total + project.categories.length,
  0,
);

export default function CommunityPage() {
  const t = useTranslations("community");
  const locale = useLocale();
  const numberFormatter = new Intl.NumberFormat(locale);
  const stats = [
    {
      value: awesomeHmuxProjects.length,
      label: t("projectsLabel"),
    },
    {
      value: categorySummaries.length,
      label: t("areasLabel"),
    },
    {
      value: categoryPlacementCount,
      label: t("placementsLabel"),
    },
  ];

  return (
    <div className="min-h-screen">
      <SiteHeader section={t("section")} />
      <main className="w-full max-w-6xl mx-auto px-6 py-10">
        <h1 className="text-2xl font-semibold tracking-tight mb-2">
          {t("title")}
        </h1>
        <p className="max-w-3xl text-muted text-[15px] mb-6">
          {t("description")}
        </p>

        <OfficialLinks />

        <div className="mb-8 flex flex-wrap items-center gap-x-4 gap-y-2 text-sm">
          <a
            href={awesomeHmuxSourceUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="font-medium underline underline-offset-2 decoration-link-underline transition-colors hover:decoration-foreground"
          >
            {t("sourceAction")}
          </a>
          <span className="text-muted">
            {numberFormatter.format(awesomeHmuxCuratedProjectRows)}{" "}
            {t("sourceRowsLabel")}
          </span>
        </div>

        <div className="mb-10 grid grid-cols-3 border-y border-border text-sm">
          {stats.map((stat, index) => (
            <div
              key={stat.label}
              className={`py-4 ${index > 0 ? "border-l border-border pl-4 sm:pl-6" : "pr-4 sm:pr-6"}`}
            >
              <div className="text-xl font-semibold tracking-tight">
                {numberFormatter.format(stat.value)}
              </div>
              <div className="mt-1 text-xs text-muted">{stat.label}</div>
            </div>
          ))}
        </div>

        <CommunityProjectBrowser
          projects={awesomeHmuxProjects}
          categorySummaries={categorySummaries}
        />
      </main>
    </div>
  );
}
