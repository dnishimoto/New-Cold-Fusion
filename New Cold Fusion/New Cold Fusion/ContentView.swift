

import SwiftUI
import SceneKit

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var monitor = QRTLColdFusionMonitor()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                latticeSceneView
                    .frame(height: 220)

                summaryBar

                fusionThresholdBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Divider()

                List {
                    ForEach(PipelineSection.allCases) { section in
                        let sectionStages = monitor.stages(in: section)
                        if !sectionStages.isEmpty {
                            Section {
                                ForEach(sectionStages) { stage in
                                    StageRow(stage: stage)
                                }
                            } header: {
                                Text(section.rawValue)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("QRTL Cold Fusion Pipeline")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: Fusion threshold bar

    private var fusionThresholdBar: some View {
        let progress = monitor.fusionThresholdProgress
        let barColor: Color = progress > 0.85 ? .green : (progress > 0.4 ? .orange : .red)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Fusion Threshold").font(.caption.bold())
                Spacer()
                Text(String(format: "%.2f / 28.4 MeV  (%.0f%%)",
                            monitor.effectiveTransitionEnergyMeV, progress * 100.0))
                    .font(.caption.monospaced())
                    .foregroundColor(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(uiColor: .tertiarySystemFill))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * CGFloat(progress)))
                        .animation(.easeInOut(duration: 0.25), value: progress)
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: Scene

    private var latticeSceneView: some View {
        ZStack(alignment: .bottomTrailing) {
            PalladiumLatticeSceneView(
                deuteriumLoading: monitor.inputs.deuteriumToPalladiumRatio,
                resonanceStrength: monitor.stages.first(where: { $0.id == "lorentzianResponse" })?.value ?? 0
            )
            .background(Color.black)

            Text(String(format: "D/Pd %.0f%%", monitor.deuteriumLoadingPercent))
                .font(.caption.monospaced())
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .padding(8)
        }
    }

    // MARK: Summary

    private var summaryBar: some View {
        VStack(spacing: 6) {
            HStack {
                summaryTile(title: "Resonance", value: formattedFrequency(monitor.resonanceFrequencyHz))
                Divider().frame(height: 34)
                summaryTile(title: "Transition Rate", value: formattedRate())
                Divider().frame(height: 34)
                summaryTile(title: "Net Power",
                            value: String(format: "%.0f W", monitor.netUsablePowerWatts),
                            color: monitor.isNetPositive ? .green : .red)
            }

            if monitor.isRunning || monitor.elapsedSimulationTime > 0 {
                HStack {
                    Label(String(format: "%.1f s", monitor.elapsedSimulationTime), systemImage: "timer")
                    Spacer()
                    Label(String(format: "%.3e J released", monitor.cumulativeEnergyJoules), systemImage: "bolt.fill")
                    if monitor.isRunning {
                        Spacer()
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
            }

            Button(action: { monitor.toggleSimulation() }) {
                Label(monitor.isRunning ? "Stop Simulation" : "Start Simulation",
                      systemImage: monitor.isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(monitor.isRunning ? .red : .green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func summaryTile(title: String, value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.caption.monospaced().bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedFrequency(_ hz: Double) -> String {
        String(format: "%.3e Hz", hz)
    }

    private func formattedRate() -> String {
        let rate = monitor.stages.first(where: { $0.id == "nuclearTransitionRate" })?.value ?? 0
        return String(format: "%.2e /s", rate)
    }
}

// MARK: - Stage Row

private struct StageRow: View {
    let stage: PipelineStageResult

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(stage.name)
                .font(.subheadline.bold())
            Text(stage.formattedValue)
                .font(.callout.monospaced())
                .foregroundColor(.accentColor)
            Text(stage.summary)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SceneKit Palladium Lattice View

struct PalladiumLatticeSceneView: UIViewRepresentable {
    var deuteriumLoading: Double
    var resonanceStrength: Double

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = buildScene()
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let scene = scnView.scene else { return }
        updateDeuteriumOccupancy(in: scene)
        updateShellGlow(in: scene)
    }

    // MARK: Scene construction

    private func buildScene() -> SCNScene {
        let scene = SCNScene()

        let camera = SCNCamera()
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(6, 6, 10)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.25, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.color = UIColor.white
        key.position = SCNVector3(8, 8, 8)
        scene.rootNode.addChildNode(key)

        let latticeRoot = SCNNode()
        latticeRoot.name = "latticeRoot"
        scene.rootNode.addChildNode(latticeRoot)

        let gridSize = 5
        let spacing: Float = 1.4
        let offset = Float(gridSize - 1) * spacing / 2.0

        for x in 0..<gridSize {
            for y in 0..<gridSize {
                for z in 0..<gridSize {
                    let pdNode = paletteSphere(radius: 0.28, color: .systemGray)
                    pdNode.position = SCNVector3(
                        Float(x) * spacing - offset,
                        Float(y) * spacing - offset,
                        Float(z) * spacing - offset
                    )
                    pdNode.name = "pd_\(x)_\(y)_\(z)"
                    latticeRoot.addChildNode(pdNode)

                    let dNode = paletteSphere(radius: 0.12, color: .systemTeal)
                    dNode.position = SCNVector3(0.35, 0.35, 0.35)
                    dNode.name = "d"
                    dNode.opacity = 0.0
                    pdNode.addChildNode(dNode)
                }
            }
        }

        // Shell resonance halo shown at the lattice center
        let shellGeometry = SCNSphere(radius: 1.2)
        shellGeometry.firstMaterial?.diffuse.contents = UIColor.systemOrange.withAlphaComponent(0.0)
        shellGeometry.firstMaterial?.emission.contents = UIColor.systemOrange.withAlphaComponent(0.0)
        shellGeometry.firstMaterial?.lightingModel = .constant
        let shellNode = SCNNode(geometry: shellGeometry)
        shellNode.name = "shellHalo"
        latticeRoot.addChildNode(shellNode)

        return scene
    }

    private func paletteSphere(radius: CGFloat, color: UIColor) -> SCNNode {
        let geometry = SCNSphere(radius: radius)
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.specular.contents = UIColor.white
        return SCNNode(geometry: geometry)
    }

    // MARK: Updates driven by simulation state

    private func updateDeuteriumOccupancy(in scene: SCNScene) {
        guard let latticeRoot = scene.rootNode.childNode(withName: "latticeRoot", recursively: false) else { return }
        let occupancyProbability = max(0.0, min(1.0, deuteriumLoading))

        latticeRoot.enumerateChildNodes { node, _ in
            guard let dNode = node.childNode(withName: "d", recursively: false) else { return }
            // deterministic pseudo-random occupancy from node position, stable across redraws
            let seed = abs(node.position.x * 12.9898 + node.position.y * 78.233 + node.position.z * 37.719)
            let pseudoRandom = seed.truncatingRemainder(dividingBy: 1.0)
            dNode.opacity = pseudoRandom < Float(occupancyProbability) ? 0.9 : 0.0
        }
    }

    private func updateShellGlow(in scene: SCNScene) {
        guard let latticeRoot = scene.rootNode.childNode(withName: "latticeRoot", recursively: false),
              let shellNode = latticeRoot.childNode(withName: "shellHalo", recursively: false),
              let material = shellNode.geometry?.firstMaterial else { return }

        let intensity = max(0.0, min(1.0, resonanceStrength))
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        material.diffuse.contents = UIColor.systemOrange.withAlphaComponent(CGFloat(0.05 + 0.35 * intensity))
        material.emission.contents = UIColor.systemOrange.withAlphaComponent(CGFloat(0.05 + 0.55 * intensity))
        SCNTransaction.commit()
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
