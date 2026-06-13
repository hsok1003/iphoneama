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

    func updateUIView(_ uiView: ARView, context: Context) {}
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
        private var hasRendered = false

        init(manager: MeasurementManager) { self.manager = manager }

        // MARK: - 탭

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            guard manager.tapStep.rawValue <= 3 else { return }

            let loc = gesture.location(in: arView)
            let hits = arView.raycast(from: loc, allowing: .existingPlaneGeometry, alignment: .horizontal)
            let hit = hits.first ?? arView.raycast(from: loc, allowing: .estimatedPlane, alignment: .horizontal).first
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

            let dot = ModelEntity(
                mesh: MeshResource.generatePlane(width: 0.025, depth: 0.025, cornerRadius: 0.002),
                materials: [SimpleMaterial(color: .white, isMetallic: false)])
            dot.position.y = 0.003
            dot.orientation = simd_quatf(angle: .pi / 4, axis: SIMD3(0, 1, 0))
            a.addChild(dot)

            let pole = ModelEntity(
                mesh: MeshResource.generateBox(width: 0.003, height: 0.06, depth: 0.003),
                materials: [SimpleMaterial(color: .white.withAlphaComponent(0.8), isMetallic: false)])
            pole.position.y = 0.033
            a.addChild(pole)

            arView.scene.addAnchor(a)
            allAnchors.append(a)
        }

        // MARK: - ★ 눈금자 라인 (아이폰 측정앱 스타일)

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

            // 메인 라인
            addBox(at: mid, w: totalLen, h: 0.002, d: 0.004,
                   color: .white.withAlphaComponent(0.9), angle: angle)

            // 눈금 (10cm 간격)
            let perpAngle = angle + .pi / 2
            let numTicks = Int(totalLen / 0.10)
            for i in 0...numTicks {
                let t = Float(i) * 0.10
                if t > totalLen { break }
                let pos = s + dir * t
                let big = (i % 5 == 0)
                addBox(at: pos, w: big ? 0.025 : 0.012, h: 0.002, d: big ? 0.004 : 0.002,
                       color: .white.withAlphaComponent(0.7), angle: perpAngle)
            }

            // 양 끝 캡
            for ep in [s, e] {
                addBox(at: ep, w: 0.04, h: 0.002, d: 0.005,
                       color: .white, angle: perpAngle)
            }

            // 거리 라벨 (배경 + 텍스트)
            let labelA = AnchorEntity(world: mid + SIMD3(0, 0.002, 0))
            let bg = ModelEntity(
                mesh: MeshResource.generatePlane(width: 0.18, depth: 0.05, cornerRadius: 0.015),
                materials: [SimpleMaterial(color: UIColor.black.withAlphaComponent(0.75), isMetallic: false)])
            bg.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
            labelA.addChild(bg)

            let distText = dist >= 1.0
                ? String(format: "%.2fm", dist)
                : String(format: "%.0fcm", dist * 100)
            let txt = ModelEntity(
                mesh: MeshResource.generateText(
                    distText, extrusionDepth: 0.003,
                    font: .systemFont(ofSize: 0.035, weight: .bold),
                    containerFrame: .zero, alignment: .center,
                    lineBreakMode: .byWordWrapping),
                materials: [SimpleMaterial(color: .white, isMetallic: false)])
            txt.position = SIMD3(-0.04, 0.004, 0)
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

            // 바닥 경계선 (보라색)
            let purple = UIColor(red: 0.4, green: 0.3, blue: 1.0, alpha: 0.8)
            for i in 0..<4 {
                let s = SIMD3<Float>(corners[i].x, y + 0.005, corners[i].z)
                let e = SIMD3<Float>(corners[(i+1)%4].x, y + 0.005, corners[(i+1)%4].z)
                let d = simd_normalize(e - s)
                let len = simd_distance(s, e)
                addBox(at: (s + e) / 2, w: len, h: 0.003, d: 0.012,
                       color: purple, angle: atan2(d.x, d.z))
            }

            // 안쪽 포인트 영역 (녹색)
            let sp = manager.spacing
            let sw = min(sp, rect.width / 3)
            let sd = min(sp, rect.depth / 3)

            let ip = [
                rect.origin + rect.widthDir * sw + rect.depthDir * sd,
                rect.origin + rect.widthDir * (rect.width - sw) + rect.depthDir * sd,
                rect.origin + rect.widthDir * (rect.width - sw) + rect.depthDir * (rect.depth - sd),
                rect.origin + rect.widthDir * sw + rect.depthDir * (rect.depth - sd),
            ]
            for i in 0..<4 {
                let s = SIMD3<Float>(ip[i].x, y + 0.006, ip[i].z)
                let e = SIMD3<Float>(ip[(i+1)%4].x, y + 0.006, ip[(i+1)%4].z)
                let d = simd_normalize(e - s)
                let len = simd_distance(s, e)
                addBox(at: (s + e) / 2, w: len, h: 0.002, d: 0.006,
                       color: .systemGreen.withAlphaComponent(0.5), angle: atan2(d.x, d.z))
            }

            // ★ 간격 표시: 벽→포인트 거리 (가로/세로 각각)
            // 가로 간격 (좌벽 → 포인트2)
            let wSpacingStart = SIMD3<Float>(corners[0].x, y + 0.007, corners[0].z) + rect.depthDir * sd
            let wSpacingEnd = SIMD3<Float>(ip[0].x, y + 0.007, ip[0].z)
            drawSpacingLine(from: wSpacingStart, to: wSpacingEnd,
                            text: String(format: "가로 %.2fm", sw), color: .systemGreen)

            // 세로 간격 (상벽 → 포인트2)
            let dSpacingStart = SIMD3<Float>(corners[0].x, y + 0.007, corners[0].z) + rect.widthDir * sw
            let dSpacingEnd = SIMD3<Float>(ip[0].x, y + 0.007, ip[0].z)
            drawSpacingLine(from: dSpacingStart, to: dSpacingEnd,
                            text: String(format: "세로 %.2fm", sd), color: .systemGreen)

            // 면적 (중앙 = 3번 포인트)
            let center = manager.points[2].position  // id 3 = 중앙
            makeLabel(at: SIMD3(center.x, y + 0.025, center.z),
                      text: String(format: "%.1fm²", rect.area), size: 0.05, color: .white)

            // 대각선 표시 (1→5)
            let p1 = manager.points[0].position  // id 1 = 우상
            let p5 = manager.points[4].position  // id 5 = 좌하
            let diagDist = simd_distance(p1, p5)
            drawRuler(from: p1, to: p5, color: .systemPurple, label: String(format: "대각선 %.2fm", diagDist))

            // 포인트
            renderPoints()

            // 1→5, 2→4 대각선 점선 (중앙이 교차점에 있음을 표시)
            let p2 = manager.points[1].position  // id 2 = 좌상
            let p4 = manager.points[3].position  // id 4 = 우하
            drawDashedLine(from: p1, to: p5, color: .white.withAlphaComponent(0.3), y: y + 0.006)
            drawDashedLine(from: p2, to: p4, color: .white.withAlphaComponent(0.3), y: y + 0.006)
        }

        // MARK: - 간격 표시선 (벽→포인트)

        private func drawSpacingLine(from a: SIMD3<Float>, to b: SIMD3<Float>,
                                     text: String, color: UIColor) {
            guard let arView else { return }
            let dir = simd_normalize(b - a)
            let len = simd_distance(a, b)
            let mid = (a + b) / 2
            let angle = atan2(dir.x, dir.z)

            // 화살표 라인
            addBox(at: mid, w: len, h: 0.002, d: 0.004,
                   color: color, angle: angle)

            // 양 끝 캡
            let perpAngle = angle + .pi / 2
            for ep in [a, b] {
                addBox(at: ep, w: 0.02, h: 0.002, d: 0.003,
                       color: color, angle: perpAngle)
            }

            // 라벨
            makeLabel(at: mid + SIMD3(0, 0.025, 0), text: text, size: 0.025, color: color)
        }

        // MARK: - 점선

        private func drawDashedLine(from a: SIMD3<Float>, to b: SIMD3<Float>,
                                    color: UIColor, y: Float) {
            let s = SIMD3<Float>(a.x, y, a.z)
            let e = SIMD3<Float>(b.x, y, b.z)
            let len = simd_distance(s, e)
            let dir = simd_normalize(e - s)
            let angle = atan2(dir.x, dir.z)
            let segLen: Float = 0.04
            let gap: Float = 0.03
            var t: Float = 0
            while t < len {
                let segEnd = min(t + segLen, len)
                let mid = s + dir * ((t + segEnd) / 2)
                addBox(at: mid, w: segEnd - t, h: 0.002, d: 0.004,
                       color: color, angle: angle)
                t += segLen + gap
            }
        }

        // MARK: - 포인트

        private func renderPoints() {
            guard let arView else { return }
            for p in manager.points {
                let a = AnchorEntity(world: p.position)
                let isCenter = p.id == 3
                let base: UIColor = isCenter ? .systemRed : .systemOrange

                let outer = ModelEntity(
                    mesh: MeshResource.generatePlane(width: 0.16, depth: 0.16, cornerRadius: 0.08),
                    materials: [SimpleMaterial(color: base.withAlphaComponent(0.3), isMetallic: false)])
                outer.position.y = 0.003
                a.addChild(outer)

                let inner = ModelEntity(
                    mesh: MeshResource.generatePlane(width: 0.05, depth: 0.05, cornerRadius: 0.025),
                    materials: [SimpleMaterial(color: base, isMetallic: false)])
                inner.position.y = 0.004
                a.addChild(inner)
                markerEntities[p.id] = inner

                let num = ModelEntity(
                    mesh: MeshResource.generateText(
                        "\(p.id)", extrusionDepth: 0.006,
                        font: .systemFont(ofSize: 0.09, weight: .bold),
                        containerFrame: .zero, alignment: .center,
                        lineBreakMode: .byWordWrapping),
                    materials: [SimpleMaterial(color: base, isMetallic: false)])
                num.position = SIMD3(-0.025, 0.14, 0)
                a.addChild(num)
                numberEntities[p.id] = num

                let dist = ModelEntity(
                    mesh: MeshResource.generateText(
                        "--", extrusionDepth: 0.002,
                        font: .systemFont(ofSize: 0.03),
                        containerFrame: .zero, alignment: .center,
                        lineBreakMode: .byWordWrapping),
                    materials: [SimpleMaterial(color: .white, isMetallic: false)])
                dist.position = SIMD3(-0.015, 0.06, 0)
                a.addChild(dist)
                distEntities[p.id] = dist

                arView.scene.addAnchor(a)
                pointAnchors[p.id] = a
            }
        }

        // MARK: - 유틸

        private func addBox(at pos: SIMD3<Float>, w: Float, h: Float, d: Float,
                            color: UIColor, angle: Float) {
            guard let arView else { return }
            let a = AnchorEntity(world: pos)
            let e = ModelEntity(
                mesh: MeshResource.generateBox(width: w, height: h, depth: d),
                materials: [SimpleMaterial(color: color, isMetallic: false)])
            e.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
            a.addChild(e)
            arView.scene.addAnchor(a)
            allAnchors.append(a)
        }

        private func makeLabel(at pos: SIMD3<Float>, text: String,
                               size: CGFloat, color: UIColor) {
            guard let arView else { return }
            let a = AnchorEntity(world: pos)
            let e = ModelEntity(
                mesh: MeshResource.generateText(
                    text, extrusionDepth: 0.002,
                    font: .systemFont(ofSize: size, weight: .semibold),
                    containerFrame: .zero, alignment: .center,
                    lineBreakMode: .byWordWrapping),
                materials: [SimpleMaterial(color: color, isMetallic: false)])
            a.addChild(e)
            arView.scene.addAnchor(a)
            allAnchors.append(a)
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let t = frame.camera.transform
            let pos = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.manager.updateCameraPosition(pos)
                for p in self.manager.points {
                    guard let m = self.markerEntities[p.id], let n = self.numberEntities[p.id] else { continue }
                    let c: UIColor = p.isChecked ? .systemGreen
                        : p.distanceToUser <= self.manager.checkRadius * 2 ? .systemYellow
                        : p.id == 3 ? .systemRed : .systemOrange
                    m.model?.materials = [SimpleMaterial(color: c, isMetallic: false)]
                    n.model?.materials = [SimpleMaterial(color: c, isMetallic: false)]
                }
                for p in self.manager.points {
                    guard let d = self.distEntities[p.id] else { continue }
                    let txt = p.isChecked ? "✓" : String(format: "%.1fm", p.distanceToUser)
                    d.model?.mesh = MeshResource.generateText(
                        txt, extrusionDepth: 0.002,
                        font: .systemFont(ofSize: 0.03),
                        containerFrame: .zero, alignment: .center,
                        lineBreakMode: .byWordWrapping)
                    d.model?.materials = [SimpleMaterial(
                        color: p.isChecked ? .systemGreen : .white, isMetallic: false)]
                    if let a = self.pointAnchors[p.id] {
                        let dir = pos - a.position(relativeTo: nil)
                        let ang = atan2(dir.x, dir.z)
                        d.orientation = simd_quatf(angle: ang, axis: SIMD3(0, 1, 0))
                        self.numberEntities[p.id]?.orientation = simd_quatf(angle: ang, axis: SIMD3(0, 1, 0))
                    }
                }
            }
        }
    }
}
