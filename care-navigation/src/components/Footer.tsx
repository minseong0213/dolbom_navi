import { TODO_COMPANY } from "@/lib/constants";
import { LogoMark } from "./MapArt";

export default function Footer() {
  return (
    <footer className="bg-ink pb-24 pt-12 text-white/80 lg:pb-12">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <div className="flex flex-col gap-8 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p className="flex items-center gap-2.5">
              <LogoMark className="h-8 w-8" />
              <span className="text-lg font-extrabold text-white">돌봄 내비게이션</span>
            </p>
            <p className="mt-2 text-sm">임산부 안심 내비게이션 · Care Navigation</p>
            <p className="mt-4 text-sm text-white/60">
              현재 MVP 및 시장 검증 단계의 서비스입니다.
            </p>
          </div>
          <nav aria-label="푸터 메뉴" className="flex flex-col gap-2 text-sm">
            <a href="#service" className="hover:text-accent">서비스 소개</a>
            <a href="#privacy-note" className="hover:text-accent">개인정보처리방침</a>
            <a href={`mailto:${TODO_COMPANY.email}`} className="hover:text-accent">
              문의하기: {TODO_COMPANY.email}
            </a>
          </nav>
        </div>
        <p id="privacy-note" className="mt-8 border-t border-white/15 pt-6 text-xs leading-relaxed text-white/50">
          사전예약 폼으로 수집한 개인정보는 사전예약과 서비스 출시 안내 목적으로만
          사용하며, 목적 달성 후 지체 없이 파기합니다. 정식 개인정보처리방침은
          서비스 출시 전 게시 예정입니다.
        </p>
        <p className="mt-4 text-xs text-white/40">
          © {new Date().getFullYear()} {TODO_COMPANY.name}. All rights reserved.
        </p>
      </div>
    </footer>
  );
}
