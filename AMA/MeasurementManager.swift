import Foundation
import ARKit
import simd
import UIKit

// MARK: - Models

struct MeasurementPoint: Identifiable {
    let id: Int
    let position: SIMD3<Float>
    var isChecked: Bool = false
    var distanceToUser: Float = 999
    var label: String {
        switch id {
        case 1: return "우상"
        case 2: return "좌상"
        case 3: return "중앙"
        case 4: return "우하"
        case 5: return "좌하"
        default: return "포인트 \(id)"
        }
    }
}

struct WallEdge: Identifiable {
    let id = UUID()
    let start: SIMD3<Float>
    let end: SIMD3<Float>
    var length: Float { simd_distance(start, end) }
}

struct RoomRect {
    let origin: SIMD3<Float>
    let widthDir: SIMD3<Float>
    let depthDir: SIMD3<Float>
    let width: Float
    let depth: Float
    let floorY: Float
    var area: Float { width * depth }
    var corners: [SIMD3<Float>] {
        let w: SIMD3<Float> = widthDir * width
        let d: SIMD3<Float> = depthDir * depth
        let c0: SIMD3<Float> = origin
        let c1: SIMD3<Float> = origin + w
        let c2: SIMD3<Float> = origin + w + d
        let c3: SIMD3<Float> = origin + d
        return [c0, c1, c2, c3]
    }
}

struct MeasurementResult: Identifiable {
    let id = UUID()
    let timestamp: Date
    let points: [MeasurementPoint]
    let floorArea: Float
    let spacing: Float
    let duration: TimeInterval
    let wallEdges: [WallEdge]
    let roomDimensions: SIMD2<Float>
}

// MARK: - 3단계 탭

enum TapStep: Int {
    case origin = 1         // 기준점 (가로시작 = 세로시작)
    case widthEnd = 2       // 가로 끝점
    case depthEnd = 3       // 세로 끝점
    case pointsReady = 4
    case complete = 5
}

// MARK: - MeasurementManager

class MeasurementManager: ObservableObject {

    @Published var tapStep: TapStep = .origin
    @Published var points: [MeasurementPoint] = []
    @Published var wallEdges: [WallEdge] = []
    @Published var floorArea: Float = 0
    @Published var roomDimensions: SIMD2<Float> = .zero
    @Published var statusMessage: String = "조준선을 가로 시작점에 맞추고 탭"
    @Published var cameraPosition: SIMD3<Float> = .zero
    @Published var elapsedTime: TimeInterval = 0
    @Published var startDate: Date = Date()
    @Published var currentResult: MeasurementResult?
    @Published var showResultSheet = false
    @Published var showInfoSheet = false
    @Published var checkedCount: Int = 0
    @Published var resetToken: Int = 0   // ★ 초기화 감지용

    @Published var originPoint: SIMD3<Float>?
    @Published var widthEndPoint: SIMD3<Float>?
    @Published var depthEndPoint: SIMD3<Float>?

    @Published var measuredWidth: Float = 0
    @Published var measuredDepth: Float = 0
    @Published var roomRect: RoomRect?

    // ★ 가로/세로 보정 계수 (실제/AR 비율). AR 오차가 가로·세로 다를 수 있어 분리
    // 사용자가 INFO 화면에서 줄자 측정값으로 미세조정
    @Published var calibrationW: Float = 0.96   // 가로 보정
    @Published var calibrationD: Float = 1.00   // 세로 보정

    var spacing: Float { floorArea < 14.0 ? 0.5 : 0.75 }
    let checkRadius: Float = 0.4
    private var timer: Timer?

    var formattedTime: String {
        let m = Int(elapsedTime) / 60
        let s = Int(elapsedTime) % 60
        let ms = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d", m, s, ms)
    }
    var formattedDate: String {
        let f = DateFormatter(); f.dateFormat = "M/d/yy, HH:mm:ss"
        return f.string(from: startDate)
    }

    // MARK: - 탭 처리

    func handleTap(position: SIMD3<Float>) {
        switch tapStep {
        case .origin:
            originPoint = position
            tapStep = .widthEnd
            statusMessage = "조준선을 가로 끝에 맞추고 탭 →"
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        case .widthEnd:
            widthEndPoint = position
            // 표시는 보정된 실제 거리
            measuredWidth = hDist(from: originPoint!, to: position) * calibrationW
            tapStep = .depthEnd
            statusMessage = String(format: "가로 %.2fm ✓ — 세로 끝에 맞추고 탭 ↓", measuredWidth)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        case .depthEnd:
            depthEndPoint = position
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            buildAndPlace(depthTap: position)

        default: break
        }
    }

    private func hDist(from a: SIMD3<Float>, to b: SIMD3<Float>) -> Float {
        let dx = b.x - a.x; let dz = b.z - a.z
        return sqrtf(dx * dx + dz * dz)
    }

    // MARK: - 직사각형 구성 + 포인트 배치

    private func buildAndPlace(depthTap: SIMD3<Float>) {
        guard let o = originPoint, let we = widthEndPoint else { return }
        let calW: Float = calibrationW
        let calD: Float = calibrationD

        // 가로 방향 (XZ 평면) = 기준점 → 가로끝 실제 방향
        let wDir: SIMD3<Float> = simd_normalize(SIMD3<Float>(we.x - o.x, 0, we.z - o.z))

        // ★ 세로 방향 = 가로에 직각(수직)으로 강제 (직사각형 방 가정 → 포인트 안 틀어짐)
        let tapVec: SIMD3<Float> = SIMD3<Float>(depthTap.x - o.x, 0, depthTap.z - o.z)
        let perpDir: SIMD3<Float> = SIMD3<Float>(-wDir.z, 0, wDir.x)
        // 탭이 어느 쪽인지(부호) 판단
        let proj: Float = simd_dot(tapVec, perpDir)
        let finalDDir: SIMD3<Float> = proj >= 0 ? perpDir : -perpDir

        // AR 공간의 원시 거리
        let arWidth: Float = hDist(from: o, to: we)
        // ★ 세로 길이 = 가로에 수직인 방향으로의 거리 (직각 투영)
        let arDepth: Float = abs(proj)

        // 보정된 실제 거리 (표시/면적/간격 계산용)
        measuredWidth = arWidth * calW
        measuredDepth = arDepth * calD

        let floorY: Float = (o.y + we.y + depthTap.y) / 3
        let origin: SIMD3<Float> = SIMD3<Float>(o.x, floorY, o.z)

        // ★ RoomRect 기하학은 원본 AR 크기 사용 (실제 탭한 모서리와 일치)
        //    보정은 표시 숫자와 간격 계산에만 적용
        let rect = RoomRect(origin: origin, widthDir: wDir, depthDir: finalDDir,
                            width: arWidth, depth: arDepth, floorY: floorY)
        roomRect = rect
        let crossY: Float = wDir.x * finalDDir.z - wDir.z * finalDDir.x
        floorArea = measuredWidth * measuredDepth * abs(crossY)
        roomDimensions = SIMD2(measuredWidth, measuredDepth)

        let c = rect.corners
        wallEdges = [
            WallEdge(start: c[0], end: c[1]),
            WallEdge(start: c[1], end: c[2]),
            WallEdge(start: c[2], end: c[3]),
            WallEdge(start: c[3], end: c[0]),
        ]

        // ★ 포인트 배치 (역Z 패턴)
        //   2(좌상) ─── 1(우상)
        //   │    3(중앙)    │
        //   5(좌하) ─── 4(우하)
        let s: Float = spacing
        let swReal: Float = min(s, measuredWidth / 3)   // 물리적 간격(m)
        let sdReal: Float = min(s, measuredDepth / 3)
        // AR 공간 오프셋 = 물리거리 / 보정계수 (포인트를 실제 위치에 배치)
        let swAR: Float = swReal / calW
        let sdAR: Float = sdReal / calD

        let wNear: SIMD3<Float> = wDir * swAR
        let wFar: SIMD3<Float> = wDir * (arWidth - swAR)
        let dNear: SIMD3<Float> = finalDDir * sdAR
        let dFar: SIMD3<Float> = finalDDir * (arDepth - sdAR)

        let p1: SIMD3<Float> = origin + wFar + dNear   // 1: 우상
        let p2: SIMD3<Float> = origin + wNear + dNear  // 2: 좌상
        let p4: SIMD3<Float> = origin + wFar + dFar    // 4: 우하
        let p5: SIMD3<Float> = origin + wNear + dFar   // 5: 좌하
        let p3: SIMD3<Float> = (p1 + p5) / 2           // 3: 중앙

        points = [
            MeasurementPoint(id: 1, position: p1),
            MeasurementPoint(id: 2, position: p2),
            MeasurementPoint(id: 3, position: p3),
            MeasurementPoint(id: 4, position: p4),
            MeasurementPoint(id: 5, position: p5),
        ]

        statusMessage = String(format: "%.2f × %.2fm = %.1fm² (간격 %.2fm)",
                               measuredWidth, measuredDepth, floorArea, s)
        tapStep = .pointsReady
        startTimer()
    }

    // MARK: - 카메라 업데이트

    func updateCameraPosition(_ pos: SIMD3<Float>) {
        cameraPosition = pos
        guard tapStep == .pointsReady else { return }
        for i in 0..<points.count {
            let dx = pos.x - points[i].position.x
            let dz = pos.z - points[i].position.z
            points[i].distanceToUser = sqrtf(dx * dx + dz * dz)
            if points[i].distanceToUser <= checkRadius && !points[i].isChecked {
                points[i].isChecked = true
                checkedCount = points.filter { $0.isChecked }.count
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    func completeMarking() {
        stopTimer(); tapStep = .complete
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        currentResult = MeasurementResult(
            timestamp: startDate, points: points, floorArea: floorArea, spacing: spacing,
            duration: elapsedTime, wallEdges: wallEdges, roomDimensions: roomDimensions)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showResultSheet = true
        }
    }

    func undo() {
        switch tapStep {
        case .widthEnd:
            originPoint = nil; tapStep = .origin
            statusMessage = "조준선을 가로 시작점에 맞추고 탭"
        case .depthEnd:
            widthEndPoint = nil; measuredWidth = 0; tapStep = .widthEnd
            statusMessage = "조준선을 가로 끝에 맞추고 탭 →"
        default: break
        }
    }

    private func startTimer() {
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedTime = Date().timeIntervalSince(self.startDate)
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    func reset() {
        stopTimer(); tapStep = .origin
        statusMessage = "조준선을 가로 시작점에 맞추고 탭"
        points = []; wallEdges = []; floorArea = 0; roomDimensions = .zero
        elapsedTime = 0; currentResult = nil; showResultSheet = false
        checkedCount = 0; roomRect = nil
        originPoint = nil; widthEndPoint = nil; depthEndPoint = nil
        measuredWidth = 0; measuredDepth = 0
        resetToken += 1   // ★ AR 뷰가 초기화를 감지하도록 토큰 증가
    }
}
