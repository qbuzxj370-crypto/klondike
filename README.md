# klondike

A new Flutter project.

## Getting Started

이 프로젝트는 솔리테어 카드 게임 중 klondike 게임을 플러터로 구현하려는 프로젝트입니다. 

- **v0.0.2**: widgets를 세분화하고 `main.dart`에는 페이지 로드만 작성하여 `main.dart` 내 소스를 최소화되도록 리펙토링 하였습니다.
- **v0.0.3**: Stock이 비었을 때 Reset(Stock 다시 채우기)을 더 직관적으로 사용할 수 있도록 UX를 개선했습니다.
  - 엔진에는 이미 구현되어 있던 Reset 로직(Stock이 비었을 때 다시 탭하면 Waste의 카드가 Stock으로 되돌아감)을 UI에서 안정적으로 동작하도록 수정했습니다.
  - Stock이 비어 있을 때 빈 영역 터치가 인식되지 않던 **HitTest 문제를 해결**하기 위해 Stock의 터치 영역을 조정했습니다.
  - Reset이 가능한 상태에서 **새로고침(Refresh) 아이콘을 표시**하고, 해당 아이콘을 눌러 Stock을 다시 채울 수 있도록 개선했습니다.
