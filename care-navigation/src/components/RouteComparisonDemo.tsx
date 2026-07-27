"use client";

import { useState } from "react";
import { Timer, TrafficCone, ShieldCheck } from "lucide-react";
import { RouteMap } from "./MapArt";
import { ROUTE_DEMO } from "@/lib/constants";
import { trackEvent } from "@/lib/analytics";

type RouteKey = keyof typeof ROUTE_DEMO;

export default function RouteComparisonDemo() {
  const [selected, setSelected] = useState<RouteKey>("calm");
  const route = ROUTE_DEMO[selected];

  const select = (key: RouteKey) => {
    setSelected(key);
    trackEvent("route_demo_interaction", { route: key });
  };

  return (
    <section className="bg-brand py-16 lg:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <h2 className="reveal text-center text-2xl font-extrabold text-white sm:text-3xl">
          같은 목적지, 다른 두 가지 길
        </h2>
        <p className="reveal mt-3 text-center text-brand-blush">
          경로를 눌러 방지턱 수와 안심 점수를 비교해보세요.
        </p>

        <div className="reveal mx-auto mt-10 max-w-3xl rounded-card bg-white p-5 shadow-lift sm:p-8">
          <div
            role="tablist"
            aria-label="경로 선택"
            className="grid grid-cols-2 gap-2 rounded-full bg-brand-blush p-1.5"
          >
            {(Object.keys(ROUTE_DEMO) as RouteKey[]).map((key) => (
              <button
                key={key}
                role="tab"
                type="button"
                aria-selected={selected === key}
                onClick={() => select(key)}
                className={`rounded-full py-3 text-sm font-semibold transition-colors ${
                  selected === key
                    ? "bg-brand text-white"
                    : "text-brand-deep hover:bg-white/70"
                }`}
              >
                {ROUTE_DEMO[key].label}
              </button>
            ))}
          </div>

          <div className="mt-6 grid gap-6 sm:grid-cols-[1.2fr_1fr] sm:items-center">
            <RouteMap
              variant={selected}
              bumps={selected === "calm" ? 3 : 6}
              className="w-full"
              title={`${route.label}가 표시된 가상 지도`}
            />
            <dl className="space-y-3" aria-live="polite">
              <div className="flex items-center justify-between rounded-2xl bg-ivory px-4 py-3">
                <dt className="flex items-center gap-2 text-sm text-ink/70">
                  <Timer className="h-4 w-4 text-brand" aria-hidden="true" />
                  예상시간
                </dt>
                <dd className="text-lg font-bold">{route.time}분</dd>
              </div>
              <div className="flex items-center justify-between rounded-2xl bg-ivory px-4 py-3">
                <dt className="flex items-center gap-2 text-sm text-ink/70">
                  <TrafficCone className="h-4 w-4 text-brand" aria-hidden="true" />
                  방지턱
                </dt>
                <dd className="text-lg font-bold">{route.bumps}개</dd>
              </div>
              <div className="flex items-center justify-between rounded-2xl bg-brand-blush px-4 py-3">
                <dt className="flex items-center gap-2 text-sm font-medium text-brand-deep">
                  <ShieldCheck className="h-4 w-4" aria-hidden="true" />
                  안심 점수
                </dt>
                <dd className="text-lg font-extrabold text-brand-deep">
                  {route.score}점
                </dd>
              </div>
            </dl>
          </div>
          <p className="mt-5 text-center text-xs text-ink/50">
            위 수치는 서비스 이해를 돕기 위한 데모 데이터입니다.
          </p>
        </div>
      </div>
    </section>
  );
}
