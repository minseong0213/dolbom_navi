/** 실제 값 확정 후 교체가 필요한 항목 (TODO) */
export const TODO_COMPANY = {
  /** TODO: 실제 팀/회사명으로 교체 */
  name: "돌봄 내비게이션 팀",
  /** TODO: 실제 문의 이메일로 교체 */
  email: "contact@example.com",
  /** TODO: 배포 도메인으로 교체 */
  siteUrl: "https://care-navigation.example.com",
} as const;

export const NAV_ITEMS = [
  { label: "서비스 소개", href: "#service" },
  { label: "주요 기능", href: "#features" },
  { label: "이용 방법", href: "#how-it-works" },
  { label: "사전예약", href: "#reservation" },
  { label: "자주 묻는 질문", href: "#faq" },
] as const;

export const HOW_IT_WORKS_STEPS = [
  {
    step: 1,
    icon: "route" as const,
    title: "여러 후보 경로 조회",
    body: "출발지와 목적지를 입력하면 최대 6개의 후보 경로를 한 번에 조회합니다.",
  },
  {
    step: 2,
    icon: "navigation" as const,
    title: "티맵 API 기반 정확한 경로 안내",
    body: "티맵 API가 제공하는 후보 경로를 바탕으로 출발지부터 목적지까지 정확하게 안내합니다.",
  },
  {
    step: 3,
    icon: "shield" as const,
    title: "최단 경로 대비 15% 이내 안심 경로",
    body: "최단 경로보다 예상 시간이 15% 이상 늘어나는 길은 제외하고, 그 안에서 방지턱이 적은 경로를 추천합니다.",
  },
] as const;

export const ROUTE_DEMO = {
  fast: { label: "빠른 경로", time: 28, bumps: 17, score: 62 },
  calm: { label: "안심 경로", time: 31, bumps: 7, score: 89 },
} as const;

export const FEATURES = [
  {
    id: "route",
    eyebrow: "핵심 기능",
    title: "방지턱을 고려한 안심 경로",
    body: "여러 후보 경로 위의 방지턱 위치와 충격점수를 분석해, 소요시간과 승차감을 함께 고려한 경로를 제안합니다.",
    mockup: "route" as const,
  },
  {
    id: "tmap",
    eyebrow: "세부 기준 01",
    title: "티맵 API 기반 정확한 경로 안내",
    body: "티맵 API가 제공하는 후보 경로를 바탕으로 출발지부터 목적지까지 익숙하고 정확한 길을 안내합니다.",
    mockup: "tmap" as const,
  },
  {
    id: "time-limit",
    eyebrow: "세부 기준 02",
    title: "최단 경로 대비 15% 이내 안심 경로",
    body: "최단 경로보다 예상 시간이 15% 이상 늘어나는 길은 제외하고, 그 안에서 방지턱이 적은 경로만 추천합니다.",
    mockup: "time-limit" as const,
  },
] as const;

export const TECH_STATS = [
  { value: "약 94,000건", label: "정제된 전국 방지턱 데이터" },
  { value: "6개 경로", label: "동시에 비교하는 후보 경로" },
  { value: "티맵 API", label: "정확한 후보 경로 탐색" },
  { value: "15% 이내", label: "최단 경로 대비 추천 기준" },
] as const;

export const APPLICANT_TYPES = ["임산부", "배우자", "가족", "기타"] as const;

export const USAGE_INTENTS = [
  "꼭 사용해보고 싶어요",
  "관심은 있어요",
  "잘 모르겠어요",
] as const;

export const DRIVING_FREQUENCIES = [
  "거의 매일",
  "주 3~4회",
  "주 1~2회",
  "월 몇 회 이하",
] as const;

export const FAQ_ITEMS = [
  {
    q: "일반 내비게이션과 무엇이 다른가요?",
    a: "일반 내비게이션은 도착 시간을 우선합니다. 돌봄 내비게이션은 후보 경로 위의 방지턱과 도로 정보를 분석해, 소요시간과 승차감을 함께 고려한 경로 선택지를 제안합니다.",
  },
  {
    q: "가장 빠른 경로보다 오래 걸리나요?",
    a: "안심 경로는 보통 빠른 경로보다 몇 분 정도 더 걸릴 수 있습니다. 다만 시간이 지나치게 오래 걸리는 경로는 추천에서 제외합니다.",
  },
  {
    q: "전국에서 사용할 수 있나요?",
    a: "방지턱 데이터는 전국 단위로 구축되어 있습니다. 다만 서비스 초기에는 부산 지역을 중심으로 시범 운영하며 순차적으로 확대할 예정입니다.",
  },
  {
    q: "방지턱 정보는 어떻게 수집하나요?",
    a: "공공데이터를 기반으로 약 94,000건의 방지턱 데이터를 정제해 사용하고 있으며, 실제 도로 정보와 비교해 지속적으로 검증합니다.",
  },
  {
    q: "의료 서비스인가요?",
    a: "아니요. 돌봄 내비게이션은 의료 서비스나 의료기기가 아니라, 도로 데이터를 활용해 이동 경로 선택을 돕는 모빌리티 서비스입니다. 서비스 효과는 실제 사용자 테스트를 통해 검증해 나갈 예정입니다.",
  },
  {
    q: "사전예약은 어떻게 하나요?",
    a: "이 페이지의 사전예약 폼을 작성해주시면, 서비스 출시 소식과 이용 방법을 남겨주신 이메일로 안내드립니다.",
  },
] as const;
