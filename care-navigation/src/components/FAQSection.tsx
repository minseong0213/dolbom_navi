"use client";

import { ChevronDown } from "lucide-react";
import { FAQ_ITEMS } from "@/lib/constants";
import { trackEvent } from "@/lib/analytics";

export default function FAQSection() {
  return (
    <section id="faq" className="mx-auto max-w-3xl px-4 py-16 sm:px-6 lg:py-24">
      <h2 className="reveal text-center text-2xl font-extrabold sm:text-3xl">
        자주 묻는 질문
      </h2>
      <div className="mt-10 space-y-3">
        {FAQ_ITEMS.map((item) => (
          <details
            key={item.q}
            className="reveal group rounded-2xl bg-white shadow-card open:ring-1 open:ring-brand-soft"
            onToggle={(e) => {
              if ((e.target as HTMLDetailsElement).open) {
                trackEvent("faq_open", { question: item.q });
              }
            }}
          >
            <summary className="flex cursor-pointer list-none items-center justify-between gap-4 rounded-2xl px-5 py-4 text-base font-semibold [&::-webkit-details-marker]:hidden">
              {item.q}
              <ChevronDown
                className="h-5 w-5 shrink-0 text-brand transition-transform group-open:rotate-180"
                aria-hidden="true"
              />
            </summary>
            <p className="px-5 pb-5 leading-relaxed text-ink/70">{item.a}</p>
          </details>
        ))}
      </div>
    </section>
  );
}
