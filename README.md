# ClipBoard

macOS용 클립보드 매니저. Windows의 Win+V 클립보드와 유사한 UX를 제공합니다.

## 기능

- 텍스트 및 이미지 클립보드 히스토리 관리
- 단축키로 클립보드 패널 열기 (기본: `Cmd+Shift+V`)
- 방향키로 선택, Enter로 붙여넣기
- 홀드 모드: 단축키를 누르고 있는 동안 패널 유지, 떼면 붙여넣기
- 패널 외부 클릭 시 자동 닫힘
- 설정 가능: 단축키, 홀드 키, 붙여넣기 모드, 패널 투명도, 배경색

## 요구사항

- macOS 13.0+
- 접근성 권한 (시스템 설정 > 개인 정보 보호 및 보안 > 접근성)

## 설치

```bash
git clone https://github.com/breakpack/Win_clip.git
cd Win_clip
./build.sh install
```

빌드 후 `/Applications/ClipBoard.app`에 설치되고 자동 실행됩니다.

### Homebrew

```bash
brew install --cask breakpack/winclip/win-clip
```

## 빌드만 하기

```bash
# 디버그 빌드
./build.sh

# 릴리즈 빌드 (Universal Binary + DMG)
./build.sh release
```

## 사용법

1. 앱 실행 후 메뉴바에 📋 아이콘 표시
2. 텍스트나 이미지를 복사 (Cmd+C)
3. `Cmd+Shift+V`로 클립보드 패널 열기
4. `↑↓` 방향키로 항목 선택
5. `Enter`로 붙여넣기 / `Delete`로 삭제 / `ESC`로 닫기

## 라이선스

MIT License
