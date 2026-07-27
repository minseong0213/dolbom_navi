import { TECH_STATS } from "@/lib/constants";

export default function TechnologySection() {
  return (
    <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6 lg:py-24">
      <h2 className="reveal text-center text-2xl font-extrabold sm:text-3xl">
        데이터로 만드는 편안한 경로
      </h2>
      <p className="reveal mx-auto mt-3 max-w-xl text-center leading-relaxed text-ink/70">
        전국 도로의 방지턱 정보를 정제하고, 경로마다 안심 점수를 계산합니다.
      </p>
      <dl className="mt-10 grid grid-cols-2 gap-4 lg:grid-cols-4">
        {TECH_STATS.map((stat) => (
          <div key={stat.label} className="reveal rounded-card bg-white p-6 text-center shadow-card">
            <dt className="order-2 mt-2 block text-sm leading-snug text-ink/70">
              {stat.label}
            </dt>
            <dd className="order-1 block text-xl font-extrabold text-brand-deep sm:text-2xl">
              {stat.value}
            </dd>
          </div>
        ))}
      </dl>
      <p className="reveal mx-auto mt-8 max-w-2xl text-center text-sm leading-relaxed text-ink/60">
        현재 데이터와 알고리즘은 MVP 단계이며, 실제 사용자 테스트와 도로 상황
        검증을 통해 계속 개선하고 있습니다.
      </p>
    </section>
  );
}
