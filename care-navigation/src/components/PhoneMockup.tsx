import { Navigation, Route, ShieldCheck } from "lucide-react";
import { RouteMap } from "./MapArt";
import { ROUTE_DEMO } from "@/lib/constants";

export type MockupVariant = "hero" | "route" | "tmap" | "time-limit";

/** 스마트폰 프레임 안에 서비스 화면을 표현하는 목업 (실제 SDK 미사용) */
export default function PhoneMockup({ variant }: { variant: MockupVariant }) {
  return (
    <div
      className="mx-auto w-[248px] rounded-[2.4rem] border-[6px] border-ink/90 bg-white p-3 shadow-lift sm:w-[268px]"
      aria-hidden={variant === "hero" ? undefined : true}
    >
      <div className="mx-auto mb-2 h-1.5 w-16 rounded-full bg-ink/15" />
      {variant === "hero" && <HeroScreen />}
      {variant === "route" && <RouteScreen />}
      {variant === "tmap" && <TmapScreen />}
      {variant === "time-limit" && <TimeLimitScreen />}
    </div>
  );
}

function SearchBar() {
  return (
    <div className="space-y-1.5 rounded-2xl bg-brand-blush p-3 text-[12px]">
      <p className="flex items-center gap-2">
        <span className="h-2 w-2 shrink-0 rounded-full border-2 border-brand" />
        <span className="text-ink/70">출발</span>
        <span className="font-semibold">부산시청</span>
      </p>
      <p className="flex items-center gap-2">
        <span className="h-2 w-2 shrink-0 rounded-full bg-brand-deep" />
        <span className="text-ink/70">도착</span>
        <span className="font-semibold">부산대학교병원</span>
      </p>
    </div>
  );
}

function HeroScreen() {
  const { fast, calm } = ROUTE_DEMO;
  return (
    <div className="space-y-2.5">
      <SearchBar />
      <RouteMap variant="calm" bumps={3} className="w-full" />
      <div className="grid grid-cols-2 gap-2 text-[11px]">
        <div className="rounded-xl border border-ink/10 p-2.5">
          <p className="text-ink/60">{fast.label}</p>
          <p className="text-sm font-bold">{fast.time}분</p>
          <p className="text-ink/60">방지턱 {fast.bumps}개</p>
        </div>
        <div className="rounded-xl bg-brand-blush p-2.5 ring-2 ring-brand">
          <p className="font-semibold text-brand-deep">{calm.label}</p>
          <p className="text-sm font-bold text-brand-deep">
            {calm.time}분{" "}
            <span className="text-[10px] font-medium">
              (+{calm.time - fast.time}분)
            </span>
          </p>
          <p className="text-brand-deep/80">
            방지턱 {calm.bumps}개 · {calm.score}점
          </p>
        </div>
      </div>
      <p className="flex items-center justify-center gap-1.5 rounded-full bg-brand py-2.5 text-[12px] font-semibold text-white">
        <Navigation className="h-3.5 w-3.5" aria-hidden="true" />
        안심 경로로 안내 시작
      </p>
    </div>
  );
}

function RouteScreen() {
  return (
    <div className="space-y-2.5">
      <SearchBar />
      <RouteMap variant="calm" bumps={4} className="w-full" />
      <div className="rounded-xl bg-brand-blush p-3 text-[11px] text-brand-deep">
        <p className="font-semibold">안심 점수 89점</p>
        <p>충격점수가 낮은 경로를 우선 제안합니다</p>
      </div>
    </div>
  );
}

function TmapScreen() {
  return (
    <div className="space-y-2.5">
      <SearchBar />
      <RouteMap variant="calm" bumps={3} className="w-full" />
      <div className="flex items-start gap-2.5 rounded-2xl bg-brand-blush p-3 text-brand-deep">
        <Route className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
        <div className="text-[11.5px] leading-relaxed">
          <p className="font-semibold">티맵 API 경로 조회 완료</p>
          <p className="text-brand-deep/70">정확한 후보 경로 6개를 확인했어요</p>
        </div>
      </div>
    </div>
  );
}

function TimeLimitScreen() {
  const { fast, calm } = ROUTE_DEMO;
  return (
    <div className="space-y-2.5">
      <SearchBar />
      <RouteMap variant="calm" bumps={2} className="w-full" />
      <div className="grid grid-cols-2 gap-2 text-[11px]">
        <div className="rounded-xl border border-ink/10 p-2.5">
          <p className="text-ink/60">최단 경로</p>
          <p className="text-sm font-bold">{fast.time}분</p>
        </div>
        <div className="rounded-xl bg-brand-blush p-2.5 ring-2 ring-brand">
          <p className="font-semibold text-brand-deep">안심 경로</p>
          <p className="text-sm font-bold text-brand-deep">{calm.time}분</p>
        </div>
      </div>
      <div className="flex items-center justify-center gap-1.5 rounded-xl bg-brand py-2.5 text-[11px] font-semibold text-white">
        <ShieldCheck className="h-4 w-4" aria-hidden="true" />
        시간 차이 10.7% · 추천 가능
      </div>
    </div>
  );
}
