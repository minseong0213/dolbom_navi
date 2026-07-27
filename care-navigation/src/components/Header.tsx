"use client";

import { useState } from "react";
import { Menu, X } from "lucide-react";
import { NAV_ITEMS } from "@/lib/constants";
import { LogoMark } from "./MapArt";

export default function Header() {
  const [open, setOpen] = useState(false);

  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-brand-soft/40 bg-ivory/80 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <a href="#top" className="flex items-center gap-2.5" aria-label="돌봄 내비게이션 홈">
          <LogoMark className="h-8 w-8" />
          <span className="text-lg font-extrabold tracking-tight">돌봄 내비게이션</span>
        </a>

        <nav className="hidden items-center gap-6 lg:flex" aria-label="주요 메뉴">
          {NAV_ITEMS.map((item) => (
            <a
              key={item.href}
              href={item.href}
              className="text-sm font-medium text-ink/70 transition-colors hover:text-brand-deep"
            >
              {item.label}
            </a>
          ))}
          <a
            href="#beta"
            className="rounded-full bg-brand px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-brand-deep"
          >
            베타테스터 신청
          </a>
        </nav>

        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className="flex h-11 w-11 items-center justify-center rounded-full lg:hidden"
          aria-expanded={open}
          aria-controls="mobile-nav"
          aria-label={open ? "메뉴 닫기" : "메뉴 열기"}
        >
          {open ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </div>

      {open && (
        <nav
          id="mobile-nav"
          aria-label="모바일 메뉴"
          className="border-t border-brand-soft/40 bg-ivory/95 px-4 pb-6 pt-3 backdrop-blur-md lg:hidden"
        >
          <ul className="space-y-1">
            {NAV_ITEMS.map((item) => (
              <li key={item.href}>
                <a
                  href={item.href}
                  onClick={() => setOpen(false)}
                  className="block rounded-xl px-3 py-3 text-base font-medium text-ink/80 hover:bg-brand-blush"
                >
                  {item.label}
                </a>
              </li>
            ))}
          </ul>
          <a
            href="#beta"
            onClick={() => setOpen(false)}
            className="mt-3 block rounded-full bg-brand py-3.5 text-center text-base font-semibold text-white"
          >
            베타테스터 신청하기
          </a>
        </nav>
      )}
    </header>
  );
}
