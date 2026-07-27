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
  { label: "베타테스트", href: "#beta" },
  { label: "자주 묻는 질문", href: "#faq" },
] as const;

export const PROBLEM_CARDS = [
  {
    icon: "car" as const,
    title: "예상하지 못한 방지턱",
    body: "익숙한 길인데도, 갑자기 만나는 방지턱에 몸이 먼저 긴장될 때가 있습니다.",
  },
  {
    icon: "map" as const,
    title: "미리 알 수 없는 경로 정보",
    body: "이 길에 방지턱이 몇 개나 있는지, 출발 전에는 알 방법이 없습니다.",
  },
  {
    icon: "clock" as const,
    title: "도착 시간만 우선하는 안내",
    body: "빨리 도착하는 길보다, 조금 덜 흔들리는 길을 찾고 싶을 때가 있습니다.",
  },
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
    icon: "scan" as const,
    title: "방지턱과 경사도 분석",
    body: "약 94,000건의 방지턱 데이터와 경로를 매칭해 높이·형태·경사도를 반영한 충격점수를 계산합니다.",
  },
  {
    step: 3,
    icon: "heart" as const,
    title: "안심 점수 높은 경로 추천",
    body: "시간이 지나치게 오래 걸리지 않는 범위에서 가장 편안한 경로를 제안합니다.",
  },
] as const;

export const ROUTE_DEMO = {
  fast: { label: "빠른 경로", time: 28, bumps: 17, score: 62 },
  calm: { label: "안심 경로", time: 31, bumps: 7, score: 89 },
} as const;

export const FEATURES = [
  {
    id: "route",
    title: "방지턱을 고려한 안심 경로",
    body: "여러 후보 경로 위의 방지턱 위치와 충격점수를 분석해, 소요시간과 승차감을 함께 고려한 경로를 제안합니다.",
    mockup: "route" as const,
  },
  {
    id: "voice",
    title: "미리 알려주는 음성 안내",
    body: "주행 중 전방에 방지턱이 있으면 약 300m와 100m 전에 음성으로 알려드립니다.",
    mockup: "voice" as const,
  },
  {
    id: "data",
    title: "사용할수록 정교해지는 도로 데이터",
    body: "공공데이터와 스마트폰 센서 데이터를 결합해 누락되거나 달라진 도로 정보를 지속적으로 보완합니다.",
    mockup: "data" as const,
  },
] as const;

export const TECH_STATS = [
  { value: "약 94,000건", label: "정제된 전국 방지턱 데이터" },
  { value: "6개 경로", label: "동시에 비교하는 후보 경로" },
  { value: "300m / 100m", label: "방지턱 사전 음성 안내" },
  { value: "100점", label: "경로별 안심 점수" },
] as const;

export const SURVEY_OPTIONS = [
  "방지턱이 적은 경로",
  "도로가 평탄한 경로",
  "방지턱 사전 음성 알림",
  "응급 분만 가능 병원 안내",
  "임산부 전용주차장 정보",
  "산전검진 일정 관리",
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

export const REGIONS = [
  "부산",
  "서울",
  "경기·인천",
  "대구·경북",
  "광주·전라",
  "대전·충청",
  "울산·경남",
  "강원",
  "제주",
  "기타",
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
    a: "공공데이터를 기반으로 약 94,000건의 방지턱 데이터를 정제해 사용하고 있습니다. 향후 스마트폰 가속도 센서 데이터를 결합해 누락된 정보를 보완할 계획입니다.",
  },
  {
    q: "의료 서비스인가요?",
    a: "아니요. 돌봄 내비게이션은 의료 서비스나 의료기기가 아니라, 도로 데이터를 활용해 이동 경로 선택을 돕는 모빌리티 서비스입니다. 서비스 효과는 실제 사용자 테스트를 통해 검증해 나갈 예정입니다.",
  },
  {
    q: "베타테스트는 어떻게 참여하나요?",
    a: "이 페이지의 신청 폼을 작성해주시면, 베타테스트 시작 시 남겨주신 연락처로 참여 방법을 안내드립니다.",
  },
] as const;
