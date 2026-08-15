export default function FinalCTA() {
  return (
    <section className="bg-brand-deep py-16 lg:py-24">
      <div className="mx-auto max-w-3xl px-4 text-center sm:px-6">
        <h2 className="reveal text-2xl font-extrabold leading-snug text-white sm:text-3xl">
          조금 더 편안한 이동이
          <br />
          당연한 선택이 될 수 있도록
        </h2>
        <p className="reveal mt-4 text-brand-soft">
          돌봄 내비게이션의 첫 번째 사용자가 되어주세요.
        </p>
        <a
          href="#reservation"
          className="reveal mt-8 inline-block rounded-full bg-accent px-10 py-4 text-base font-bold text-ink shadow-lift transition-transform hover:scale-[1.03]"
        >
          사전예약하기
        </a>
      </div>
    </section>
  );
}
