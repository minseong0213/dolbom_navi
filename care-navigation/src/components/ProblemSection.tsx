import { Car, Map, Clock } from "lucide-react";
import { PROBLEM_CARDS } from "@/lib/constants";

const ICONS = { car: Car, map: Map, clock: Clock } as const;

export default function ProblemSection() {
  return (
    <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 lg:py-24">
      <h2 className="reveal text-center text-2xl font-extrabold leading-snug sm:text-3xl">
        임신 후, 평소 다니던 길도
        <br className="sm:hidden" /> 다르게 느껴집니다.
      </h2>
      <div className="mt-10 grid gap-5 sm:grid-cols-3 lg:mt-14">
        {PROBLEM_CARDS.map((card) => {
          const Icon = ICONS[card.icon];
          return (
            <article
              key={card.title}
              className="reveal rounded-card bg-white p-7 shadow-card"
            >
              <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-brand-blush">
                <Icon className="h-6 w-6 text-brand-deep" aria-hidden="true" />
              </span>
              <h3 className="mt-4 text-lg font-bold">{card.title}</h3>
              <p className="mt-2 leading-relaxed text-ink/70">{card.body}</p>
            </article>
          );
        })}
      </div>
    </section>
  );
}
