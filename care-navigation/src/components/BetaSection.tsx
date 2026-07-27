"use client";

import { useEffect, useRef, useState } from "react";
import { Check, Loader2, PartyPopper, AlertCircle } from "lucide-react";
import {
  SURVEY_OPTIONS,
  APPLICANT_TYPES,
  USAGE_INTENTS,
  DRIVING_FREQUENCIES,
  REGIONS,
} from "@/lib/constants";
import { trackEvent, readUtmParams } from "@/lib/analytics";

type SubmitState = "idle" | "loading" | "success" | "mock-success" | "error";

const IS_PROD_STORAGE = Boolean(process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID);

export default function BetaSection() {
  const [features, setFeatures] = useState<string[]>([]);
  const [contactType, setContactType] = useState<"email" | "phone">("email");
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
          trackEvent("beta_form_open");
          observer.disconnect();
        }
      },
      { threshold: 0.3 },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const toggleFeature = (feature: string) => {
    setFeatures((prev) => {
      const next = prev.includes(feature)
        ? prev.filter((f) => f !== feature)
        : [...prev, feature];
      if (!prev.includes(feature)) {
        trackEvent("feature_selected", { feature });
      }
      return next;
    });
  };

  const onSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (state === "loading") return;

    const form = event.currentTarget;
    const data = new FormData(form);

    if (data.get("privacyConsent") !== "on") {
      setState("error");
      setErrorMessage("개인정보 수집·이용에 동의해주셔야 신청할 수 있어요.");
      return;
    }

    setState("loading");
    setErrorMessage("");
    trackEvent("beta_form_submit");

    const payload = {
      applicantType: String(data.get("applicantType") ?? ""),
      region: String(data.get("region") ?? ""),
      usageIntent: String(data.get("usageIntent") ?? ""),
      contactType,
      contact: String(data.get("contact") ?? "").trim(),
      privacyConsent: true,
      pregnancyWeek: String(data.get("pregnancyWeek") ?? ""),
      drivingFrequency: String(data.get("drivingFrequency") ?? ""),
      desiredFeatures: features,
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
      trackEvent("beta_form_success", { mock: Boolean(json.mock) });
      form.reset();
      setFeatures([]);
    } catch (error) {
      setState("error");
      setErrorMessage(
        error instanceof Error ? error.message : "잠시 후 다시 시도해주세요.",
      );
      trackEvent("beta_form_error");
    }
  };

  const submitted = state === "success" || state === "mock-success";

  return (
    <section
      id="beta"
      ref={sectionRef}
      className="scroll-mt-20 bg-brand-blush/60 py-16 lg:py-24"
    >
      <div className="mx-auto max-w-3xl px-4 sm:px-6">
        <h2 className="reveal text-center text-2xl font-extrabold sm:text-3xl">
          어떤 기능이 가장 필요하신가요?
        </h2>
        <p className="reveal mt-3 text-center text-ink/70">
          필요한 기능을 모두 골라주세요. 신청과 함께 전달되어 서비스 우선순위에
          반영됩니다.
        </p>

        <fieldset className="reveal mt-8">
          <legend className="sr-only">필요한 기능 선택 (복수 선택 가능)</legend>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            {SURVEY_OPTIONS.map((option) => {
              const active = features.includes(option);
              return (
                <button
                  key={option}
                  type="button"
                  aria-pressed={active}
                  onClick={() => toggleFeature(option)}
                  className={`flex min-h-[3.25rem] items-center justify-between rounded-2xl border-2 px-4 py-3 text-left text-sm font-medium transition-colors ${
                    active
                      ? "border-brand bg-white text-brand-deep shadow-card"
                      : "border-transparent bg-white/70 text-ink/70 hover:bg-white"
                  }`}
                >
                  {option}
                  <span
                    className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full ${
                      active ? "bg-brand text-white" : "bg-brand-blush"
                    }`}
                    aria-hidden="true"
                  >
                    {active && <Check className="h-4 w-4" />}
                  </span>
                </button>
              );
            })}
          </div>
        </fieldset>

        <div className="reveal mt-10 rounded-card bg-white p-6 shadow-lift sm:p-9">
          <h3 className="text-xl font-extrabold">베타테스터 신청</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink/60">
            남겨주신 정보는 시장 검증과 베타테스트 연락 목적으로만 수집·이용하며,
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
                신청이 완료되었습니다.
              </p>
              <p className="mt-1 text-brand-deep/80">
                조금 더 편안한 이동을 함께 만들어주셔서 감사합니다.
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

              <div className="grid gap-5 sm:grid-cols-2">
                <div>
                  <label htmlFor="region" className="text-sm font-semibold">
                    거주 지역 <RequiredMark />
                  </label>
                  <select
                    id="region"
                    name="region"
                    required
                    defaultValue=""
                    className="mt-2 w-full rounded-xl border-2 border-brand-blush bg-white px-3.5 py-3 text-sm focus:border-brand"
                  >
                    <option value="" disabled>
                      지역을 선택해주세요
                    </option>
                    {REGIONS.map((region) => (
                      <option key={region} value={region}>
                        {region}
                      </option>
                    ))}
                  </select>
                </div>
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
              </div>

              <div>
                <span className="text-sm font-semibold" id="contact-label">
                  연락처 (이메일 또는 휴대전화) <RequiredMark />
                </span>
                <div
                  className="mt-2.5 grid grid-cols-2 gap-2"
                  role="radiogroup"
                  aria-labelledby="contact-label"
                >
                  {(
                    [
                      ["email", "이메일"],
                      ["phone", "휴대전화"],
                    ] as const
                  ).map(([value, label]) => (
                    <button
                      key={value}
                      type="button"
                      role="radio"
                      aria-checked={contactType === value}
                      onClick={() => setContactType(value)}
                      className={`min-h-[2.75rem] rounded-xl text-sm font-medium transition-colors ${
                        contactType === value
                          ? "bg-brand text-white"
                          : "bg-brand-blush text-brand-deep"
                      }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
                <label htmlFor="contact" className="sr-only">
                  {contactType === "email" ? "이메일 주소" : "휴대전화 번호"}
                </label>
                <input
                  id="contact"
                  name="contact"
                  type={contactType === "email" ? "email" : "tel"}
                  inputMode={contactType === "email" ? "email" : "tel"}
                  required
                  placeholder={
                    contactType === "email"
                      ? "hello@example.com"
                      : "010-1234-5678"
                  }
                  className="mt-2.5 w-full rounded-xl border-2 border-brand-blush px-3.5 py-3 text-sm focus:border-brand"
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
                        {DRIVING_FREQUENCIES.map((freq) => (
                          <option key={freq} value={freq}>
                            {freq}
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
                  정보이며, 시장 검증과 베타테스트 연락 목적으로만 사용됩니다.
                </span>
              </label>

              {state === "error" && (
                <p
                  role="alert"
                  className="flex items-start gap-2 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700"
                >
                  <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
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
                    신청 접수 중…
                  </>
                ) : (
                  "베타테스터 신청하기"
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
