# AMA - 무료 IPA 빌드 & Sideloadly 설치 가이드

Apple Developer Program(유료) 없이, **무료로** IPA를 만들어
Sideloadly로 iPhone에 설치하는 방법입니다.

> ✅ Mac 불필요
> ✅ 유료 멤버십 불필요 (무료 Apple 계정만 있으면 됨)
> ⚠️ 무료 계정으로 설치한 앱은 **7일마다 재서명** 필요 (Sideloadly로 다시 설치)

---

## 전체 흐름

```
1. GitHub에 코드 올리기
2. GitHub Actions가 무료 Mac 서버에서 빌드 → unsigned IPA 생성
3. IPA 다운로드
4. PC(Windows/Mac)에 Sideloadly 설치
5. iPhone 연결 → IPA를 본인 Apple ID로 서명하며 설치
```

---

## STEP 1: GitHub에 코드 올리기

이미 GitHub에 올리셨다면, 이 프로젝트의 새 파일들로 업데이트하세요.

특히 중요한 파일:
- `.github/workflows/build-unsigned.yml` ← 이게 빌드를 담당합니다

GitHub 저장소에 이 파일이 포함되도록 전체 프로젝트를 다시 업로드하면 됩니다.

> **주의**: `.github` 폴더는 숨김 폴더라 일부 압축 해제 프로그램에서 안 보일 수 있습니다.
> 안 보이면 "숨김 파일 보기"를 켜세요.

---

## STEP 2: 자동 빌드 실행

### 방법 A: 자동 (코드 push 시)
코드를 main 브랜치에 올리면 자동으로 빌드가 시작됩니다.

### 방법 B: 수동 실행
1. GitHub 저장소 → 상단 **Actions** 탭
2. 왼쪽 목록에서 **Build Unsigned IPA** 클릭
3. 오른쪽 **Run workflow** → 초록 **Run workflow** 버튼

빌드는 약 3~7분 걸립니다. 진행 중엔 노란 점, 완료되면 초록 체크(✓)가 뜹니다.

> 빌드가 빨간 X로 실패하면, 클릭해서 로그를 확인하세요.
> 어느 단계에서 실패했는지 알려주시면 고쳐드립니다.

---

## STEP 3: IPA 다운로드

1. **Actions** 탭 → 방금 성공한 빌드(초록 체크) 클릭
2. 페이지 맨 아래 **Artifacts** 섹션
3. **AMA-unsigned-ipa** 클릭 → zip 다운로드
4. 압축 해제하면 `AMA-unsigned.ipa` 파일이 나옵니다

---

## STEP 4: Sideloadly 설치 (PC)

1. [sideloadly.io](https://sideloadly.io) 접속
2. Windows 또는 Mac 버전 다운로드 → 설치
3. **iTunes**도 설치되어 있어야 합니다 (Windows)
   - [apple.com/itunes](https://www.apple.com/itunes/) 또는 Microsoft Store
   - iCloud(드라이버용)도 권장

---

## STEP 5: iPhone에 설치

1. iPhone을 USB 케이블로 PC에 연결
2. iPhone에서 "이 컴퓨터를 신뢰" → **신뢰** 탭
3. **Sideloadly** 실행
4. 상단에 연결된 iPhone이 표시됨
5. **IPA 파일**을 Sideloadly 창에 드래그 (또는 폴더 아이콘으로 선택)
6. **Apple Account** 칸에 본인 Apple ID(이메일) 입력
7. **Start** 클릭
8. Apple ID 비밀번호 입력
   - 2단계 인증 쓰면 [appleid.apple.com](https://appleid.apple.com)에서
     **앱 암호(App-Specific Password)** 생성해서 사용
9. 설치 진행... "Done" 뜨면 완료

---

## STEP 6: iPhone에서 신뢰 설정

설치 후 앱을 바로 못 열고 "신뢰할 수 없는 개발자" 뜨면:

1. iPhone **설정 → 일반 → VPN 및 기기 관리**
2. 본인 Apple ID 항목 탭 → **신뢰**
3. 이제 홈 화면에서 AMA 앱 실행 가능!

---

## 7일마다 재설치 (무료 계정 한계)

무료 Apple 계정으로 서명한 앱은 **7일 후 만료**됩니다.
만료되면 STEP 5를 다시 하면 됩니다 (IPA는 그대로 재사용).

### 자동 재서명 (선택)
Sideloadly에 같은 Wi-Fi에서 자동 재서명하는 기능이 있고,
**AltStore**를 쓰면 더 편하게 자동 갱신할 수 있습니다.

---

## 무료 계정 제약 정리

| 항목 | 무료 계정 | 유료 ($99/년) |
|------|----------|--------------|
| 앱 유효기간 | 7일 | 1년 |
| 동시 설치 앱 수 | 3개 | 무제한 |
| 설치 기기 | 본인 기기 | 100대 |
| TestFlight 배포 | 불가 | 가능 |

---

## 자주 묻는 질문

**Q. GitHub Actions 빌드는 정말 무료인가요?**
네. Public 저장소는 완전 무료, Private도 월 2,000분 무료입니다.
빌드 1회에 5분 정도이니 한 달에 수백 번 가능합니다.

**Q. Apple ID 비밀번호를 Sideloadly에 넣어도 안전한가요?**
Sideloadly는 Apple 서버에 직접 인증합니다. 불안하면 2단계 인증 +
앱 암호를 사용하세요 (비밀번호 노출 없음).

**Q. 카메라/AR 기능이 무료 계정에서도 되나요?**
네. 서명 방식만 다를 뿐 앱 기능은 동일합니다.

---

## 문제 해결

- **빌드 실패**: Actions 로그 확인 → 어느 단계인지 알려주세요
- **Sideloadly에서 설치 실패**: iTunes/iCloud 설치 확인, 케이블 교체
- **"앱을 사용할 수 없음"**: 7일 만료 → 재설치
- **3개 앱 제한**: 다른 사이드로드 앱 삭제 후 재시도
