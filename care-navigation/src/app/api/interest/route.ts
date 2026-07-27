import { NextResponse } from "next/server";

interface InterestPayload {
  applicantType: string;
  region: string;
  usageIntent: string;
  contactType: "email" | "phone";
  contact: string;
  privacyConsent: boolean;
  pregnancyWeek?: string;
  drivingFrequency?: string;
  desiredFeatures?: string[];
  discomfortExperience?: string;
  comment?: string;
  referrer?: string;
  utmSource?: string;
  utmMedium?: string;
  utmCampaign?: string;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_RE = /^01[016789]-?\d{3,4}-?\d{4}$/;

function validate(body: InterestPayload): string | null {
  if (!body.applicantType) return "신청자 유형을 선택해주세요.";
  if (!body.region) return "거주 지역을 선택해주세요.";
  if (!body.usageIntent) return "서비스 사용 의향을 선택해주세요.";
  if (!body.contact) return "이메일 또는 휴대전화 번호를 입력해주세요.";
  if (body.contactType === "email" && !EMAIL_RE.test(body.contact))
    return "이메일 형식을 확인해주세요.";
  if (body.contactType === "phone" && !PHONE_RE.test(body.contact))
    return "휴대전화 번호 형식을 확인해주세요.";
  if (body.privacyConsent !== true)
    return "개인정보 수집·이용에 동의해주세요.";
  return null;
}

/** Firestore REST 문서 필드 형식으로 변환 */
function toFirestoreFields(body: InterestPayload) {
  const s = (v: string | undefined) => ({ stringValue: v ?? "" });
  return {
    applicantType: s(body.applicantType),
    region: s(body.region),
    pregnancyWeek: s(body.pregnancyWeek),
    drivingFrequency: s(body.drivingFrequency),
    desiredFeatures: {
      arrayValue: {
        values: (body.desiredFeatures ?? []).map((f) => ({ stringValue: f })),
      },
    },
    usageIntent: s(body.usageIntent),
    contactType: s(body.contactType),
    contact: s(body.contact),
    discomfortExperience: s(body.discomfortExperience),
    comment: s(body.comment),
    privacyConsent: { booleanValue: body.privacyConsent },
    referrer: s(body.referrer),
    utmSource: s(body.utmSource),
    utmMedium: s(body.utmMedium),
    utmCampaign: s(body.utmCampaign),
    createdAt: { timestampValue: new Date().toISOString() },
  };
}

export async function POST(request: Request) {
  let body: InterestPayload;
  try {
    body = (await request.json()) as InterestPayload;
  } catch {
    return NextResponse.json(
      { ok: false, error: "요청 형식이 올바르지 않습니다." },
      { status: 400 },
    );
  }

  const validationError = validate(body);
  if (validationError) {
    return NextResponse.json(
      { ok: false, error: validationError },
      { status: 400 },
    );
  }

  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const apiKey = process.env.FIREBASE_API_KEY;

  // Firebase 미설정 개발 환경: 저장하지 않고 mock 응답을 반환합니다.
  if (!projectId || !apiKey) {
    return NextResponse.json({ ok: true, mock: true });
  }

  try {
    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/care_navigation_interest?key=${apiKey}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ fields: toFirestoreFields(body) }),
    });
    if (!res.ok) {
      console.error("Firestore 저장 실패:", res.status, await res.text());
      return NextResponse.json(
        { ok: false, error: "잠시 후 다시 시도해주세요." },
        { status: 502 },
      );
    }
    return NextResponse.json({ ok: true, mock: false });
  } catch (error) {
    console.error("Firestore 요청 오류:", error);
    return NextResponse.json(
      { ok: false, error: "잠시 후 다시 시도해주세요." },
      { status: 502 },
    );
  }
}
