# 돌봄 내비게이션 — 시장 검증 랜딩페이지

임산부 안심 내비게이션 '돌봄 내비게이션'의 베타테스터 모집 / 시장 반응 검증용 랜딩페이지입니다.

## 실행 방법

```bash
npm install
npm run dev        # http://localhost:3000
npm run build      # 프로덕션 빌드
npm run type-check # 타입 검사
```

## 환경변수 (.env.example 참고)

| 변수 | 설명 |
|---|---|
| `NEXT_PUBLIC_GA_ID` | GA4 측정 ID. 설정 시에만 이벤트 추적 활성화 |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Firebase 프로젝트 ID |
| `FIREBASE_API_KEY` | Firebase Web API Key (서버 전용) |

Firebase 변수 미설정 시 신청 폼은 **mock 모드**로 동작하며, 화면에 개발 환경임이 표시되고 실제 저장은 이루어지지 않습니다. 설정 시 Firestore `care_navigation_interest` 컬렉션에 REST API로 저장됩니다. Firestore 보안 규칙에서 해당 컬렉션의 `create`를 허용해야 합니다.

## 배포 전 확인 (TODO)

- `src/lib/constants.ts`의 `TODO_COMPANY` — 팀명, 문의 이메일, 배포 도메인 교체
- 개인정보처리방침 정식 페이지 게시 (현재 푸터에 요약 문구만 존재)
- Firestore 보안 규칙: 쓰기(create)만 허용, 읽기 차단 권장
- GA4 속성 생성 후 `NEXT_PUBLIC_GA_ID` 설정
- OG 이미지 추가 (`app/opengraph-image.png`)
