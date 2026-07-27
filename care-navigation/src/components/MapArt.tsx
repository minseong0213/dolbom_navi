interface PinProps {
  className?: string;
}

/** 물방울형 위치 핀 (브랜드 시그니처) */
export function BrandPin({ className }: PinProps) {
  return (
    <svg
      viewBox="0 0 30 40"
      className={className}
      role="img"
      aria-label="돌봄 내비게이션 위치 핀"
    >
      <path
        d="M15 1C7.3 1 1.5 6.8 1.5 14.2 1.5 23 15 38 15 38s13.5-15 13.5-23.8C28.5 6.8 22.7 1 15 1z"
        fill="currentColor"
      />
      <circle cx="15" cy="14" r="6.5" fill="#FFFFFF" />
    </svg>
  );
}

/** 텍스트 로고 앞에 붙는 심볼 */
export function LogoMark({ className }: PinProps) {
  return (
    <svg viewBox="0 0 36 36" className={className} aria-hidden="true">
      <rect x="0" y="0" width="36" height="36" rx="11" fill="#F0455A" />
      <path
        d="M18 7c-4.4 0-8 3.4-8 7.7C10 20 18 29 18 29s8-9 8-14.3C26 10.4 22.4 7 18 7z"
        fill="#FFFFFF"
      />
      <circle cx="18" cy="14.6" r="3.2" fill="#F0455A" />
    </svg>
  );
}

interface RouteMapProps {
  /** calm: 안심 경로 강조 / fast: 빠른 경로 강조 */
  variant?: "calm" | "fast";
  bumps?: number;
  className?: string;
  title?: string;
}

/**
 * 랜딩페이지용 가상 지도 그래픽.
 * 실제 지도 SDK 없이 도로·블록·경로·방지턱을 표현합니다.
 */
export function RouteMap({
  variant = "calm",
  bumps = 3,
  className,
  title = "가상 지도 위에 표시된 추천 경로",
}: RouteMapProps) {
  const calm = variant === "calm";
  const routeColor = calm ? "#F0455A" : "#9E1F3E";
  const routePath = calm
    ? "M20 176 C56 150 60 120 96 104 C136 86 168 66 204 34"
    : "M20 176 C70 168 120 130 148 96 C168 72 186 52 204 34";
  const bumpPositions = [
    { x: 60, y: 146 },
    { x: 104, y: 100 },
    { x: 150, y: 72 },
    { x: 176, y: 52 },
    { x: 84, y: 122 },
    { x: 128, y: 86 },
  ].slice(0, Math.min(bumps, 6));

  return (
    <svg viewBox="0 0 224 196" className={className} role="img" aria-label={title}>
      <rect width="224" height="196" rx="14" fill="#FDEDF0" />
      <rect x="14" y="16" width="56" height="42" rx="5" fill="#F8B9C6" opacity="0.75" />
      <rect x="150" y="128" width="60" height="50" rx="5" fill="#F8B9C6" opacity="0.75" />
      <rect x="120" y="16" width="44" height="30" rx="5" fill="#F8B9C6" opacity="0.5" />
      <rect x="14" y="120" width="40" height="34" rx="5" fill="#F8B9C6" opacity="0.5" />
      <path
        d="M-8 186 C40 160 60 128 100 108 C144 86 172 62 232 22"
        stroke="#FFFFFF"
        strokeWidth="22"
        fill="none"
        strokeLinecap="round"
      />
      <path
        d="M104 210 C112 160 96 120 128 84"
        stroke="#FFFFFF"
        strokeWidth="14"
        fill="none"
        strokeLinecap="round"
      />
      <path
        d={routePath}
        stroke={routeColor}
        strokeWidth="4"
        strokeDasharray="0.5 9"
        strokeLinecap="round"
        fill="none"
      />
      {bumpPositions.map((p) => (
        <g key={`${p.x}-${p.y}`}>
          <circle cx={p.x} cy={p.y} r="6.5" fill="#FFD54A" />
          <path
            d={`M${p.x - 3.4} ${p.y + 1.6} q3.4 -4.4 6.8 0`}
            stroke="#9E1F3E"
            strokeWidth="1.8"
            fill="none"
            strokeLinecap="round"
          />
        </g>
      ))}
      <circle cx="20" cy="176" r="6" fill="#FFFFFF" stroke={routeColor} strokeWidth="3" />
      <g transform="translate(192 6)">
        <path
          d="M12 2C6.5 2 2.4 6.1 2.4 11.3 2.4 17.6 12 28 12 28s9.6-10.4 9.6-16.7C21.6 6.1 17.5 2 12 2z"
          fill="#9E1F3E"
        />
        <circle cx="12" cy="11" r="4.4" fill="#FFFFFF" />
      </g>
    </svg>
  );
}
