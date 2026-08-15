"use client";

import { useEffect, useRef, useState } from "react";
import { AlertCircle, Loader2, PartyPopper } from "lucide-react";
import {
  APPLICANT_TYPES,
  DRIVING_FREQUENCIES,
  USAGE_INTENTS,
} from "@/lib/constants";
import { readUtmParams, trackEvent } from "@/lib/analytics";

type SubmitState = "idle" | "loading" | "success" | "mock-success" | "error";

const IS_PROD_STORAGE = Boolean(process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID);

export default function BetaSection() {
  const [state, setState] = useState<SubmitState>("idle");
  const [errorMessage, setErrorMessage] = useState("");
  const openTracked = useRef(false);
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const el = sectionRef.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && !openTracked.current) {
          openTracked.current = true;
          trackEvent("reservation_form_open");
          observer.disconnect();
        }
      },
      { threshold: 0.3 },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const onSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (state === "loading") return;

    const form = event.currentTarget;
    const data = new FormData(form);

    if (data.get("privacyConsent") !== "on") {
      setState("error");
      setErrorMessage("개인정보 수집·이용에 동의해주셔야 사전예약할 수 있어요.");
      return;
    }

    setState("loading");
    setErrorMessage("");
    trackEvent("reservation_form_submit");

    const payload = {
      applicantType: String(data.get("applicantType") ?? ""),
      usageIntent: String(data.get("usageIntent") ?? ""),
      email: String(data.get("email") ?? "").trim(),
      privacyConsent: true,
      pregnancyWeek: String(data.get("pregnancyWeek") ?? ""),
      drivingFrequency: String(data.get("drivingFrequency") ?? ""),
      discomfortExperience: String(data.get("discomfortExperience") ?? ""),
      comment: String(data.get("comment") ?? ""),
      ...readUtmParams(),
    };

    try {
      const res = await fetch("/api/interest", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const json = (await res.json()) as {
        ok: boolean;
        mock?: boolean;
        error?: string;
      };
      if (!res.ok || !json.ok) {
        throw new Error(json.error ?? "잠시 후 다시 시도해주세요.");
      }
      setState(json.mock ? "mock-success" : "success");
      trackEvent("reservation_form_success", { mock: Boolean(json.mock) });
      form.reset();
    } catch (error) {
      setState("error");
      setErrorMessage(
        error instanceof Error ? error.message : "잠시 후 다시 시도해주세요.",
      );
      trackEvent("reservation_form_error");
    }
  };

  const submitted = state === "success" || state === "mock-success";

  return (
    <section
      id="reservation"
      ref={sectionRef}
      className="scroll-mt-20 bg-brand-blush/60 py-16 lg:py-24"
    >
      <div className="mx-auto max-w-3xl px-4 sm:px-6">
        <h2 className="reveal text-center text-2xl font-extrabold sm:text-3xl">
          돌봄 내비게이션을 가장 먼저 만나보세요
        </h2>
        <p className="reveal mx-auto mt-3 max-w-xl text-center leading-relaxed text-ink/70">
          이메일로 사전예약하시면 서비스 출시 소식과 이용 방법을 가장 먼저
          안내해드립니다.
        </p>

        <div className="reveal mt-10 rounded-card bg-white p-6 shadow-lift sm:p-9">
          <h3 className="text-xl font-extrabold">사전예약</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink/60">
            남겨주신 정보는 사전예약과 서비스 출시 안내 목적으로만 수집·이용하며,
            그 외 용도로 사용하지 않습니다.
          </p>

          {submitted ? (
            <div
              role="status"
              className="mt-8 rounded-2xl bg-brand-blush p-6 text-center"
            >
              <PartyPopper
                className="mx-auto h-9 w-9 text-brand"
                aria-hidden="true"
              />
              <p className="mt-3 text-lg font-bold text-brand-deep">
                사전예약이 완료되었습니다.
              </p>
              <p className="mt-1 text-brand-deep/80">
                출시 소식과 이용 방법을 이메일로 안내해드릴게요.
              </p>
              {state === "mock-success" && (
                <p className="mt-4 rounded-xl bg-white px-4 py-3 text-xs text-ink/60">
                  개발 환경(mock 모드)입니다 — 실제로 저장되지 않았습니다.
                  Firebase 환경변수를 설정하면 실제 저장이 활성화됩니다.
                </p>
              )}
            </div>
          ) : (
            <form onSubmit={onSubmit} className="mt-7 space-y-6" noValidate>
              <fieldset>
                <legend className="text-sm font-semibold">
                  신청자 유형 <RequiredMark />
                </legend>
                <div className="mt-2.5 grid grid-cols-2 gap-2 sm:grid-cols-4">
                  {APPLICANT_TYPES.map((type, i) => (
                    <label
                      key={type}
                      className="flex min-h-[3rem] cursor-pointer items-center justify-center rounded-xl border-2 border-brand-blush px-3 text-sm font-medium has-[:checked]:border-brand has-[:checked]:bg-brand-blush has-[:checked]:text-brand-deep"
                    >
                      <input
                        type="radio"
                        name="applicantType"
                        value={type}
                        defaultChecked={i === 0}
                        required
                        className="sr-only"
                      />
                      {type}
                    </label>
                  ))}
                </div>
              </fieldset>

              <div>
                <label htmlFor="usageIntent" className="text-sm font-semibold">
                  서비스 사용 의향 <RequiredMark />
                </label>
                <select
                  id="usageIntent"
                  name="usageIntent"
                  required
                  defaultValue=""
                  className="mt-2 w-full rounded-xl border-2 border-brand-blush bg-white px-3.5 py-3 text-sm focus:border-brand"
                >
                  <option value="" disabled>
                    의향을 선택해주세요
                  </option>
                  {USAGE_INTENTS.map((intent) => (
                    <option key={intent} value={intent}>
                      {intent}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label htmlFor="email" className="text-sm font-semibold">
                  이메일 <RequiredMark />
                </label>
                <input
                  id="email"
                  name="email"
                  type="email"
                  inputMode="email"
                  autoComplete="email"
                  required
                  placeholder="hello@example.com"
                  className="mt-2 w-full rounded-xl border-2 border-brand-blush px-3.5 py-3 text-sm focus:border-brand"
                />
              </div>

              <details className="rounded-2xl bg-ivory p-4">
                <summary className="cursor-pointer text-sm font-semibold text-ink/80">
                  선택 항목 더 입력하기
                </summary>
                <div className="mt-4 space-y-5">
                  <div className="grid gap-5 sm:grid-cols-2">
                    <div>
                      <label
                        htmlFor="pregnancyWeek"
                        className="text-sm font-semibold"
                      >
                        임신 주차 (선택)
                      </label>
                      <input
                        id="pregnancyWeek"
                        name="pregnancyWeek"
                        type="text"
                        inputMode="numeric"
                        placeholder="예: 24주"
                        className="mt-2 w-full rounded-xl border-2 border-brand-blush px-3.5 py-3 text-sm focus:border-brand"
                      />
                    </div>
                    <div>
                      <label
                        htmlFor="drivingFrequency"
                        className="text-sm font-semibold"
                      >
                        평소 차량 이동 빈도 (선택)
                      </label>
                      <select
                        id="drivingFrequency"
                        name="drivingFrequency"
                        defaultValue=""
                        className="mt-2 w-full rounded-xl border-2 border-brand-blush bg-white px-3.5 py-3 text-sm focus:border-brand"
                      >
                        <option value="">선택 안 함</option>
                        {DRIVING_FREQUENCIES.map((frequency) => (
                          <option key={frequency} value={frequency}>
                            {frequency}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                  <div>
                    <label
                      htmlFor="discomfortExperience"
                      className="text-sm font-semibold"
                    >
                      가장 불편했던 이동 경험 (선택)
                    </label>
                    <textarea
                      id="discomfortExperience"
                      name="discomfortExperience"
                      rows={3}
                      placeholder="이동 중 불편했던 순간이 있다면 들려주세요."
                      className="mt-2 w-full rounded-xl border-2 border-brand-blush px-3.5 py-3 text-sm focus:border-brand"
                    />
                  </div>
                  <div>
                    <label htmlFor="comment" className="text-sm font-semibold">
                      추가 의견 (선택)
                    </label>
                    <textarea
                      id="comment"
                      name="comment"
                      rows={3}
                      placeholder="서비스에 바라는 점을 자유롭게 남겨주세요."
                      className="mt-2 w-full rounded-xl border-2 border-brand-blush px-3.5 py-3 text-sm focus:border-brand"
                    />
                  </div>
                </div>
              </details>

              <label className="flex cursor-pointer items-start gap-3 text-sm leading-relaxed text-ink/80">
                <input
                  type="checkbox"
                  name="privacyConsent"
                  required
                  className="mt-0.5 h-5 w-5 shrink-0 accent-[#F0455A]"
                />
                <span>
                  (필수) 개인정보 수집·이용에 동의합니다. 수집 항목은 위 입력
                  정보이며, 사전예약과 서비스 출시 안내 목적으로만 사용됩니다.
                </span>
              </label>

              {state === "error" && (
                <p
                  role="alert"
                  className="flex items-start gap-2 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700"
                >
                  <AlertCircle
                    className="mt-0.5 h-4 w-4 shrink-0"
                    aria-hidden="true"
                  />
                  {errorMessage}
                </p>
              )}

              <button
                type="submit"
                disabled={state === "loading"}
                className="flex w-full items-center justify-center gap-2 rounded-full bg-brand py-4 text-base font-bold text-white transition-colors hover:bg-brand-deep disabled:cursor-not-allowed disabled:opacity-70"
              >
                {state === "loading" ? (
                  <>
                    <Loader2 className="h-5 w-5 animate-spin" aria-hidden="true" />
                    사전예약 접수 중…
                  </>
                ) : (
                  "사전예약하기"
                )}
              </button>

              {!IS_PROD_STORAGE && (
                <p className="text-center text-xs text-ink/50">
                  개발 환경: 저장소 미연결 상태(mock 모드)로 동작합니다.
                </p>
              )}
            </form>
          )}
        </div>
      </div>
    </section>
  );
}

function RequiredMark() {
  return (
    <span className="text-brand" aria-hidden="true">
      *
    </span>
  );
}
