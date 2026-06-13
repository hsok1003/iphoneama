import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var manager: MeasurementManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        arView.session.delegate = context.coordinator

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        arView.addSubview(coaching)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // ★ 초기화(RESET) 감지 → AR 마커 전부 제거
        if context.coordinator.lastResetToken != manager.resetToken {
            context.coordinator.lastResetToken = manager.resetToken
            context.coordinator.clearAll()
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(manager: manager) }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSessionDelegate {
        let manager: MeasurementManager
        weak var arView: ARView?
        private var allAnchors: [AnchorEntity] = []
        private var pointAnchors: [Int: AnchorEntity] = [:]
        private var markerEntities: [Int: ModelEntity] = [:]
        private var numberEntities: [Int: ModelEntity] = [:]
        private var distEntities: [Int: ModelEntity] = [:]
        private var labelAnchors: [AnchorEntity] = []
        private var hasRendered = false
        var lastResetToken = 0   // ★ 초기화 감지용

        init(manager: MeasurementManager) { self.manager = manager }

        // MARK: - 탭

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            guard manager.tapStep.rawValue <= 3 else { return }

            // ★ 탭 위치가 아닌 "화면 정중앙(조준선)"에서 측정
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            // 정확도 우선순위: 감지된 평면 메시 > 평면 무한확장 > 추정 평면
            var hit = arView.raycast(from: center, allowing: .existingPlaneGeometry, alignment: .horizontal).first
            if hit == nil {
                hit = arView.raycast(from: center, allowing: .existingPlaneInfinite, alignment: .horizontal).first
            }
            if hit == nil {
                hit = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal).first
            }
            guard let h = hit else { return }

            let pos = SIMD3<Float>(h.worldTransform.columns.3.x,
                                    h.worldTransform.columns.3.y,
                                    h.worldTransform.columns.3.z)

            let step = manager.tapStep

            // 끝점 마커
            let color: UIColor = step == .depthEnd ? .systemCyan : .systemOrange
            placeEndpoint(at: pos, color: color)

            // 가로 끝점 → 눈금자 라인
            if step == .widthEnd, let o = manager.originPoint {
                drawRuler(from: o, to: pos, color: .systemOrange, label: "가로")
            }

            // 세로 끝점 → 눈금자 라인 (기준점에서 수직)
            if step == .depthEnd, let o = manager.originPoint {
                drawRuler(from: o, to: pos, color: .systemCyan, label: "세로")
            }

            manager.handleTap(position: pos)

            // 포인트 배치 후 방 렌더링
            if manager.tapStep == .pointsReady && !hasRendered {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.renderRoom()
                }
            }
        }

        // MARK: - 끝점 마커 (◇ 다이아몬드 + 폴)

        private func placeEndpoint(at pos: SIMD3<Float>, color: UIColor) {
            guard let arView else { return }
            let a = AnchorEntity(world: pos)

            // 바닥 원형 (색상)
            let dot = ModelEntity(
                mesh: MeshResource.generatePlane(width: 0.06, depth: 0.06, cornerRadius: 0.03),
                materials: [UnlitMaterial(color: color)])
            dot.position.y = 0.003
            a.addChild(dot)

            // 세로 기둥 (색상, 잘 보이게)
            let pole = ModelEntity(
                mesh: MeshResource.generateBox(width: 0.008, height: 0.12, depth: 0.008),
                materials: [UnlitMaterial(color: color)])
            pole.position.y = 0.06
            a.addChild(pole)

            // 위 구슬
            let ball = ModelEntity(
                mesh: MeshResource.generateSphere(radius: 0.02),
                materials: [UnlitMaterial(color: color)])
            ball.position.y = 0.12
            a.addChild(ball)

            arView.scene.addAnchor(a)
            allAnchors.append(a)
        }

        // MARK: - ★ 측정 라인 (깔끔한 스타일)

        private func drawRuler(from a: SIMD3<Float>, to b: SIMD3<Float>,
                               color: UIColor, label: String) {
            guard let arView else { return }
            let y = (a.y + b.y) / 2 + 0.004
            let s = SIMD3<Float>(a.x, y, a.z)
            let e = SIMD3<Float>(b.x, y, b.z)
            let dist = simd_distance(SIMD2(a.x, a.z), SIMD2(b.x, b.z))
            guard dist > 0.01 else { return }

            let dir = simd_normalize(e - s)
            let totalLen = simd_distance(s, e)
            let mid = (s + e) / 2
            let angle = atan2(dir.x, dir.z)
            let perpAngle = angle + .pi / 2

            // 메인 라인 (선명한 색)
            addBoxUnlit(at: mid, w: totalLen, h: 0.003, d: 0.012,
                        color: color, angle: angle)

            // 양 끝 캡만 (눈금 틱 제거 → 깔끔)
            for ep in [s, e] {
                addBoxUnlit(at: ep, w: 0.06, h: 0.003, d: 0.012,
                            color: color, angle: perpAngle)
            }

            // 거리 라벨 (검정 배경 + 흰 글씨)
            let labelA = AnchorEntity(world: mid + SIMD3(0, 0.03, 0))
            let bg = ModelEntity(
                mesh: MeshResource.generatePlane(width: 0.20, depth: 0.06, cornerRadius: 0.02),
                materials: [UnlitMaterial(color: UIColor.black.withAlphaComponent(0.8))])
            bg.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
            labelA.addChild(bg)

            let distText = dist >= 1.0
                ? String(format: "%.2fm", dist)
                : String(format: "%.0fcm", dist * 100)
            let txt = ModelEntity(
                mesh: MeshResource.generateText(
                    distText, extrusionDepth: 0.003,
                    font: .systemFont(ofSize: 0.045, weight: .bold),
                    containerFrame: .zero, alignment: .center,
                    lineBreakMode: .byWordWrapping),
                materials: [UnlitMaterial(color: .white)])
            txt.position = SIMD3(-0.05, 0.005, 0)
            labelA.addChild(txt)

            arView.scene.addAnchor(labelA)
            allAnchors.append(labelA)
        }

        // MARK: - 방 렌더링

        private func renderRoom() {
            guard let arView, let rect = manager.roomRect else { return }
            hasRendered = true
            let y = rect.floorY
            let corners = rect.corners

            // 1) 바닥 경계선 (보라색, 선명)
            let purple = UIColor(red: 0.5, green: 0.35, blue: 1.0, alpha: 1.0)
            for i in 0..<4 {
                let s = SIMD3<Float>(corners[i].x, y + 0.005, corners[i].z)
                let e = SIMD3<Float>(corners[(i+1)%4].x, y + 0.005, corners[(i+1)%4].z)
                let d = simd_normalize(e - s)
                let len = simd_distance(s, e)
                addBoxUnlit(at: (s + e) / 2, w: len, h: 0.004, d: 0.015,
                            color: purple, angle: atan2(d.x, d.z))
            }

            // 2) 가로/세로 치수 라벨 (벽 중앙에)
            let topMid = (corners[0] + corners[1]) / 2
            makeLabelBG(at: SIMD3(topMid.x, y + 0.03, topMid.z),
                        text: String(format: "가로 %.2fm", rect.width), color: .systemOrange)
            let leftMid = (corners[0] + corners[3]) / 2
            makeLabelBG(at: SIMD3(leftMid.x, y + 0.03, leftMid.z),
                        text: String(format: "세로 %.2fm", rect.depth), color: .systemCyan)

            // 3) 면적 (중앙)
            let center = manager.points[2].position
            makeLabelBG(at: SIMD3(center.x, y + 0.30, center.z),
                        text: String(format: "%.1fm²  간격%.2fm", rect.area, manager.spacing),
                        color: .white)

            // 4) 포인트 (잘 보이게)
            renderPoints()
        }

        // MARK: - 포인트

        private func renderPoints() {
            guard let arView else { return }
            for p in manager.points {
                let a = AnchorEntity(world: p.position)
                let isCenter = p.id == 3
                let base: UIColor = isCenter ? .systemRed : .systemOrange

                // ★ 작은 X자 (정확한 지점 표시) — 대각선 2개
                let arm1 = ModelEntity(
                    mesh: MeshResource.generateBox(width: 0.08, height: 0.003, depth: 0.008),
                    materials: [UnlitMaterial(color: base)])
                arm1.position.y = 0.004
                arm1.orientation = simd_quatf(angle: .pi / 4, axis: SIMD3(0, 1, 0))
                a.addChild(arm1)

                let arm2 = ModelEntity(
                    mesh: MeshResource.generateBox(width: 0.08, height: 0.003, depth: 0.008),
                    materials: [UnlitMaterial(color: base)])
                arm2.position.y = 0.004
                arm2.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3(0, 1, 0))
                a.addChild(arm2)

                // 정중앙 아주 작은 점 (마킹 지점)
                let centerDot = ModelEntity(
                    mesh: MeshResource.generatePlane(width: 0.012, depth: 0.012, cornerRadius: 0.006),
                    materials: [UnlitMaterial(color: base)])
                centerDot.position.y = 0.005
                a.addChild(centerDot)
                markerEntities[p.id] = centerDot

                // 작은 번호 — 바닥에 평평하게 (X 옆에)
                let num = ModelEntity(
                    mesh: MeshResource.generateText(
                        "\(p.id)", extrusionDepth: 0.003,
                        font: .systemFont(ofSize: 0.05, weight: .bold),
                        containerFrame: .zero, alignment: .center,
                        lineBreakMode: .byWordWrapping),
                    materials: [UnlitMaterial(color: base)])
                num.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
                num.position = SIMD3(0.06, 0.006, 0.02)
                a.addChild(num)
                numberEntities[p.id] = num
                distEntities[p.id] = num

                arView.scene.addAnchor(a)
                pointAnchors[p.id] = a
            }
        }

        // MARK: - 유틸

        // UnlitMaterial 버전 (조명 영향 없이 항상 선명)
        private func addBoxUnlit(at pos: SIMD3<Float>, w: Float, h: Float, d: Float,
                                 color: UIColor, angle: Float) {
            guard let arView else { return }
            let a = AnchorEntity(world: pos)
            let e = ModelEntity(
                mesh: MeshResource.generateBox(width: w, height: h, depth: d),
                materials: [UnlitMaterial(color: color)])
            e.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
            a.addChild(e)
            arView.scene.addAnchor(a)
            allAnchors.append(a)
        }

        // 배경 있는 라벨 (검정 배경 + 색 글씨)
        private func makeLabelBG(at pos: SIMD3<Float>, text: String, color: UIColor) {
            guard let arView else { return }
            let a = AnchorEntity(world: pos)
            let bg = ModelEntity(
                mesh: MeshResource.generatePlane(width: 0.011 * Float(text.count) + 0.06, depth: 0.06, cornerRadius: 0.02),
                materials: [UnlitMaterial(color: UIColor.black.withAlphaComponent(0.8))])
            a.addChild(bg)
            let e = ModelEntity(
                mesh: MeshResource.generateText(
                    text, extrusionDepth: 0.002,
                    font: .systemFont(ofSize: 0.035, weight: .bold),
                    containerFrame: .zero, alignment: .center,
                    lineBreakMode: .byWordWrapping),
                materials: [UnlitMaterial(color: color)])
            e.position = SIMD3(-0.011 * Float(text.count) / 2, 0, 0.005)
            a.addChild(e)
            arView.scene.addAnchor(a)
            allAnchors.append(a)
            labelAnchors.append(a)
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let t = frame.camera.transform
            let pos = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.manager.updateCameraPosition(pos)
                for p in self.manager.points {
                    guard let m = self.markerEntities[p.id] else { continue }
                    // 체크되면 초록, 가까우면 노랑, 평소엔 빨강/주황
                    let c: UIColor = p.isChecked ? .systemGreen
                        : p.distanceToUser <= self.manager.checkRadius * 2 ? .systemYellow
                        : p.id == 3 ? .systemRed : .systemOrange
                    m.model?.materials = [UnlitMaterial(color: c)]
                }
                // 치수 라벨만 카메라를 향하도록 (포인트 번호는 바닥 고정)
                for la in self.labelAnchors {
                    let dir = pos - la.position(relativeTo: nil)
                    let ang = atan2(dir.x, dir.z)
                    la.orientation = simd_quatf(angle: ang, axis: SIMD3(0, 1, 0))
                }
            }
        }

        // MARK: - ★ 초기화: 모든 AR 마커 제거

        func clearAll() {
            guard let arView else { return }
            // 모든 앵커 제거
            for a in allAnchors { arView.scene.removeAnchor(a) }
            for (_, a) in pointAnchors { arView.scene.removeAnchor(a) }
            // 딕셔너리/배열 비우기
            allAnchors.removeAll()
            pointAnchors.removeAll()
            markerEntities.removeAll()
            numberEntities.removeAll()
            distEntities.removeAll()
            labelAnchors.removeAll()
            hasRendered = false
        }
    }
}
