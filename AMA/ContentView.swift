import SwiftUI

struct ContentView: View {
    @StateObject private var manager = MeasurementManager()

    var body: some View {
        ZStack {
            ARViewContainer(manager: manager)
                .ignoresSafeArea()

            // ★ 화면 중앙 조준선 (에임) — 측정 단계에서만 표시
            if manager.tapStep.rawValue <= 3 {
                aimReticle
            }

            VStack(spacing: 0) { topBar; Spacer(); bottomBar }

            // 사이드 버튼
            VStack(spacing: 14) {
                Spacer()
                sideBtn("info.circle.fill", "INFO") { manager.showInfoSheet = true }
                sideBtn("arrow.counterclockwise", "RESET") { manager.reset() }
                Spacer().frame(height: 160)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .sheet(isPresented: $manager.showResultSheet) {
            if let r = manager.currentResult {
                ResultView(result: r) { manager.showResultSheet = false }
            }
        }
        .sheet(isPresented: $manager.showInfoSheet) { InfoView(manager: manager) }
    }

    // MARK: - 조준선 (에임)

    private var aimReticle: some View {
        // 단계별 색상: 기준점/가로=주황, 세로=시안
        let color: Color = manager.tapStep == .depthEnd ? .cyan : .orange
        return ZStack {
            // 바깥 원
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 60, height: 60)
            // 십자선
            Rectangle().fill(color).frame(width: 2, height: 22)
            Rectangle().fill(color).frame(width: 22, height: 2)
            // 중앙 점
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            // 바깥 흰 외곽 (대비)
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                .frame(width: 64, height: 64)
        }
        .shadow(color: .black.opacity(0.5), radius: 2)
    }

    // MARK: - 상단

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if manager.tapStep == .widthEnd || manager.tapStep == .depthEnd {
                        manager.undo()
                    } else { manager.reset() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }

                // 3단계 인디케이터
                HStack(spacing: 0) {
                    sDot("기준점", 1, manager.tapStep.rawValue >= 1, .orange)
                    sLine(manager.tapStep.rawValue >= 2)
                    sDot("가로끝", 2, manager.tapStep.rawValue >= 2, .orange)
                    sLine(manager.tapStep.rawValue >= 3)
                    sDot("세로끝", 3, manager.tapStep.rawValue >= 3, .cyan)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.4))
                .cornerRadius(16)

                Spacer()
                if manager.floorArea > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "square.fill").font(.system(size: 8))
                        Text(String(format: "%.2fm²", manager.floorArea))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.green.opacity(0.85))
                    .cornerRadius(6)
                }
            }

            Text("측정 포인트에 마킹")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            // 측정값 표시
            if manager.measuredWidth > 0 || manager.measuredDepth > 0 {
                HStack(spacing: 12) {
                    if manager.measuredWidth > 0 {
                        tag("가로 \(String(format: "%.2fm", manager.measuredWidth))", .orange)
                    }
                    if manager.measuredDepth > 0 {
                        tag("세로 \(String(format: "%.2fm", manager.measuredDepth))", .cyan)
                    }
                    if manager.floorArea > 0 {
                        tag("간격 \(String(format: "%.2fm", manager.spacing))", .green)
                    }
                }
            }

            if manager.tapStep == .pointsReady || manager.tapStep == .complete {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(manager.formattedDate)
                            .font(.system(size: 12, design: .monospaced))
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.system(size: 10))
                            Text(manager.formattedTime)
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                .padding(10)
                .background(Color.black.opacity(0.55))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16).padding(.top, 56)
    }

    // MARK: - 하단

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // 포인트 체크리스트
            if manager.tapStep == .pointsReady || manager.tapStep == .complete {
                HStack(spacing: 10) {
                    ForEach(manager.points) { p in
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(p.isChecked ? Color.green
                                          : p.distanceToUser <= manager.checkRadius * 2 ? Color.yellow
                                          : p.id == 3 ? Color.red : Color.orange)
                                    .frame(width: 32, height: 32)
                                if p.isChecked {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(p.id)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            if p.isChecked {
                                Text("✓").font(.system(size: 9)).foregroundColor(.green)
                            } else if p.distanceToUser < 100 {
                                Text(String(format: "%.1fm", p.distanceToUser))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.black.opacity(0.45))
                .cornerRadius(14)
            }

            // 상태 메시지
            Text(manager.statusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.black.opacity(0.65))
                .cornerRadius(20)

            // 탭 가이드
            switch manager.tapStep {
            case .origin:
                tapGuide("조준선을 기준 모서리에 맞추고 탭", icon: "scope", color: .orange)
            case .widthEnd:
                tapGuide("조준선을 가로 끝에 맞추고 탭 →", icon: "scope", color: .orange)
            case .depthEnd:
                tapGuide("조준선을 세로 끝에 맞추고 탭 ↓", icon: "scope", color: .cyan)
            default: EmptyView()
            }

            // 버튼
            if manager.tapStep == .pointsReady {
                actionButton("마킹 완료", color: .green) { manager.completeMarking() }
            } else if manager.tapStep == .complete {
                actionButton("결과 보기", color: Color(red: 0.35, green: 0.3, blue: 0.85)) {
                    manager.showResultSheet = true
                }
            }
        }
        .padding(.bottom, 36)
    }

    // MARK: - Components

    private func sDot(_ label: String, _ n: Int, _ active: Bool, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 7, weight: .medium))
                .foregroundColor(active ? color : .gray)
            ZStack {
                Circle().fill(active ? color : Color.gray.opacity(0.5))
                    .frame(width: 20, height: 20)
                Text("\(n)").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
            }
        }
    }

    private func sLine(_ active: Bool) -> some View {
        Rectangle().fill(active ? Color.white.opacity(0.6) : Color.gray.opacity(0.4))
            .frame(width: 14, height: 2)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.black.opacity(0.5))
            .cornerRadius(6)
    }

    private func tapGuide(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill").font(.system(size: 18)).foregroundColor(color)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(color.opacity(0.25)).cornerRadius(20)
    }

    private func actionButton(_ text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(color).cornerRadius(12)
        }
        .padding(.horizontal, 40)
    }

    private func sideBtn(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.white).frame(width: 50, height: 50)
            .background(Color.black.opacity(0.45)).cornerRadius(12)
        }
    }
}
