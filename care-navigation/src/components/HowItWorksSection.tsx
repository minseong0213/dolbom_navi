import { Route, ScanLine, HeartHandshake } from "lucide-react";
import { HOW_IT_WORKS_STEPS } from "@/lib/constants";

const ICONS = { route: Route, scan: ScanLine, heart: HeartHandshake } as const;

export default function HowItWorksSection() {
  return (
    <section id="how-it-works" className="bg-brand-blush/60 py-16 lg:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <h2 className="reveal text-center text-2xl font-extrabold leading-snug sm:text-3xl">
          가장 빠른 길이 아닌,
          <br />
          우리에게 편안한 길을 찾습니다.
        </h2>
        <ol className="mt-10 grid gap-5 sm:grid-cols-3 lg:mt-14">
          {HOW_IT_WORKS_STEPS.map((step) => {
            const Icon = ICONS[step.icon];
            return (
              <li key={step.step} className="reveal rounded-card bg-white p-7 shadow-card">
                <div className="flex items-center justify-between">
                  <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-brand text-white">
                    <Icon className="h-6 w-6" aria-hidden="true" />
                  </span>
                  <span className="text-4xl font-extrabold text-brand-soft" aria-hidden="true">
                    {step.step}
                  </span>
                </div>
                <h3 className="mt-4 text-lg font-bold">
                  <span className="sr-only">{step.step}단계, </span>
                  {step.title}
                </h3>
                <p className="mt-2 leading-relaxed text-ink/70">{step.body}</p>
              </li>
            );
          })}
        </ol>
      </div>
    </section>
  );
}
