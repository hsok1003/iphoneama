import SwiftUI

struct ResultView: View {
    let result: MeasurementResult
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 완료 헤더
                    header

                    // 측정 요약
                    summaryCard

                    // 포인트 상세
                    pointsCard

                    // 배치도
                    diagramCard

                    // 벽 치수
                    dimensionsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("측정 결과")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { onDismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    ShareLink(item: generateReport()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.green)
            Text("마킹 완료")
                .font(.system(size: 24, weight: .bold))
            Text(dateString(result.timestamp))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("소요 시간: \(durationString(result.duration))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 12)
    }

    // MARK: - 측정 요약

    private var summaryCard: some View {
        VStack(spacing: 14) {
            row("square.dashed", "바닥 면적", String(format: "%.2f m²", result.floorArea))
            Divider()
            row("ruler", "포인트 간격",
                String(format: "%.2f m (%@)",
                       result.spacing,
                       result.floorArea < 14 ? "14m² 미만" : "14m² 이상"))
            Divider()
            row("mappin.and.ellipse", "측정 포인트", "\(result.points.count)개")
            Divider()
            row("arrow.left.and.right", "공간 크기",
                String(format: "%.2f × %.2f m",
                       result.roomDimensions.x,
                       result.roomDimensions.y))
            Divider()
            row("checkmark.circle", "확인 포인트",
                "\(result.points.filter { $0.isChecked }.count) / \(result.points.count)")
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }

    // MARK: - 포인트 상세 좌표

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("포인트 좌표")
                .font(.headline)

            ForEach(result.points) { p in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(p.isChecked ? Color.green : Color.orange)
                            .frame(width: 30, height: 30)
                        Text("\(p.id)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(p.label)")
                            .font(.subheadline.weight(.medium))
                        Text(String(format: "X: %.3f  Y: %.3f  Z: %.3f",
                                    p.position.x, p.position.y, p.position.z))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if p.isChecked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                if p.id < 5 { Divider() }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }

    // MARK: - 배치도

    private var diagramCard: some View {
        VStack(spacing: 8) {
            Text("포인트 배치도")
                .font(.headline)

            ZStack {
                // 바닥 영역
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(red: 0.4, green: 0.3, blue: 1.0), lineWidth: 2)
                    )

                // 연결선
                Canvas { context, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let s: CGFloat = 55

                    let offsets: [CGPoint] = [
                        .zero,
                        CGPoint(x: 0, y: -s),
                        CGPoint(x: 0, y: s),
                        CGPoint(x: s, y: 0),
                        CGPoint(x: -s, y: 0)
                    ]

                    // 연결선
                    for i in 1..<5 {
                        var path = Path()
                        path.move(to: c)
                        path.addLine(to: CGPoint(x: c.x + offsets[i].x, y: c.y + offsets[i].y))
                        context.stroke(path,
                                       with: .color(.gray.opacity(0.4)),
                                       style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    }
                }
                .frame(width: 200, height: 200)

                // 포인트
                ForEach(0..<5) { i in
                    let offset = pointOffset(i)
                    Circle()
                        .fill(i == 2 ? Color.red : Color.orange)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: offset.x * 55, y: offset.y * 55)
                }

                // 간격 표시
                Text(String(format: "%.2fm", result.spacing))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .offset(x: 16, y: -30)
            }
            .frame(height: 220)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }

    // MARK: - 벽 치수

    private var dimensionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("벽 치수")
                .font(.headline)

            ForEach(Array(result.wallEdges.enumerated()), id: \.offset) { idx, edge in
                HStack {
                    Text("벽 \(idx + 1)")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f m", edge.length))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }

    // MARK: - Helpers

    private func row(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 22)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
        }
    }

    private func pointOffset(_ i: Int) -> CGPoint {
        switch i {
        case 0: return CGPoint(x: 1, y: -1)   // 1: 우상
        case 1: return CGPoint(x: -1, y: -1)  // 2: 좌상
        case 2: return .zero                   // 3: 중앙
        case 3: return CGPoint(x: 1, y: 1)    // 4: 우하
        case 4: return CGPoint(x: -1, y: 1)   // 5: 좌하
        default: return .zero
        }
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy년 M월 d일 HH:mm:ss"
        return f.string(from: d)
    }

    private func durationString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d분 %02d초", m, s)
    }

    private func generateReport() -> String {
        var r = """
        ═══════════════════════════════
        AMA 측정 결과 리포트
        ═══════════════════════════════
        날짜: \(dateString(result.timestamp))
        소요시간: \(durationString(result.duration))

        ■ 공간 정보
        바닥 면적: \(String(format: "%.2f m²", result.floorArea))
        공간 크기: \(String(format: "%.2f × %.2f m", result.roomDimensions.x, result.roomDimensions.y))
        포인트 간격: \(String(format: "%.2f m", result.spacing))

        ■ 측정 포인트 좌표\n
        """
        for p in result.points {
            r += "  포인트 \(p.id) (\(p.label)): "
            r += String(format: "(%.3f, %.3f, %.3f)", p.position.x, p.position.y, p.position.z)
            r += p.isChecked ? " ✓\n" : "\n"
        }
        r += "\n■ 벽 치수\n"
        for (i, edge) in result.wallEdges.enumerated() {
            r += "  벽 \(i+1): \(String(format: "%.2f m", edge.length))\n"
        }
        r += "\n═══════════════════════════════\n"
        r += "Generated by AMA (Auto Marking App)\n"
        return r
    }
}
