//
//  QRTLColdFusionModel.swift
//  QRTL Palladium-Deuterium Cold Fusion Pipeline
//
//  Inventor: David S. Nishimoto
//  Copyright: 2026
//
//  Implements the full QRTL palladium-deuterium experiment causal chain as a
//  staged simulation pipeline: lattice pressure -> shell Hamiltonian -> shell
//  eigenstates -> nuclear binding/stability -> electromagnetic coupling ->
//  resonance -> nuclear transition -> net usable power.
//
//  All physical claims here are speculative model quantities (QRTL), not
//  established nuclear physics. Values are toy/simplified formulas intended
//  to keep every named stage in the theory calculable and inspectable.
//

import Foundation
import Combine

// MARK: - Physical Constants

enum PhysicalConstants {
    static let planckConstant: Double = 6.62607015e-34          // J·s
    static let reducedPlanck: Double = 1.054571817e-34           // J·s
    static let elementaryCharge: Double = 1.602176634e-19        // C
    static let electronVoltInJoules: Double = 1.602176634e-19
    static let boltzmann: Double = 1.380649e-23                  // J/K
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

// MARK: - Input State

/// Everything the experimenter can control or measure directly.
struct QRTLExperimentInputs {
    // Palladium plate / electrochemical reference condition
    var plateWidthCm: Double = 8.0
    var plateHeightCm: Double = 8.0
    var currentDensityMaPerCm2: Double = 1.6

    // Lattice / loading condition
    var unloadedLatticeParameterAngstrom: Double = 3.89   // Pd fcc lattice parameter
    var deuteriumToPalladiumRatio: Double = 0.85          // D/Pd loading, 0...~0.95
    var temperatureKelvin: Double = 313.0                  // ~40 C electrolysis bath
    var effectiveBulkModulusGPa: Double = 180.0            // Pd effective bulk modulus
    var deuteriumPressureCoefficient: Double = 2.4e9       // Pa per unit loading

    // QRTL shell parameters
    var shellStiffness: Double = 1.0                       // effective QRTL stiffness (model units)
    var nonlinearCoefficient: Double = 0.35                // quartic QRTL coefficient
    var pressureEnergyCouplingEvPerGPa: Double = 3.1e-2     // eV per GPa of effective pressure

    // Electromagnetic drive
    var appliedFrequencyHz: Double = 6.86e18                // swept excitation frequency
    var resonanceLinewidthHz: Double = 4.0e16
    var electromagneticFieldAmplitude: Double = 1.0         // model units
    var couplingCoefficient: Double = 0.62                  // model units

    // Nuclear / transition model parameters (fixed by the QRTL model spec)
    var transitionEnergyMeV: Double = 28.4
    var maxResonantTransitionFraction: Double = 0.344
    var nuclearEnhancementBase: Double = 1.0

    // Coherence / recovery
    var resonanceCoherence: Double = 0.9
    var resonanceFidelity: Double = 0.85
    var meanLifetimeSeconds: Double = 1.2e-9
    var electricalConversionEfficiency: Double = 0.10
    var apparatusInputPowerWatts: Double = 850.0            // pumps, heaters, electronics
}

// MARK: - QRTL Cold Fusion Monitor

/// Master pipeline monitor for the QRTL palladium-deuterium cold fusion
/// experiment. Mirrors the MasterMonitor ObservableObject pattern used across
/// the QRTL simulator family: mutate `inputs`, call `recompute()` (or let the
/// Combine pipeline do it automatically), then read `stages` / `sections`.
final class QRTLColdFusionMonitor: ObservableObject {

    @Published var inputs: QRTLExperimentInputs
    @Published private(set) var stages: [PipelineStageResult] = []
    @Published private(set) var lastUpdated: Date = Date()

    // MARK: Live simulation run state

    /// True while the resonance sweep / time-integration loop is running.
    @Published private(set) var isRunning: Bool = false
    /// Elapsed simulated time since the current run started, in seconds.
    @Published private(set) var elapsedSimulationTime: Double = 0
    /// Running total of predicted energy production over the simulated run, in joules.
    @Published private(set) var cumulativeEnergyJoules: Double = 0

    private var cancellables = Set<AnyCancellable>()
    private var simulationTimerCancellable: AnyCancellable?
    private let simulationTickInterval: Double = 0.2 // seconds of wall-clock per tick
    private var baseAppliedFrequencyHz: Double = 0

    init(inputs: QRTLExperimentInputs = QRTLExperimentInputs()) {
        self.inputs = inputs
        recompute()
        $inputs
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
    }

    /// Starts the live simulation: performs the "resonance on-off-on" sweep
    /// described in the source document (excitation frequency swept toward,
    /// through, and away from the calculated QRTL resonance) while
    /// integrating predicted energy production over simulated time.
    func startSimulation() {
        guard !isRunning else { return }
        isRunning = true
        elapsedSimulationTime = 0
        cumulativeEnergyJoules = 0
        baseAppliedFrequencyHz = resonanceFrequencyHz

        simulationTimerCancellable = Timer.publish(every: simulationTickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.advanceSimulation() }
    }

    /// Stops the live simulation and leaves the last computed state in place.
    func stopSimulation() {
        isRunning = false
        simulationTimerCancellable?.cancel()
        simulationTimerCancellable = nil
    }

    func toggleSimulation() {
        isRunning ? stopSimulation() : startSimulation()
    }

    private func advanceSimulation() {
        elapsedSimulationTime += simulationTickInterval

        // Sweep the excitation frequency through +/- 3 linewidths around the
        // resonance the model calculated at run start, tracing out the
        // predicted Lorentzian resonance curve as time progresses.
        let sweepSpan = 3.0 * inputs.resonanceLinewidthHz
        let sweepPhase = (elapsedSimulationTime.truncatingRemainder(dividingBy: 20.0)) / 20.0 // 20s period
        let sweepOffset = sweepSpan * sin(sweepPhase * 2.0 * Double.pi)
        inputs.appliedFrequencyHz = max(0, baseAppliedFrequencyHz + sweepOffset)

        // recompute() is also triggered by the debounced $inputs publisher,
        // but call it directly here so energy integration uses this tick's
        // freshly computed gross power rather than a stale value.
        recompute()

        if let grossPower = stages.first(where: { $0.id == "nuclearEnergyProduction" })?.value {
            cumulativeEnergyJoules += max(0, grossPower) * simulationTickInterval
        }
    }

    func stages(in section: PipelineSection) -> [PipelineStageResult] {
        stages.filter { sectionMap[$0.id] == section }
    }

    // MARK: Section lookup (id -> section), populated during recompute()

    private var sectionMap: [String: PipelineSection] = [:]

    // MARK: - Recompute the entire causal chain

    func recompute() {
        var results: [PipelineStageResult] = []
        var map: [String: PipelineSection] = [:]

        func add(_ id: String, _ name: String, _ value: Double, _ unit: String,
                 _ summary: String, _ section: PipelineSection) {
            results.append(PipelineStageResult(id: id, name: name, value: value,
                                                unit: unit, summary: summary))
            map[id] = section
        }

        // ---- Reference electrical operating point ----------------------
        let plateAreaCm2 = inputs.plateWidthCm * inputs.plateHeightCm
        let referenceCurrentMa = inputs.currentDensityMaPerCm2 * plateAreaCm2
        let referenceCurrentA = referenceCurrentMa / 1000.0
        let chargeFlowRatePerSecond = referenceCurrentA / PhysicalConstants.elementaryCharge

        add("plateArea", "Reference Palladium Plate Area", plateAreaCm2, "cm²",
            "8cm × 8cm palladium plate reference surface area.", .latticePressure)
        add("referenceCurrent", "Reference Electrical Operating Current", referenceCurrentMa, "mA",
            "Reference current from the historical current-density condition.", .latticePressure)
        add("chargeFlowRate", "Charge Flow Rate", chargeFlowRatePerSecond, "e⁻ equiv/s",
            "Elementary-charge equivalents passing through the system per second.", .latticePressure)

        // ---- 1. Effective QRTL Pressure ---------------------------------
        // fractional lattice-parameter change grows with D/Pd loading (toy model: ~6.5% at full loading)
        let fractionalLatticeChange = 0.065 * inputs.deuteriumToPalladiumRatio
        let volumetricStrain = 3.0 * fractionalLatticeChange
        let bulkModulusPa = inputs.effectiveBulkModulusGPa * 1e9
        let deuteriumPressureTerm = inputs.deuteriumPressureCoefficient * inputs.deuteriumToPalladiumRatio
        let effectivePressurePa = -bulkModulusPa * volumetricStrain + deuteriumPressureTerm
        let effectivePressureGPa = effectivePressurePa / 1e9

        add("volumetricStrain", "Fractional Volumetric Lattice Strain", volumetricStrain, "",
            "Loaded vs. unloaded lattice volume change, ≈3× fractional lattice-parameter change.", .latticePressure)
        add("effectivePressure", "Effective QRTL Pressure", effectivePressureGPa, "GPa",
            "Collective lattice pressure condition from strain plus deuterium occupancy.", .latticePressure)

        // ---- 2. Local Lattice Continuity ---------------------------------
        // toy: how uniformly the QRTL quantity is distributed (1 = perfectly uniform)
        let latticeContinuity = max(0.0, 1.0 - 0.4 * abs(inputs.deuteriumToPalladiumRatio - 0.7))
        add("latticeContinuity", "Local Lattice Continuity", latticeContinuity, "",
            "Uniformity of QRTL activity distribution through the lattice (1 = fully balanced).", .latticeDynamics)

        // ---- 3. QRTL Lattice Action / 4. Equations of Motion -------------
        let latticeActionDensity = effectivePressureGPa * latticeContinuity * inputs.shellStiffness
        add("latticeAction", "QRTL Lattice Action Density", latticeActionDensity, "model units",
            "Energetic rules governing the QRTL lattice from pressure, continuity, and stiffness.", .latticeDynamics)

        let motionAmplitude = latticeActionDensity / (1.0 + inputs.nonlinearCoefficient)
        add("equationsOfMotion", "QRTL Equations-of-Motion Amplitude", motionAmplitude, "model units",
            "Resulting oscillation amplitude of the proposed lattice configuration.", .latticeDynamics)

        // ---- 5. Lattice Resonance Energy / 6. Stability / 7. Score -------
        let latticeResonanceEnergy = 0.5 * inputs.shellStiffness * motionAmplitude * motionAmplitude
        add("latticeResonanceEnergy", "Lattice Resonance Energy", latticeResonanceEnergy, "model units",
            "Energy associated with the examined resonating lattice configuration.", .latticeDynamics)

        let stabilitySecondDerivative = inputs.shellStiffness + 3.0 * inputs.nonlinearCoefficient * motionAmplitude * motionAmplitude
        let isStable = stabilitySecondDerivative > 0
        add("stabilityCondition", "Stability Second Derivative", stabilitySecondDerivative, isStable ? "(stable)" : "(unstable)",
            "Second derivative of shell energy; positive means the configuration is stable.", .latticeDynamics)

        let energyStabilityScore = isStable ? (stabilitySecondDerivative / (1.0 + latticeResonanceEnergy)) : 0.0
        add("energyStabilityScore", "Energy-Stability Score", energyStabilityScore, "",
            "Combined ranking of candidate configurations by energy and stability.", .latticeDynamics)

        // ---- 8. QRTL Shell Hamiltonian -----------------------------------
        // shell energy(x) = 1/2 k x^2 + 1/4 λ x^4, evaluated at equilibrium coordinate
        func shellEnergy(_ x: Double) -> Double {
            0.5 * inputs.shellStiffness * x * x + 0.25 * inputs.nonlinearCoefficient * pow(x, 4)
        }
        let equilibriumCoordinate = sqrt(max(0.0, motionAmplitude))
        let shellHamiltonianEnergy = shellEnergy(equilibriumCoordinate)
        add("shellHamiltonian", "QRTL Shell Hamiltonian Energy", shellHamiltonianEnergy, "model units",
            "Total proposed energy structure of the QRTL shell at its equilibrium coordinate.", .shellHamiltonian)

        // ---- 9. Resonance-Shell Wave Equation / 10-11 Eigenstates --------
        // toy two-level system: ground and first excited shell coordinate
        let groundCoordinate = equilibriumCoordinate
        let excitedCoordinate = equilibriumCoordinate * 1.62
        let groundEnergy = shellEnergy(groundCoordinate)
        let excitedEnergy = shellEnergy(excitedCoordinate)
        add("shellEigenstateGround", "Shell-Energy Eigenvalue (Ground)", groundEnergy, "model units",
            "Lowest allowed QRTL shell configuration energy.", .shellHamiltonian)
        add("shellEigenstateExcited", "Shell-Energy Eigenvalue (Excited)", excitedEnergy, "model units",
            "Higher accessible QRTL shell configuration energy.", .shellHamiltonian)

        // ---- 12-14. Spherical decomposition / radial boundary / density --
        let radialShellBoundaryFm = 1.2 * pow(2.0, 1.0/3.0) * (1.0 + 0.05 * effectivePressureGPa)
        add("radialShellBoundary", "Radial Shell Boundary", radialShellBoundaryFm, "fm",
            "Predicted spatial extent of the QRTL shell (deuteron-pair scale, pressure-adjusted).", .shellGeometry)

        let shellVolumeFm3 = (4.0/3.0) * Double.pi * pow(radialShellBoundaryFm, 3)
        let shellEnergyDensity = (excitedEnergy - groundEnergy) / max(shellVolumeFm3, 1e-9)
        add("shellEnergyDensity", "Shell-Energy Density", shellEnergyDensity, "model units/fm³",
            "Shell transition energy divided by the enclosed shell volume.", .shellGeometry)

        // ---- 15. Resonance-Mass Relation ---------------------------------
        let shellEnergySeparationEv = (excitedEnergy - groundEnergy) * 1.0 // model units treated as eV scale
        let resonanceMassEquivalentKg = (shellEnergySeparationEv * PhysicalConstants.electronVoltInJoules) / pow(299_792_458.0, 2)
        add("resonanceMassRelation", "Resonance-Mass Equivalent", resonanceMassEquivalentKg, "kg",
            "Mass-energy equivalence of the calculated shell-energy separation.", .shellGeometry)

        // ---- 16-20. Nuclear binding / Coulomb / stability / radius -------
        let nuclearLatticeBindingMeV = 25.0 + 6.0 * effectivePressureGPa / 10.0 * latticeContinuity
        add("nuclearLatticeEnergy", "Nuclear Lattice (Binding) Energy", nuclearLatticeBindingMeV, "MeV",
            "Proposed QRTL-shell contribution to holding the nuclear configuration together.", .nuclearBinding)

        let coulombRepulsionMeV = 0.72 // deuteron-deuteron Coulomb barrier order of magnitude
        add("coulombRepulsion", "Coulomb Repulsion Estimate", coulombRepulsionMeV, "MeV",
            "Electrical repulsion between the two deuteron nuclei that binding must overcome.", .nuclearBinding)

        let stabilityMargin = nuclearLatticeBindingMeV - coulombRepulsionMeV
        let nuclearlyStable = stabilityMargin > 0
        add("nuclearStabilityInequality", "Nuclear Stability Margin", stabilityMargin, nuclearlyStable ? "MeV (stable)" : "MeV (unstable)",
            "Binding contribution minus Coulomb repulsion; positive favors a bound configuration.", .nuclearBinding)

        let forbiddenPairPenalty = nuclearlyStable ? 0.0 : 12.0
        add("forbiddenPairPenalty", "Forbidden-Pair Penalty", forbiddenPairPenalty, "MeV",
            "Energy penalty suppressing energetically forbidden state combinations.", .nuclearBinding)

        let nuclearRadiusFm = 1.25 * pow(4.0, 1.0/3.0) // He-4 product radius, order of magnitude
        add("nuclearRadiusRelation", "Nuclear Radius Relation", nuclearRadiusFm, "fm",
            "Predicted physical size of the resulting nuclear configuration.", .nuclearBinding)

        // ---- 21-22. Conservation checks -----------------------------------
        let energyMomentumResidual = abs(shellHamiltonianEnergy - (groundEnergy)) < 1e-6 ? 0.0 : abs(shellHamiltonianEnergy - groundEnergy)
        add("energyMomentumConservation", "Energy-Momentum Conservation Residual", energyMomentumResidual, "model units",
            "Bookkeeping residual; should remain near zero across the chain.", .nuclearBinding)

        let noetherPhaseCharge = inputs.resonanceCoherence * inputs.couplingCoefficient
        add("noetherCharge", "Noether Charge (Phase Symmetry)", noetherPhaseCharge, "model units",
            "Conserved quantity from the QRTL phase symmetry constraining allowed transitions.", .nuclearBinding)

        // ---- 23-26. Electromagnetic coupling ------------------------------
        let emCoupling = inputs.couplingCoefficient * inputs.electromagneticFieldAmplitude * equilibriumCoordinate
        add("electromagneticCoupling", "QRTL Electromagnetic Coupling", emCoupling, "model units",
            "Interaction strength between the applied field and the calculated shell.", .electromagnetic)

        let shellMagneticMoment = 0.5 * emCoupling * equilibriumCoordinate
        add("shellMagneticMoment", "Shell Magnetic Moment", shellMagneticMoment, "model units",
            "Magnetic behavior associated with circulating QRTL current/angular motion.", .electromagnetic)

        let magneticEnergyDensity = 0.5 * shellMagneticMoment * shellMagneticMoment
        add("magneticEnergyDensity", "Magnetic Energy Density", magneticEnergyDensity, "model units",
            "Energy stored in the magnetic field associated with the QRTL configuration.", .electromagnetic)

        let poyntingFlux = emCoupling * inputs.electromagneticFieldAmplitude
        add("poyntingFlux", "Poynting Energy Flux", poyntingFlux, "model units",
            "Directional electromagnetic energy transport magnitude.", .electromagnetic)

        // ---- 27-28. Shell-energy separation / resonance frequency ---------
        let shellEnergySeparationJ = shellEnergySeparationEv * PhysicalConstants.electronVoltInJoules
        let resonanceFrequencyHz = shellEnergySeparationJ / PhysicalConstants.planckConstant
        add("shellEnergySeparation", "Shell-Energy Separation", shellEnergySeparationEv, "eV (model)",
            "Energy difference between the two relevant accessible shell states.", .resonance)
        add("resonanceFrequency", "QRTL Resonance Frequency", resonanceFrequencyHz, "Hz",
            "Shell-energy separation divided by Planck's constant.", .resonance)

        // ---- 29-31. Pressure / D-Pd / Temperature dependent shifts --------
        let pressureCouplingHzPerGPa = (inputs.pressureEnergyCouplingEvPerGPa * PhysicalConstants.electronVoltInJoules) / PhysicalConstants.planckConstant
        let pressureShiftHz = pressureCouplingHzPerGPa * effectivePressureGPa
        add("pressureResonanceShift", "Pressure-Dependent Resonance Shift", pressureShiftHz, "Hz",
            "Predicted resonance shift from the current effective QRTL pressure.", .resonance)

        let dPdShiftHz = pressureShiftHz * (inputs.deuteriumToPalladiumRatio)
        add("dPdResonanceShift", "D/Pd-Dependent Resonance Shift", dPdShiftHz, "Hz",
            "Resonance shift attributable to deuterium loading via the pressure channel.", .resonance)

        let temperatureShiftHz = pressureCouplingHzPerGPa * 0.002 * (inputs.temperatureKelvin - 293.0)
        add("temperatureResonanceShift", "Temperature-Dependent Resonance Shift", temperatureShiftHz, "Hz",
            "Resonance shift attributable to temperature via the pressure channel.", .resonance)

        // ---- 32. Lorentzian response at the applied frequency -------------
        let detuning = 2.0 * (inputs.appliedFrequencyHz - resonanceFrequencyHz) / max(inputs.resonanceLinewidthHz, 1.0)
        let lorentzianResponse = 1.0 / (1.0 + detuning * detuning)
        add("lorentzianResponse", "QRTL Lorentzian Response", lorentzianResponse, "(0-1)",
            "Predicted response strength of the applied frequency relative to resonance.", .resonance)

        // ---- 33-34. Coherence / Fidelity -----------------------------------
        add("resonanceCoherence", "Resonance Coherence", inputs.resonanceCoherence, "(0-1)",
            "Consistency of the required phase relationship across the system.", .resonance)
        add("resonanceFidelity", "Resonance Fidelity", inputs.resonanceFidelity, "(0-1)",
            "How closely the real system approaches the ideal resonant condition.", .resonance)

        // ---- 35. QRTL Transition Rate (shell-level) ------------------------
        let shellTransitionRate = lorentzianResponse * inputs.resonanceCoherence * inputs.resonanceFidelity * chargeFlowRatePerSecond
        add("qrtlTransitionRate", "QRTL (Shell) Transition Rate", shellTransitionRate, "transitions/s",
            "Frequency of shell-state transitions under the current drive condition.", .nuclearTransition)

        // ---- 36-37. Nuclear matrix element / enhancement factor -----------
        let enhancementFunction = inputs.nuclearEnhancementBase * (1.0 + emCoupling * lorentzianResponse * inputs.resonanceCoherence)
        add("nuclearMatrixElement", "QRTL-Modified D-D Matrix Element (rel.)", enhancementFunction, "× ordinary",
            "Ordinary D-D transition amplitude modified by the QRTL shell coupling.", .nuclearTransition)

        let enhancementFactor = enhancementFunction * enhancementFunction
        add("nuclearEnhancementFactor", "QRTL Nuclear Enhancement Factor", enhancementFactor, "×",
            "Ratio of QRTL-modified to ordinary deuterium-deuterium transition rate.", .nuclearTransition)

        // ---- 38. Transition fraction ----------------------------------------
        let transitionFraction = inputs.maxResonantTransitionFraction * lorentzianResponse * inputs.resonanceCoherence
        add("transitionFraction", "QRTL Transition Fraction", transitionFraction * 100.0, "%",
            "Share of the available excitation population undergoing successful transitions.", .nuclearTransition)

        // ---- 39. Nuclear transition energy (fixed model requirement) --------
        add("nuclearTransitionEnergyMeV", "QRTL Nuclear Transition Energy", inputs.transitionEnergyMeV, "MeV",
            "Model-required energy released per successful QRTL fusion transition.", .nuclearTransition)
        let transitionEnergyJoules = inputs.transitionEnergyMeV * 1.0e6 * PhysicalConstants.electronVoltInJoules
        add("nuclearTransitionEnergyJ", "Nuclear Transition Energy", transitionEnergyJoules, "J",
            "Transition energy converted to joules for the power calculation.", .nuclearTransition)

        // ---- 40-41. Recovery dynamics / mean lifetime ------------------------
        let recoveryFactor = exp(-inputs.meanLifetimeSeconds * 1e9) // toy decay factor
        add("recoveryDynamics", "State-C Recovery Factor", recoveryFactor, "(0-1)",
            "Fraction of the population ready for another transition after recovery.", .nuclearTransition)
        add("meanLifetime", "Mean Lifetime", inputs.meanLifetimeSeconds, "s",
            "Time scale over which the relevant shell state remains available.", .nuclearTransition)

        // ---- 42-43. Nuclear transition rate / gross energy production -------
        let nuclearTransitionRate = chargeFlowRatePerSecond * transitionFraction * recoveryFactor
        add("nuclearTransitionRate", "Nuclear Transition Rate", nuclearTransitionRate, "transitions/s",
            "Actual number of proposed nuclear transitions occurring per second.", .nuclearTransition)

        let grossPowerWatts = nuclearTransitionRate * transitionEnergyJoules
        add("nuclearEnergyProduction", "Nuclear Energy Production (Gross)", grossPowerWatts, "W",
            "Transition rate multiplied by energy released per transition.", .powerOutput)

        // ---- 44-46. Recycling balance / outflow / net usable power -----------
        let recycledFraction = 0.22
        let outflowPowerWatts = grossPowerWatts * (1.0 - recycledFraction)
        add("resonantOutflowPower", "Resonant-Outflow Power", outflowPowerWatts, "W",
            "Energy leaving the resonant system through the proposed output mechanism.", .powerOutput)

        let thermalOutputWatts = outflowPowerWatts
        add("thermalOutput", "Predicted Thermal Output", thermalOutputWatts, "W",
            "Calorimetrically measurable heat output if fully thermalized.", .powerOutput)

        let electricalOutputWatts = thermalOutputWatts * inputs.electricalConversionEfficiency
        add("electricalOutput", "Predicted Electrical Output", electricalOutputWatts, "W",
            "Portion of thermal output converted to usable electricity.", .powerOutput)

        let netUsablePowerWatts = electricalOutputWatts - inputs.apparatusInputPowerWatts
        add("netUsablePower", "Net Usable Power", netUsablePowerWatts, "W",
            "Electrical output minus apparatus input power and losses.", .powerOutput)

        self.sectionMap = map
        self.stages = results
        self.lastUpdated = Date()
    }

    // MARK: Convenience accessors used by the UI

    var netUsablePowerWatts: Double {
        stages.first(where: { $0.id == "netUsablePower" })?.value ?? 0
    }

    var resonanceFrequencyHz: Double {
        stages.first(where: { $0.id == "resonanceFrequency" })?.value ?? 0
    }

    var deuteriumLoadingPercent: Double {
        inputs.deuteriumToPalladiumRatio * 100.0
    }

    var isNetPositive: Bool { netUsablePowerWatts > 0 }
}
