

import Foundation
import Combine


final class QRTLColdFusionMonitor: ObservableObject {

    @Published var inputs: QRTLExperimentInputs

    @Published private(set) var stages: [PipelineStageResult] = []

    @Published private(set) var lastUpdated: Date = Date()

    // MARK: Live simulation run state

    @Published private(set) var isRunning: Bool = false

    @Published private(set) var elapsedSimulationTime: Double = 0

    @Published private(set) var cumulativeEnergyJoules: Double = 0

    private var cancellables = Set<AnyCancellable>()

    private var simulationTimerCancellable: AnyCancellable?

    private var baseAppliedFrequencyHz: Double = 0

    // MARK: Section lookup

    private var sectionMap: [String: PipelineSection] = [:]

    // MARK: Initialization

    init(inputs: QRTLExperimentInputs = QRTLExperimentInputs()) {

        self.inputs = inputs

        recompute()

        $inputs
            .debounce(
                for: .milliseconds(80),
                scheduler: RunLoop.main
            )
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &cancellables)
    }

    // MARK: Simulation

    func startSimulation() {

        guard !isRunning else {
            return
        }

        isRunning = true
        elapsedSimulationTime = 0
        cumulativeEnergyJoules = 0

        baseAppliedFrequencyHz = resonanceFrequencyHz

        simulationTimerCancellable =
            Timer.publish(
                every: inputs.simulationTickIntervalSeconds,
                on: .main,
                in: .common
            )
            .autoconnect()
            .sink { [weak self] _ in
                self?.advanceSimulation()
            }
    }

    func stopSimulation() {

        isRunning = false

        simulationTimerCancellable?.cancel()
        simulationTimerCancellable = nil
    }

    func toggleSimulation() {

        isRunning
            ? stopSimulation()
            : startSimulation()
    }

    private func advanceSimulation() {

        let tick =
            max(
                inputs.simulationTickIntervalSeconds,
                1e-9
            )

        elapsedSimulationTime += tick

        // Sweep the applied frequency around the calculated resonance.
        let sweepSpan =
            inputs.resonanceSweepSpanLinewidths
            * inputs.resonanceLinewidthHz

        let sweepPeriod =
            max(
                inputs.resonanceSweepPeriodSeconds,
                1e-9
            )

        let sweepPhase =
            elapsedSimulationTime
                .truncatingRemainder(
                    dividingBy: sweepPeriod
                )
            / sweepPeriod

        let sweepOffset =
            sweepSpan
            * sin(
                sweepPhase
                * 2.0
                * Double.pi
            )

        inputs.appliedFrequencyHz =
            max(
                0,
                baseAppliedFrequencyHz
                + sweepOffset
            )

        // Recompute immediately so integration uses
        // the current tick's calculated power.
        recompute()

        if let grossPower =
            stages.first(
                where: {
                    $0.id == "nuclearEnergyProduction"
                }
            )?.value {

            cumulativeEnergyJoules +=
                max(0, grossPower) * tick
        }
    }

    // MARK: Section access

    func stages(
        in section: PipelineSection
    ) -> [PipelineStageResult] {

        stages.filter {
            sectionMap[$0.id] == section
        }
    }



    func recompute() {

        var results: [PipelineStageResult] = []
        var map: [String: PipelineSection] = [:]

        func add(
            _ id: String,
            _ name: String,
            _ value: Double,
            _ unit: String,
            _ summary: String,
            _ section: PipelineSection
        ) {
            results.append(
                PipelineStageResult(
                    id: id,
                    name: name,
                    value: value,
                    unit: unit,
                    summary: summary
                )
            )
            map[id] = section
        }

        // ================================================================
        // Reference electrical operating point
        // ================================================================

        let plateAreaCm2 =
            inputs.plateWidthCm
            * inputs.plateHeightCm

        let referenceCurrentMa =
            inputs.currentDensityMaPerCm2
            * plateAreaCm2

        let referenceCurrentA =
            referenceCurrentMa / 1000.0

        let chargeFlowRatePerSecond =
            referenceCurrentA
            / PhysicalConstants.elementaryCharge

        add(
            "plateArea",
            "Reference Palladium Plate Area",
            plateAreaCm2,
            "cm²",
            "Palladium plate reference surface area.",
            .latticePressure
        )

        add(
            "referenceCurrent",
            "Reference Electrical Operating Current",
            referenceCurrentMa,
            "mA",
            "Reference current from the specified current-density condition.",
            .latticePressure
        )

        add(
            "chargeFlowRate",
            "Charge Flow Rate",
            chargeFlowRatePerSecond,
            "e⁻ equiv/s",
            "Elementary-charge equivalents passing through the system per second.",
            .latticePressure
        )

        // ================================================================
        // 1. Effective QRTL Pressure
        // ================================================================

        let fractionalLatticeChange =
            inputs.latticeExpansionAtFullLoading
            * inputs.deuteriumToPalladiumRatio

        let volumetricStrain =
            inputs.volumetricStrainMultiplier
            * fractionalLatticeChange

        let bulkModulusPa =
            inputs.effectiveBulkModulusGPa
            * 1e9

        let deuteriumPressureTerm =
            inputs.deuteriumPressureCoefficient
            * inputs.deuteriumToPalladiumRatio

        let effectivePressurePa =
            -bulkModulusPa
            * volumetricStrain
            + deuteriumPressureTerm

        let effectivePressureGPa =
            effectivePressurePa / 1e9

        add(
            "volumetricStrain",
            "Fractional Volumetric Lattice Strain",
            volumetricStrain,
            "N/A",
            "Loaded vs. unloaded lattice volume change using the configured lattice-expansion model.",
            .latticePressure
        )

        add(
            "effectivePressure",
            "Effective QRTL Pressure",
            effectivePressureGPa,
            "GPa",
            "Collective lattice pressure condition from strain plus deuterium occupancy.",
            .latticePressure
        )

        // ================================================================
        // 2. Local Lattice Continuity
        // ================================================================

        let latticeContinuity =
            max(
                0.0,
                1.0
                - inputs.latticeContinuitySensitivity
                * abs(
                    inputs.deuteriumToPalladiumRatio
                    - inputs.latticeContinuityReferenceLoading
                )
            )

        add(
            "latticeContinuity",
            "Local Lattice Continuity",
            latticeContinuity,
            "N/A",
            "Uniformity of QRTL activity distribution through the lattice.",
            .latticeDynamics
        )

        // ================================================================
        // 3. QRTL Lattice Action
        // ================================================================

        let latticeActionDensity =
            effectivePressureGPa
            * latticeContinuity
            * inputs.shellStiffness

        add(
            "latticeAction",
            "QRTL Lattice Action Density",
            latticeActionDensity,
            "model units",
            "Energetic rules governing the proposed QRTL lattice.",
            .latticeDynamics
        )

        // ================================================================
        // 4. Equations of Motion
        // ================================================================

        let motionDenominator =
            1.0 + inputs.nonlinearCoefficient

        // Do not assert here. A bad denominator is handled safely so that
        // recompute() does not intentionally trap the application.

        let motionAmplitude: Double

        if motionDenominator > 0.0 {
            motionAmplitude =
                latticeActionDensity
                / motionDenominator
        } else {
            motionAmplitude = 0.0

            print(
                "⚠️ QRTL ERROR: Invalid motion denominator = " +
                "\(motionDenominator). " +
                "Check nonlinearCoefficient."
            )
        }

        // Preserve the raw signed value for diagnosis.
        let rawMotionAmplitude =
            motionAmplitude

        if rawMotionAmplitude < 0.0 {
            print(
                "⚠️ QRTL WARNING: Negative motion amplitude detected.\n" +
                "   effectivePressureGPa = \(effectivePressureGPa)\n" +
                "   latticeContinuity = \(latticeContinuity)\n" +
                "   shellStiffness = \(inputs.shellStiffness)\n" +
                "   latticeActionDensity = \(latticeActionDensity)\n" +
                "   motionDenominator = \(motionDenominator)\n" +
                "   rawMotionAmplitude = \(rawMotionAmplitude)\n" +
                "   Safety clamp applied: 0.0"
            )
        }

        // Amplitude is treated as a non-negative magnitude downstream.
        let safeMotionAmplitude =
            max(
                0.0,
                rawMotionAmplitude
            )

        add(
            "equationsOfMotionRaw",
            "Raw QRTL Equations-of-Motion Amplitude",
            rawMotionAmplitude,
            "model units",
            rawMotionAmplitude < 0.0
                ? "WARNING: Upstream calculation produced a negative amplitude. Safety clamp applied to downstream calculations."
                : "Unclamped amplitude produced by the equations-of-motion calculation.",
            .latticeDynamics
        )

        add(
            "equationsOfMotion",
            "QRTL Equations-of-Motion Amplitude",
            safeMotionAmplitude,
            "model units",
            rawMotionAmplitude < 0.0
                ? "Safety-clamped amplitude. The raw negative value remains available diagnostically."
                : "Resulting non-negative oscillation amplitude of the proposed lattice configuration.",
            .latticeDynamics
        )

        // ================================================================
        // 5. Resonance Energy
        // ================================================================

        let latticeResonanceEnergy =
            0.5
            * inputs.shellStiffness
            * safeMotionAmplitude
            * safeMotionAmplitude

        add(
            "latticeResonanceEnergy",
            "Lattice Resonance Energy",
            latticeResonanceEnergy,
            "model units",
            "Energy associated with the examined resonating lattice configuration.",
            .latticeDynamics
        )

        // ================================================================
        // 6. Stability
        // ================================================================

        let stabilitySecondDerivative =
            inputs.shellStiffness
            + 3.0
            * inputs.nonlinearCoefficient
            * safeMotionAmplitude
            * safeMotionAmplitude

        let isStable =
            stabilitySecondDerivative > 0.0

        add(
            "stabilityCondition",
            "Stability Second Derivative",
            stabilitySecondDerivative,
            "N/A",
            isStable
                ? "Positive second derivative. Model status: stable."
                : "Non-positive second derivative. Model status: unstable.",
            .latticeDynamics
        )

        // ================================================================
        // 7. Energy Stability Score
        // ================================================================

        let energyStabilityScore =
            isStable
                ? stabilitySecondDerivative
                    / (
                        1.0
                        + latticeResonanceEnergy
                    )
                : 0.0

        add(
            "energyStabilityScore",
            "Energy-Stability Score",
            energyStabilityScore,
            "N/A",
            "Combined ranking of candidate configurations by energy and stability.",
            .latticeDynamics
        )

        // ================================================================
        // 8. QRTL Shell Hamiltonian
        // ================================================================

        func shellEnergy(_ x: Double) -> Double {
            0.5
            * inputs.shellStiffness
            * x
            * x
            + 0.25
            * inputs.nonlinearCoefficient
            * pow(x, 4)
        }

        let equilibriumCoordinate =
            sqrt(safeMotionAmplitude)

        let shellHamiltonianEnergy =
            shellEnergy(
                equilibriumCoordinate
            )

        add(
            "shellHamiltonian",
            "QRTL Shell Hamiltonian Energy",
            shellHamiltonianEnergy,
            "model units",
            "Total proposed energy structure of the QRTL shell at equilibrium.",
            .shellHamiltonian
        )

        // ================================================================
        // 9-11. Shell Eigenstates
        // ================================================================

        let groundCoordinate =
            equilibriumCoordinate

        let excitedCoordinate =
            equilibriumCoordinate
            * inputs.excitedStateCoordinateMultiplier

        let groundEnergy =
            shellEnergy(
                groundCoordinate
            )

        let excitedEnergy =
            shellEnergy(
                excitedCoordinate
            )

        add(
            "shellEigenstateGround",
            "Shell-Energy Eigenvalue (Ground)",
            groundEnergy,
            "model units",
            "Lowest allowed QRTL shell configuration energy.",
            .shellHamiltonian
        )

        add(
            "shellEigenstateExcited",
            "Shell-Energy Eigenvalue (Excited)",
            excitedEnergy,
            "model units",
            "Higher accessible QRTL shell configuration energy.",
            .shellHamiltonian
        )

        // ================================================================
        // 12-14. Shell Geometry
        // ================================================================

        let shellRadiusScale =
            max(
                1.0e-9,
                1.0
                + inputs.radialShellPressureCoefficientPerGPa
                * effectivePressureGPa
            )

        let radialShellBoundaryFm =
            inputs.radialShellRadiusFm
            * pow(
                2.0,
                1.0 / 3.0
            )
            * shellRadiusScale

        add(
            "radialShellBoundary",
            "Radial Shell Boundary",
            radialShellBoundaryFm,
            "fm",
            "Predicted spatial extent of the proposed QRTL shell.",
            .shellGeometry
        )

        let shellVolumeFm3 =
            (4.0 / 3.0)
            * Double.pi
            * pow(
                radialShellBoundaryFm,
                3
            )

        let shellEnergySeparationModel =
            max(
                0.0,
                excitedEnergy - groundEnergy
            )

        let shellEnergyDensity =
            shellEnergySeparationModel
            / max(
                shellVolumeFm3,
                1e-9
            )

        add(
            "shellEnergyDensity",
            "Shell-Energy Density",
            shellEnergyDensity,
            "model units/fm³",
            "Non-negative modeled shell transition energy divided by the enclosed shell volume.",
            .shellGeometry
        )

        // ================================================================
        // 15. Resonance-Mass Relation
        // ================================================================

        let shellEnergySeparationEv =
            shellEnergySeparationModel
            * max(
                0.0,
                inputs.shellEnergyToEVScale
            )

        let resonanceMassEquivalentKg =
            (
                shellEnergySeparationEv
                * PhysicalConstants.electronVoltInJoules
            )
            / pow(
                PhysicalConstants.speedOfLight,
                2
            )

        add(
            "resonanceMassRelation",
            "Resonance-Mass Equivalent",
            resonanceMassEquivalentKg,
            "kg",
            "Mass-energy equivalent of the calculated shell-energy separation.",
            .shellGeometry
        )

        // ================================================================
        // 16-20. Nuclear Binding / Stability
        // ================================================================

        let nuclearLatticeBindingMeV =
            inputs.nuclearBaselineBindingEnergyMeV
            + inputs.nuclearBindingPressureCoefficientMeVPerGPa
            * effectivePressureGPa
            * latticeContinuity

        add(
            "nuclearLatticeEnergy",
            "Nuclear Lattice (Binding) Energy",
            nuclearLatticeBindingMeV,
            "MeV",
            "Proposed QRTL-shell contribution to holding the modeled nuclear configuration together.",
            .nuclearBinding
        )

        let coulombRepulsionMeV =
            inputs.coulombRepulsionMeV

        add(
            "coulombRepulsion",
            "Coulomb Repulsion Estimate",
            coulombRepulsionMeV,
            "MeV",
            "Configured Coulomb-repulsion estimate for the modeled two-deuteron configuration.",
            .nuclearBinding
        )

        let stabilityMargin =
            nuclearLatticeBindingMeV
            - coulombRepulsionMeV

        let nuclearlyStable =
            stabilityMargin > 0.0

        add(
            "nuclearStabilityInequality",
            "Nuclear Stability Margin",
            stabilityMargin,
            "MeV",
            nuclearlyStable
                ? "Binding contribution exceeds the configured Coulomb estimate. Model status: stable."
                : "Binding contribution does not exceed the configured Coulomb estimate. Model status: unstable.",
            .nuclearBinding
        )

        let forbiddenPairPenalty =
            nuclearlyStable
                ? 0.0
                : inputs.forbiddenPairPenaltyMeV

        add(
            "forbiddenPairPenalty",
            "Forbidden-Pair Penalty",
            forbiddenPairPenalty,
            "MeV",
            "Configured penalty applied when the modeled nuclear configuration is unstable.",
            .nuclearBinding
        )

        let nuclearRadiusFm =
            inputs.nuclearRadiusCoefficientFm
            * pow(
                4.0,
                1.0 / 3.0
            )

        add(
            "nuclearRadiusRelation",
            "Nuclear Radius Relation",
            nuclearRadiusFm,
            "fm",
            "Modeled physical size of the resulting nuclear configuration.",
            .nuclearBinding
        )

        // ================================================================
        // 21. Energy / Momentum Conservation Residual
        // ================================================================

        let energyMomentumDifference =
            abs(
                shellHamiltonianEnergy
                - groundEnergy
            )

        let energyMomentumResidual =
            energyMomentumDifference < 1e-6
                ? 0.0
                : energyMomentumDifference

        add(
            "energyMomentumConservation",
            "Energy-Momentum Conservation Residual",
            energyMomentumResidual,
            "model units",
            "Bookkeeping residual between shell Hamiltonian and ground-state energy.",
            .nuclearBinding
        )

        // ================================================================
        // 22. Noether Phase Charge
        // ================================================================

        let safeResonanceCoherence =
            min(
                1.0,
                max(
                    0.0,
                    inputs.resonanceCoherence
                )
            )

        let safeResonanceFidelity =
            min(
                1.0,
                max(
                    0.0,
                    inputs.resonanceFidelity
                )
            )

        let noetherPhaseCharge =
            safeResonanceCoherence
            * inputs.couplingCoefficient

        add(
            "noetherCharge",
            "Noether Charge (Phase Symmetry)",
            noetherPhaseCharge,
            "model units",
            "Proposed phase-symmetry quantity constraining modeled transitions.",
            .nuclearBinding
        )

        // ================================================================
        // 23-26. Electromagnetic Coupling
        // ================================================================

        let emCoupling =
            inputs.couplingCoefficient
            * inputs.electromagneticFieldAmplitude
            * equilibriumCoordinate

        add(
            "electromagneticCoupling",
            "QRTL Electromagnetic Coupling",
            emCoupling,
            "model units",
            "Interaction strength between the applied field and calculated shell.",
            .electromagnetic
        )

        let shellMagneticMoment =
            0.5
            * emCoupling
            * equilibriumCoordinate

        add(
            "shellMagneticMoment",
            "Shell Magnetic Moment",
            shellMagneticMoment,
            "model units",
            "Modeled magnetic behavior associated with the QRTL configuration.",
            .electromagnetic
        )

        let magneticEnergyDensity =
            0.5
            * shellMagneticMoment
            * shellMagneticMoment

        add(
            "magneticEnergyDensity",
            "Magnetic Energy Density",
            magneticEnergyDensity,
            "model units",
            "Modeled magnetic-field energy density.",
            .electromagnetic
        )

        let poyntingFlux =
            emCoupling
            * inputs.electromagneticFieldAmplitude

        add(
            "poyntingFlux",
            "Poynting Energy Flux",
            poyntingFlux,
            "model units",
            "Modeled directional electromagnetic energy transport magnitude.",
            .electromagnetic
        )

        // ================================================================
        // 27-28. Shell Energy / Resonance
        // ================================================================

        let shellEnergySeparationJ =
            shellEnergySeparationEv
            * PhysicalConstants.electronVoltInJoules

        let resonanceFrequencyHz =
            shellEnergySeparationJ
            / PhysicalConstants.planckConstant

        add(
            "shellEnergySeparation",
            "Shell-Energy Separation",
            shellEnergySeparationEv,
            "eV (model)",
            "Energy difference between the modeled accessible shell states.",
            .resonance
        )

        add(
            "resonanceFrequency",
            "QRTL Resonance Frequency",
            resonanceFrequencyHz,
            "Hz",
            "Shell-energy separation divided by Planck's constant.",
            .resonance
        )

        // ================================================================
        // 29-31. Pressure / D-Pd / Temperature Shifts
        // ================================================================

        let pressureCouplingHzPerGPa =
            (
                inputs.pressureEnergyCouplingEvPerGPa
                * PhysicalConstants.electronVoltInJoules
            )
            / PhysicalConstants.planckConstant

        let pressureShiftHz =
            pressureCouplingHzPerGPa
            * effectivePressureGPa

        add(
            "pressureResonanceShift",
            "Pressure-Dependent Resonance Shift",
            pressureShiftHz,
            "Hz",
            "Predicted resonance shift from the configured pressure coupling.",
            .resonance
        )

        let dPdShiftHz =
            pressureShiftHz
            * inputs.deuteriumToPalladiumRatio

        add(
            "dPdResonanceShift",
            "D/Pd-Dependent Resonance Shift",
            dPdShiftHz,
            "Hz",
            "Resonance shift attributable to deuterium loading through the pressure channel.",
            .resonance
        )

        let temperatureShiftHz =
            pressureCouplingHzPerGPa
            * inputs.temperatureResonanceCoefficientPerKelvin
            * (
                inputs.temperatureKelvin
                - inputs.referenceTemperatureKelvin
            )

        add(
            "temperatureResonanceShift",
            "Temperature-Dependent Resonance Shift",
            temperatureShiftHz,
            "Hz",
            "Resonance shift attributable to temperature through the configured pressure channel.",
            .resonance
        )

        // ================================================================
        // 32. Lorentzian Response
        // ================================================================

        let detuning =
            inputs.resonanceDetuningMultiplier
            * (
                inputs.appliedFrequencyHz
                - resonanceFrequencyHz
            )
            / max(
                inputs.resonanceLinewidthHz,
                1.0
            )

        let lorentzianResponse =
            1.0
            / (
                1.0
                + detuning * detuning
            )

        add(
            "lorentzianResponse",
            "QRTL Lorentzian Response",
            lorentzianResponse,
            "(0-1)",
            "Modeled response strength of the applied frequency relative to resonance.",
            .resonance
        )

        // ================================================================
        // 33-34. Coherence / Fidelity
        // ================================================================

        add(
            "resonanceCoherence",
            "Resonance Coherence",
            safeResonanceCoherence,
            "(0-1)",
            "Consistency of the required phase relationship across the modeled system.",
            .resonance
        )

        add(
            "resonanceFidelity",
            "Resonance Fidelity",
            safeResonanceFidelity,
            "(0-1)",
            "How closely the modeled system approaches the ideal resonant condition.",
            .resonance
        )

        // ================================================================
        // 35. QRTL Shell Transition Fraction
        // ================================================================

        let safeMaxResonantTransitionFraction =
            min(
                1.0,
                max(
                    0.0,
                    inputs.maxResonantTransitionFraction
                )
            )

        let transitionFraction =
            min(
                1.0,
                max(
                    0.0,
                    safeMaxResonantTransitionFraction
                    * lorentzianResponse
                    * safeResonanceCoherence
                    * safeResonanceFidelity
                )
            )

        add(
            "transitionFraction",
            "QRTL Transition Fraction",
            transitionFraction * 100.0,
            "%",
            "Modeled share of the available excitation population undergoing successful QRTL transitions.",
            .nuclearTransition
        )

        // ================================================================
        // 36. QRTL Shell Transition Rate
        //
        // THIS IS NOW PART OF THE POWER PIPELINE.
        // ================================================================

        let qrtlTransitionRate =
            chargeFlowRatePerSecond
            * transitionFraction

        add(
            "qrtlTransitionRate",
            "QRTL (Shell) Transition Rate",
            qrtlTransitionRate,
            "transitions/s",
            "QRTL-derived transition rate generated from charge flow, resonance response, coherence, fidelity, and the configured transition fraction.",
            .nuclearTransition
        )

        // ================================================================
        // 37-38. Matrix Element / Enhancement
        // ================================================================

        let enhancementFunction =
            inputs.nuclearEnhancementBase
            * (
                1.0
                + emCoupling
                * lorentzianResponse
                * safeResonanceCoherence
            )

        add(
            "nuclearMatrixElement",
            "QRTL-Modified D-D Matrix Element (rel.)",
            enhancementFunction,
            "× ordinary",
            "Modeled modification of the ordinary D-D transition amplitude.",
            .nuclearTransition
        )

        let enhancementFactor =
            max(
                0.0,
                enhancementFunction
                * enhancementFunction
            )

        add(
            "nuclearEnhancementFactor",
            "QRTL Nuclear Enhancement Factor",
            enhancementFactor,
            "×",
            "Modeled ratio of QRTL-modified to ordinary D-D transition rate.",
            .nuclearTransition
        )

        // ================================================================
        // 39. Effective QRTL Transition Rate
        //
        // ENHANCEMENT NOW ACTUALLY MODIFIES THE RATE.
        // ================================================================

        let enhancedQRTLTransitionRate =
            qrtlTransitionRate
            * enhancementFactor

        add(
            "enhancedQRTLTransitionRate",
            "Enhanced QRTL Transition Rate",
            enhancedQRTLTransitionRate,
            "transitions/s",
            "QRTL shell transition rate after application of the modeled nuclear enhancement factor.",
            .nuclearTransition
        )

        // ================================================================
        // 40. Fusion Threshold Progress
        // ================================================================

        let fusionThresholdProgressFraction =
            max(
                0.0,
                min(
                    1.0,
                    lorentzianResponse
                    * safeResonanceCoherence
                    * safeResonanceFidelity
                )
            )

        let effectiveTransitionEnergyMeV =
            fusionThresholdProgressFraction
            * max(
                0.0,
                inputs.transitionEnergyMeV
            )

        add(
            "fusionThresholdProgress",
            "Fusion Threshold Progress",
            fusionThresholdProgressFraction * 100.0,
            "%",
            "Modeled progress toward the configured QRTL transition energy.",
            .nuclearTransition
        )

        add(
            "effectiveTransitionEnergy",
            "Effective Transition Energy",
            effectiveTransitionEnergyMeV,
            "MeV",
            "Currently realized modeled share of the configured transition energy.",
            .nuclearTransition
        )

        // ================================================================
        // 41. Nuclear Transition Energy
        // ================================================================

        let safeTransitionEnergyMeV =
            max(
                0.0,
                inputs.transitionEnergyMeV
            )

        add(
            "nuclearTransitionEnergyMeV",
            "QRTL Nuclear Transition Energy",
            safeTransitionEnergyMeV,
            "MeV",
            "Proposed QRTL model transition energy per successful transition.",
            .nuclearTransition
        )

        let transitionEnergyJoules =
            safeTransitionEnergyMeV
            * 1.0e6
            * PhysicalConstants.electronVoltInJoules

        add(
            "nuclearTransitionEnergyJ",
            "Nuclear Transition Energy",
            transitionEnergyJoules,
            "J",
            "Configured transition energy converted to joules.",
            .nuclearTransition
        )

        // ================================================================
        // 42-43. Recovery Dynamics
        // ================================================================

        let recoveryFactor =
            min(
                1.0,
                max(
                    0.0,
                    exp(
                        -max(
                            0.0,
                            inputs.meanLifetimeSeconds
                        )
                        * 1e9
                    )
                )
            )

        add(
            "recoveryDynamics",
            "State-C Recovery Factor",
            recoveryFactor,
            "(0-1)",
            "Modeled fraction of the population available for another transition after recovery.",
            .nuclearTransition
        )

        add(
            "meanLifetime",
            "Mean Lifetime",
            inputs.meanLifetimeSeconds,
            "s",
            "Configured time scale for the relevant modeled shell state.",
            .nuclearTransition
        )

        // ================================================================
        // 44. Nuclear Reaction Rate
        //
        // THIS NO LONGER BYPASSES QRTL.
        // ================================================================

        let nuclearTransitionRate =
            enhancedQRTLTransitionRate
            * recoveryFactor

        add(
            "nuclearTransitionRate",
            "Nuclear Transition Rate",
            nuclearTransitionRate,
            "transitions/s",
            "Reaction rate derived directly from the QRTL transition rate, QRTL enhancement factor, and recovery dynamics.",
            .nuclearTransition
        )

        // ================================================================
        // 45. Gross Power
        //
        // POWER NOW COMES FROM:
        //
        // QRTL transition rate
        // × enhancement
        // × recovery
        // × transition energy
        //
        // There is no independent 20.3 kW shortcut here.
        // ================================================================

        let grossPowerWatts =
            nuclearTransitionRate
            * transitionEnergyJoules

        add(
            "nuclearEnergyProduction",
            "Nuclear Energy Production (Gross)",
            grossPowerWatts,
            "W",
            "Modeled QRTL-derived reaction rate multiplied by the configured transition energy.",
            .powerOutput
        )

        // ================================================================
        // 46-48. Recycling / Output
        // ================================================================

        let recycledFraction =
            min(
                1.0,
                max(
                    0.0,
                    inputs.recycledEnergyFraction
                )
            )

        let outflowPowerWatts =
            grossPowerWatts
            * (
                1.0
                - recycledFraction
            )

        add(
            "resonantOutflowPower",
            "Resonant-Outflow Power",
            outflowPowerWatts,
            "W",
            "Modeled energy leaving the resonant system through the proposed output mechanism.",
            .powerOutput
        )

        let thermalOutputWatts =
            outflowPowerWatts

        add(
            "thermalOutput",
            "Predicted Thermal Output",
            thermalOutputWatts,
            "W",
            "Modeled heat output if the outflow is fully thermalized.",
            .powerOutput
        )

        let safeElectricalConversionEfficiency =
            min(
                1.0,
                max(
                    0.0,
                    inputs.electricalConversionEfficiency
                )
            )

        let electricalOutputWatts =
            thermalOutputWatts
            * safeElectricalConversionEfficiency

        add(
            "electricalOutput",
            "Predicted Electrical Output",
            electricalOutputWatts,
            "W",
            "Modeled portion of thermal output converted to electricity.",
            .powerOutput
        )

        // Net power remains signed intentionally.
        // A negative result means apparatus input exceeds modeled output.

        let apparatusInputPowerWatts =
            max(
                0.0,
                inputs.apparatusInputPowerWatts
            )

        let netUsablePowerWatts =
            electricalOutputWatts
            - apparatusInputPowerWatts

        add(
            "netUsablePower",
            "Net Usable Power",
            netUsablePowerWatts,
            "W",
            "Modeled electrical output minus configured apparatus input power.",
            .powerOutput
        )

        // ================================================================
        // Publish
        // ================================================================

        self.sectionMap = map
        self.stages = results
        self.lastUpdated = Date()
    }
  
}
