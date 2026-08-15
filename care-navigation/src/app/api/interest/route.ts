import { NextResponse } from "next/server";

interface InterestPayload {
  applicantType: string;
  usageIntent: string;
  email: string;
  privacyConsent: boolean;
  pregnancyWeek?: string;
  drivingFrequency?: string;
  discomfortExperience?: string;
  comment?: string;
  referrer?: string;
  utmSource?: string;
  utmMedium?: string;
  utmCampaign?: string;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validate(body: InterestPayload): string | null {
  if (!body.applicantType) return "신청자 유형을 선택해주세요.";
  if (!body.usageIntent) return "서비스 사용 의향을 선택해주세요.";
  if (!body.email) return "이메일을 입력해주세요.";
  if (!EMAIL_RE.test(body.email)) return "이메일 형식을 확인해주세요.";
  if (body.privacyConsent !== true)
    return "개인정보 수집·이용에 동의해주세요.";
  return null;
}

/** Firestore REST 문서 필드 형식으로 변환 */
function toFirestoreFields(body: InterestPayload) {
  const s = (v: string | undefined) => ({ stringValue: v ?? "" });
  return {
    applicantType: s(body.applicantType),
    pregnancyWeek: s(body.pregnancyWeek),
    drivingFrequency: s(body.drivingFrequency),
    usageIntent: s(body.usageIntent),
    email: s(body.email),
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
