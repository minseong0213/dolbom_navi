"use client";

import { MapPin } from "lucide-react";
import PhoneMockup from "./PhoneMockup";
import { trackEvent } from "@/lib/analytics";

export default function HeroSection() {
  return (
    <section id="service" className="relative overflow-hidden bg-brand pt-28 sm:pt-32">
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.14]"
        aria-hidden="true"
      >
        <svg viewBox="0 0 800 600" className="h-full w-full" preserveAspectRatio="xMidYMid slice">
          <path d="M-40 520 C160 420 240 300 420 240 C580 186 660 120 860 20" stroke="#FFFFFF" strokeWidth="70" fill="none" strokeLinecap="round" />
          <path d="M300 660 C330 480 260 360 420 240" stroke="#FFFFFF" strokeWidth="44" fill="none" strokeLinecap="round" />
        </svg>
      </div>

      <div className="relative mx-auto grid max-w-6xl gap-12 px-4 pb-16 sm:px-6 lg:grid-cols-2 lg:items-center lg:gap-8 lg:pb-24">
        <div className="text-center lg:text-left">
          <p className="mb-5 inline-flex items-center gap-1.5 rounded-full bg-white/15 px-4 py-1.5 text-sm font-medium text-white">
            <MapPin className="h-4 w-4 text-accent" aria-hidden="true" />
            임산부 안심 내비게이션
          </p>
          <h1 className="text-[2rem] font-extrabold leading-snug text-white sm:text-4xl lg:text-[2.75rem] lg:leading-tight">
            아기와 함께 가는 길,
            <br />
            조금 더 편안할 수 있도록
          </h1>
          <p className="mx-auto mt-5 max-w-md text-base leading-relaxed text-brand-blush lg:mx-0">
            돌봄 내비게이션은 방지턱과 도로 정보를 분석해
            <br className="hidden sm:block" /> 임산부에게 노면 충격이 적은 안심
            경로를 제안합니다.
          </p>

          <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row sm:justify-center lg:justify-start">
            <a
              href="#reservation"
              onClick={() => trackEvent("hero_cta_click", { cta: "apply" })}
              className="w-full rounded-full bg-accent px-8 py-4 text-center text-base font-bold text-ink shadow-lift transition-transform hover:scale-[1.03] sm:w-auto"
            >
              사전예약하기
            </a>
            <a
              href="#features"
              onClick={() => trackEvent("hero_cta_click", { cta: "learn" })}
              className="w-full rounded-full border-2 border-brand-soft px-8 py-[0.9rem] text-center text-base font-semibold text-white transition-colors hover:bg-white/10 sm:w-auto"
            >
              서비스 알아보기
            </a>
          </div>
          <p className="mt-5 text-sm text-white/80">
            현재 부산 지역 시범 서비스를 준비하고 있습니다.
          </p>
        </div>

        <div className="reveal pb-2">
          <PhoneMockup variant="hero" />
        </div>
      </div>

      <svg
        viewBox="0 0 1440 64"
        className="block w-full text-ivory"
        preserveAspectRatio="none"
        aria-hidden="true"
      >
        <path d="M0 64 L0 40 C360 0 1080 0 1440 40 L1440 64 Z" fill="currentColor" />
      </svg>
    </section>
  );
}
