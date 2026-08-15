import { Navigation, Route, ShieldCheck } from "lucide-react";
import { HOW_IT_WORKS_STEPS } from "@/lib/constants";

const ICONS = { route: Route, navigation: Navigation, shield: ShieldCheck } as const;

export default function HowItWorksSection() {
  return (
    <section id="how-it-works" className="bg-ivory py-20 lg:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <p className="reveal text-center text-base font-medium text-brand-deep sm:text-lg">
          임신 후, 평소 다니던 길도 다르게 느껴집니다.
        </p>
        <h2 className="reveal mt-4 text-center text-3xl font-extrabold leading-snug sm:text-4xl">
          티맵 경로는 그대로,
          <br />
          방지턱은 최소한으로.
        </h2>
        <p className="reveal mt-10 text-center text-xl font-bold leading-snug sm:text-2xl">
          가장 빠른 길이 아닌,
          <br />
          우리에게 편안한 길을 찾습니다.
        </p>
        <ol className="mt-10 grid gap-5 sm:grid-cols-3 lg:mt-12">
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
