import PhoneMockup from "./PhoneMockup";
import { FEATURES } from "@/lib/constants";

export default function FeatureSection() {
  return (
    <section id="features" className="mx-auto max-w-6xl px-4 py-16 sm:px-6 lg:py-24">
      <h2 className="reveal text-center text-2xl font-extrabold sm:text-3xl">
        안심 경로를 만드는 방식
      </h2>
      <div className="mt-12 space-y-16 lg:mt-16 lg:space-y-24">
        {FEATURES.map((feature, index) => (
          <article
            key={feature.id}
            className="reveal grid items-center gap-8 lg:grid-cols-2 lg:gap-16"
          >
            <div className={index % 2 === 1 ? "lg:order-2" : ""}>
              <PhoneMockup variant={feature.mockup} />
            </div>
            <div
              className={`text-center lg:text-left ${index % 2 === 1 ? "lg:order-1" : ""}`}
            >
              <p className="text-sm font-bold text-brand">
                {feature.eyebrow}
              </p>
              <h3 className="mt-2 text-xl font-extrabold leading-snug sm:text-2xl">
                {feature.title}
              </h3>
              <p className="mx-auto mt-4 max-w-md leading-relaxed text-ink/70 lg:mx-0">
                {feature.body}
              </p>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
