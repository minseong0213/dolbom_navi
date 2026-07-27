"use client";

import { useEffect, useState } from "react";

/** 모바일에서 하단에 고정되는 신청 CTA. 신청 폼이 보이면 숨깁니다. */
export default function MobileStickyCTA() {
  const [hidden, setHidden] = useState(false);

  useEffect(() => {
    const target = document.getElementById("beta");
    if (!target) return;
    const observer = new IntersectionObserver(
      (entries) => setHidden(Boolean(entries[0]?.isIntersecting)),
      { threshold: 0.1 },
    );
    observer.observe(target);
    return () => observer.disconnect();
  }, []);

  if (hidden) return null;

  return (
    <div className="fixed inset-x-0 bottom-0 z-40 border-t border-brand-soft/40 bg-ivory/90 p-3 backdrop-blur-md lg:hidden">
      <a
        href="#beta"
        className="block rounded-full bg-brand py-3.5 text-center text-base font-bold text-white"
      >
        베타테스터 신청하기
      </a>
    </div>
  );
}
