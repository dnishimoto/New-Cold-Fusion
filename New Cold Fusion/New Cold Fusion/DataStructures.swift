
//

import Foundation



enum PhysicalConstants {

    static let planckConstant: Double = 6.62607015e-34       // J·s
    static let reducedPlanck: Double = 1.054571817e-34       // J·s
    static let elementaryCharge: Double = 1.602176634e-19   // C
    static let electronVoltInJoules: Double = 1.602176634e-19
    static let boltzmann: Double = 1.380649e-23              // J/K

    static let speedOfLight: Double = 299_792_458.0         // m/s
}

// MARK: - Stage Result

/// A single named stage in the QRTL causal chain, ready for display in the UI.
struct PipelineStageResult: Identifiable, Equatable {
    let id: String
    let name: String
    let value: Double
    let unit: String
    let summary: String
    var formattedValue: String {
        if abs(value) >= 1e5 || (abs(value) < 1e-3 && value != 0) {
            return String(format: "%.4e %@", value, unit)
        }
        return String(format: "%.6g %@", value, unit)
    }
}

/// Grouped stages so the UI can section the pipeline the way the theory does.
enum PipelineSection: String, CaseIterable, Identifiable {
    case latticePressure = "Lattice & Effective Pressure"
    case latticeDynamics = "Lattice Action & Dynamics"
    case shellHamiltonian = "Shell Hamiltonian & Eigenstates"
    case shellGeometry = "Shell Geometry & Energy Density"
    case nuclearBinding = "Nuclear Binding & Stability"
    case electromagnetic = "Electromagnetic Coupling"
    case resonance = "Resonance & Frequency"
    case nuclearTransition = "Nuclear Transition"
    case powerOutput = "Energy & Power Output"

    var id: String { rawValue }
}
