import SwiftUI

struct InfoView: View {
    @ObservedObject var manager: MeasurementManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 현재 상태
                    statusSection

                    // 측정 기준
                    standardsSection

                    // 사용 안내
                    guideSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("측정 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    // MARK: - 현재 측정 상태

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("현재 측정 상태")

            VStack(spacing: 10) {
                infoRow("바닥 면적",
                        manager.floorArea > 0
                            ? String(format: "%.2f m²", manager.floorArea)
                            : "스캔 중...")

                infoRow("적용 간격",
                        manager.floorArea > 0
                            ? String(format: "%.2f m", manager.spacing)
                            : "--")

                infoRow("간격 기준",
                        manager.floorArea < 14
                            ? "14m² 미만 → 0.5m"
                            : "14m² 이상 → 0.75m")

                infoRow("공간 크기",
                        manager.roomDimensions.x > 0
                            ? String(format: "%.2f × %.2f m",
                                     manager.roomDimensions.x,
                                     manager.roomDimensions.y)
                            : "--")

                infoRow("포인트 수", "\(manager.points.count)개")
                infoRow("확인 완료", "\(manager.checkedCount) / \(manager.points.count)")
                infoRow("경과 시간", manager.formattedTime)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - 측정 기준

    private var standardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("바닥충격음 차단성능 측정 기준")

            VStack(alignment: .leading, spacing: 10) {
                Text("KS F 2810-1 / KS F 2810-2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)

                guideLine("측정 바닥면적 14m² 이상: 포인트 간격 0.75m")
                guideLine("측정 바닥면적 14m² 미만: 포인트 간격 0.5m")
                guideLine("측정 포인트: 5개 (역Z 패턴: 1우상→2좌상→3중앙→4우하→5좌하)")
                guideLine("포인트 위치: 각 벽에서 가로/세로 방향으로 정확히 간격만큼 안쪽")
                guideLine("3번 중앙점: 1→5 대각선의 중간점 (= 2→4 중간점)")
                guideLine("가진실(상층) / 수음실(하층) 동일 배치")
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - 사용 안내

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("사용 안내")

            VStack(alignment: .leading, spacing: 14) {
                stepGuide(1, "기준점 + 가로 측정",
                          "바닥의 기준 모서리를 탭하고, 가로 끝점을 탭하세요. 눈금자 라인으로 가로 길이가 표시됩니다.")

                stepGuide(2, "세로 측정",
                          "기준점에서 수직 방향의 세로 끝점을 탭하세요. 기준점은 공유되므로 다시 탭할 필요 없습니다.")

                stepGuide(3, "포인트 확인",
                          "5개 포인트가 자동 배치됩니다. 간격은 가로/세로 각각 벽에서 정확히 0.75m(또는 0.5m)입니다. 중앙점은 2→5 대각선의 중간점입니다.")
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Components

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private func guideLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.orange)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
        }
    }

    private func stepGuide(_ num: Int, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.5, green: 0.3, blue: 1.0))
                    .frame(width: 28, height: 28)
                Text("\(num)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}
