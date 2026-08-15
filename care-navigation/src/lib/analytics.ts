"use client";

export type AnalyticsEvent =
  | "hero_cta_click"
  | "reservation_form_open"
  | "route_demo_interaction"
  | "reservation_form_submit"
  | "reservation_form_success"
  | "reservation_form_error"
  | "faq_open"
  | "scroll_50"
  | "scroll_90";

type GtagFn = (
  command: "event",
  eventName: string,
  params?: Record<string, string | number | boolean>,
) => void;

declare global {
  interface Window {
    gtag?: GtagFn;
  }
}

export const GA_ID = process.env.NEXT_PUBLIC_GA_ID ?? "";

/** GA4가 설정된 경우에만 이벤트를 전송합니다. 미설정 시 아무 동작도 하지 않습니다. */
export function trackEvent(
  name: AnalyticsEvent,
  params?: Record<string, string | number | boolean>,
): void {
  if (typeof window === "undefined") return;
  if (!GA_ID || typeof window.gtag !== "function") return;
  try {
    window.gtag("event", name, params);
  } catch {
    // 추적 실패가 사용자 경험에 영향을 주지 않도록 무시합니다.
  }
}

export interface UtmParams {
  utmSource: string;
  utmMedium: string;
  utmCampaign: string;
  referrer: string;
}

export function readUtmParams(): UtmParams {
  if (typeof window === "undefined") {
    return { utmSource: "", utmMedium: "", utmCampaign: "", referrer: "" };
  }
  const search = new URLSearchParams(window.location.search);
  return {
    utmSource: search.get("utm_source") ?? "",
    utmMedium: search.get("utm_medium") ?? "",
    utmCampaign: search.get("utm_campaign") ?? "",
    referrer: document.referrer ?? "",
  };
}
