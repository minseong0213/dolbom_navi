import type { Metadata, Viewport } from "next";
import "./globals.css";
import AnalyticsProvider from "@/components/AnalyticsProvider";
import { TODO_COMPANY } from "@/lib/constants";

export const metadata: Metadata = {
  metadataBase: new URL(TODO_COMPANY.siteUrl),
  title: "돌봄 내비게이션 — 임산부 안심 내비게이션",
  description:
    "방지턱과 도로 정보를 분석해 임산부에게 노면 충격이 적은 안심 경로를 제안하는 내비게이션 서비스입니다. 지금 사전예약할 수 있습니다.",
  keywords: ["임산부 내비게이션", "방지턱", "안심 경로", "돌봄 내비게이션", "Care Navigation"],
  openGraph: {
    title: "돌봄 내비게이션 — 임산부 안심 내비게이션",
    description:
      "아기와 함께 가는 길, 조금 더 편안할 수 있도록. 방지턱이 적은 안심 경로를 제안합니다.",
    url: TODO_COMPANY.siteUrl,
    siteName: "돌봄 내비게이션",
    locale: "ko_KR",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "돌봄 내비게이션 — 임산부 안심 내비게이션",
    description: "방지턱이 적은 안심 경로를 제안하는 임산부 내비게이션",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#F0455A",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <head>
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css"
        />
      </head>
      <body>
        {children}
        <AnalyticsProvider />
      </body>
    </html>
  );
}
