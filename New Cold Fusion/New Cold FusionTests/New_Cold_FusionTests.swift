

/*
# QRTL Cold Fusion — Unit Test Pipeline

The tests are organized in the same order as the model pipeline:

1. Initialization
2. Palladium material
3. Deuterium loading
4. Input energy
5. QRTL field
6. Resonance
7. Energy shell
8. Pd–D interaction
9. QRTL stabilization
10. Reaction calculation
11. Reaction energy
12. Energy losses
13. Net output
14. Gain/COP
15. Full pipeline
16. Zero-QRTL baseline
17. Zero-reaction baseline
18. Energy conservation
19. Parameter sensitivity
20. Deterministic regression

*/
//
//  New_Cold_FusionTests.swift
//  New Cold FusionTests
//
//  Unit tests for QRTLColdFusionMonitor
//

import Foundation
import XCTest
@testable import New_Cold_Fusion

final class New_Cold_FusionTests: XCTestCase {

    // MARK: - Helpers

    private func makeMonitor(
        configure: ((inout QRTLExperimentInputs) -> Void)? = nil
    ) -> QRTLColdFusionMonitor {

        var inputs = QRTLExperimentInputs()

        configure?(&inputs)

        return QRTLColdFusionMonitor(inputs: inputs)
    }

    private func value(
        _ id: String,
        in monitor: QRTLColdFusionMonitor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Double {

        guard let stage = monitor.stages.first(where: { $0.id == id }) else {
            XCTFail(
                "Stage '\(id)' was not found.",
                file: file,
                line: line
            )
            return .nan
        }

        return stage.value
    }

    private func assertClose(
        _ actual: Double,
        _ expected: Double,
        accuracy: Double = 1e-10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            actual,
            expected,
            accuracy: accuracy,
            file: file,
            line: line
        )
    }

    // MARK: - Physical Constants

    func testPhysicalConstants() {

        XCTAssertEqual(
            PhysicalConstants.planckConstant,
            6.62607015e-34,
            accuracy: 1e-45
        )

        XCTAssertEqual(
            PhysicalConstants.reducedPlanck,
            1.054571817e-34,
            accuracy: 1e-45
        )

        XCTAssertEqual(
            PhysicalConstants.elementaryCharge,
            1.602176634e-19,
            accuracy: 1e-30
        )

        XCTAssertEqual(
            PhysicalConstants.electronVoltInJoules,
            1.602176634e-19,
            accuracy: 1e-30
        )

        XCTAssertEqual(
            PhysicalConstants.boltzmann,
            1.380649e-23,
            accuracy: 1e-34
        )
    }

    // MARK: - PipelineStageResult

    func testPipelineStageResultEquality() {

        let a = PipelineStageResult(
            id: "test",
            name: "Test",
            value: 10.0,
            unit: "W",
            summary: "Test"
        )

        let b = PipelineStageResult(
            id: "test",
            name: "Test",
            value: 10.0,
            unit: "W",
            summary: "Test"
        )

        XCTAssertEqual(a, b)
    }

    func testPipelineStageResultFormattedValueLarge() {

        let stage = PipelineStageResult(
            id: "power",
            name: "Power",
            value: 100_000.0,
            unit: "W",
            summary: "Power"
        )

        XCTAssertEqual(
            stage.formattedValue,
            "1.0000e+05 W"
        )
    }

    func testPipelineStageResultFormattedValueNormal() {

        let stage = PipelineStageResult(
            id: "power",
            name: "Power",
            value: 12.3456,
            unit: "W",
            summary: "Power"
        )

        XCTAssertEqual(
            stage.formattedValue,
            "12.3456 W"
        )
    }

    func testPipelineStageResultFormattedValueSmall() {

        let stage = PipelineStageResult(
            id: "energy",
            name: "Energy",
            value: 0.0001,
            unit: "J",
            summary: "Energy"
        )

        XCTAssertEqual(
            stage.formattedValue,
            "1.0000e-04 J"
        )
    }

    // MARK: - Pipeline Sections

    func testPipelineSections() {

        XCTAssertEqual(
            PipelineSection.allCases.count,
            9
        )

        for section in PipelineSection.allCases {
            XCTAssertEqual(
                section.id,
                section.rawValue
            )
        }
    }

    // MARK: - Monitor Initialization

    func testMonitorInitializes() {

        let monitor = makeMonitor()

        XCTAssertFalse(
            monitor.isRunning
        )

        XCTAssertEqual(
            monitor.elapsedSimulationTime,
            0.0
        )

        XCTAssertEqual(
            monitor.cumulativeEnergyJoules,
            0.0
        )

        XCTAssertEqual(
            monitor.inputs.plateWidthCm,
            8.0
        )

        XCTAssertEqual(
            monitor.inputs.plateHeightCm,
            8.0
        )

        XCTAssertEqual(
            monitor.inputs.deuteriumToPalladiumRatio,
            0.85
        )
    }

    func testDefaultPipelineHas52Stages() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            monitor.stages.count,
            52
        )
    }

    func testStageIDsAreUnique() {

        let monitor = makeMonitor()

        let ids = monitor.stages.map(\.id)
        let uniqueIDs = Set(ids)

        XCTAssertEqual(
            ids.count,
            uniqueIDs.count
        )
    }

    func testAllStagesHaveNamesUnitsAndSummaries() {
        let monitor = makeMonitor()

        monitor.recompute()

        XCTAssertFalse(
            monitor.stages.isEmpty,
            "recompute() should populate monitor.stages"
        )

        for stage in monitor.stages {
            XCTAssertFalse(
                stage.id.isEmpty,
                "Stage ID is empty"
            )

            XCTAssertFalse(
                stage.name.isEmpty,
                "Stage name is empty for \(stage.id)"
            )

            XCTAssertFalse(
                stage.unit.isEmpty,
                "Stage unit is empty for \(stage.id)"
            )

            XCTAssertFalse(
                stage.summary.isEmpty,
                "Stage summary is empty for \(stage.id)"
            )
        }
    }

    // MARK: - Reference Electrical Operating Point

    func testPlateArea() {

        let monitor = makeMonitor()

        let expected = 8.0 * 8.0

        assertClose(
            value("plateArea", in: monitor),
            expected
        )
    }

    func testReferenceCurrent() {

        let monitor = makeMonitor()

        let expected =
            1.6 * 64.0

        assertClose(
            value("referenceCurrent", in: monitor),
            expected
        )

        XCTAssertEqual(
            value("referenceCurrent", in: monitor),
            102.4,
            accuracy: 1e-10
        )
    }

    func testChargeFlowRate() {

        let monitor = makeMonitor()

        let currentA =
            102.4 / 1000.0

        let expected =
            currentA / PhysicalConstants.elementaryCharge

        assertClose(
            value("chargeFlowRate", in: monitor),
            expected,
            accuracy: 1e4
        )
    }

    // MARK: - Lattice Pressure

    func testVolumetricStrain() {

        let monitor = makeMonitor()

        let fractionalChange =
            0.065 * 0.85

        let expected =
            3.0 * fractionalChange

        assertClose(
            value("volumetricStrain", in: monitor),
            expected
        )
    }

    func testEffectivePressure() {

        let monitor = makeMonitor()

        let fractionalChange =
            0.065 * 0.85

        let volumetricStrain =
            3.0 * fractionalChange

        let bulkModulusPa =
            180.0e9

        let deuteriumPressureTerm =
            2.4e9 * 0.85

        let expected =
            (
                -bulkModulusPa * volumetricStrain
                + deuteriumPressureTerm
            ) / 1.0e9

        assertClose(
            value("effectivePressure", in: monitor),
            expected
        )

        XCTAssertEqual(
            expected,
            -27.795,
            accuracy: 1e-10
        )
    }

    func testLatticeContinuity() {

        let monitor = makeMonitor()

        let expected =
            1.0 - 0.4 * abs(0.85 - 0.7)

        assertClose(
            value("latticeContinuity", in: monitor),
            expected
        )

        XCTAssertEqual(
            expected,
            0.94,
            accuracy: 1e-12
        )
    }

    // MARK: - Lattice Dynamics

    func testLatticeAction() {

        let monitor = makeMonitor()

        let pressure = -27.795
        let continuity = 0.94
        let stiffness = 1.0

        let expected =
            pressure
            * continuity
            * stiffness

        assertClose(
            value("latticeAction", in: monitor),
            expected
        )
    }

    func testEquationsOfMotion() {

        let monitor = makeMonitor()

        let action =
            -27.795 * 0.94

        let expected =
            action / 1.35

        assertClose(
            value("equationsOfMotion", in: monitor),
            expected
        )
    }

    func testLatticeResonanceEnergy() {

        let monitor = makeMonitor()

        let motion =
            (-27.795 * 0.94) / 1.35

        let expected =
            0.5 * motion * motion

        assertClose(
            value("latticeResonanceEnergy", in: monitor),
            expected
        )
    }

    func testStabilityCondition() {

        let monitor = makeMonitor()

        let motion =
            (-27.795 * 0.94) / 1.35

        let expected =
            1.0
            + 3.0 * 0.35 * motion * motion

        assertClose(
            value("stabilityCondition", in: monitor),
            expected
        )

        XCTAssertGreaterThan(
            expected,
            0
        )
    }

    func testEnergyStabilityScore() {

        let monitor = makeMonitor()

        let stability =
            value("stabilityCondition", in: monitor)

        let energy =
            value("latticeResonanceEnergy", in: monitor)

        let expected =
            stability / (1.0 + energy)

        assertClose(
            value("energyStabilityScore", in: monitor),
            expected
        )
    }

    // MARK: - Shell Hamiltonian

    func testDefaultNegativeMotionClampsShellCoordinate() {

        let monitor = makeMonitor()

        XCTAssertLessThan(
            value("equationsOfMotion", in: monitor),
            0
        )

        XCTAssertEqual(
            value("shellHamiltonian", in: monitor),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            value("shellEigenstateGround", in: monitor),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            value("shellEigenstateExcited", in: monitor),
            0.0,
            accuracy: 1e-12
        )
    }

    func testPositiveMotionActivatesShell() {

        let monitor = makeMonitor { inputs in
            inputs.effectiveBulkModulusGPa = 10.0
        }

        XCTAssertGreaterThan(
            value("equationsOfMotion", in: monitor),
            0
        )

        XCTAssertGreaterThan(
            value("shellHamiltonian", in: monitor),
            0
        )

        XCTAssertGreaterThan(
            value("shellEigenstateExcited", in: monitor),
            value("shellEigenstateGround", in: monitor)
        )
    }

    func testShellHamiltonianFormula() {

        let monitor = makeMonitor { inputs in
            inputs.effectiveBulkModulusGPa = 10.0
        }

        let motion =
            value("equationsOfMotion", in: monitor)

        let coordinate =
            sqrt(max(0.0, motion))

        let expected =
            0.5 * coordinate * coordinate
            + 0.25 * 0.35 * pow(coordinate, 4)

        assertClose(
            value("shellHamiltonian", in: monitor),
            expected
        )
    }

    func testGroundEigenstateEqualsShellHamiltonian() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        assertClose(
            value("shellEigenstateGround", in: monitor),
            value("shellHamiltonian", in: monitor)
        )
    }

    func testExcitedEigenstateIsHigherThanGroundState() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        XCTAssertGreaterThan(
            value("shellEigenstateExcited", in: monitor),
            value("shellEigenstateGround", in: monitor)
        )
    }

    // MARK: - Shell Geometry

    func testRadialShellBoundary() {

        let monitor = makeMonitor()

        let pressure =
            value("effectivePressure", in: monitor)

        let expected =
            1.2
            * pow(2.0, 1.0 / 3.0)
            * (1.0 + 0.05 * pressure)

        assertClose(
            value("radialShellBoundary", in: monitor),
            expected
        )
    }

    func testShellEnergyDensity() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let radius =
            value("radialShellBoundary", in: monitor)

        let volume =
            (4.0 / 3.0)
            * Double.pi
            * pow(radius, 3)

        let ground =
            value("shellEigenstateGround", in: monitor)

        let excited =
            value("shellEigenstateExcited", in: monitor)

        let expected =
            (excited - ground)
            / max(volume, 1e-9)

        assertClose(
            value("shellEnergyDensity", in: monitor),
            expected
        )
    }

    func testResonanceMassRelation() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let separation =
            value("shellEnergySeparation", in: monitor)

        let expected =
            separation
            * PhysicalConstants.electronVoltInJoules
            / pow(299_792_458.0, 2)

        assertClose(
            value("resonanceMassRelation", in: monitor),
            expected,
            accuracy: 1e-30
        )
    }

    // MARK: - Nuclear Binding

    func testNuclearLatticeEnergy() {

        let monitor = makeMonitor()

        let pressure =
            value("effectivePressure", in: monitor)

        let continuity =
            value("latticeContinuity", in: monitor)

        let expected =
            25.0
            + 6.0
            * pressure
            / 10.0
            * continuity

        assertClose(
            value("nuclearLatticeEnergy", in: monitor),
            expected
        )
    }

    func testCoulombRepulsion() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            value("coulombRepulsion", in: monitor),
            0.72,
            accuracy: 1e-12
        )
    }

    func testNuclearStabilityMargin() {

        let monitor = makeMonitor()

        let binding =
            value("nuclearLatticeEnergy", in: monitor)

        let coulomb =
            value("coulombRepulsion", in: monitor)

        XCTAssertGreaterThan(
            binding - coulomb,
            0
        )

        XCTAssertEqual(
            value("forbiddenPairPenalty", in: monitor),
            0.0,
            accuracy: 1e-12
        )
    }

    func testNuclearRadiusRelation() {

        let monitor = makeMonitor()

        let expected =
            1.25 * pow(4.0, 1.0 / 3.0)

        assertClose(
            value("nuclearRadiusRelation", in: monitor),
            expected
        )
    }

    // MARK: - Conservation

    func testEnergyMomentumConservation() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            value(
                "energyMomentumConservation",
                in: monitor
            ),
            0.0,
            accuracy: 1e-12
        )
    }

    func testNoetherCharge() {

        let monitor = makeMonitor()

        let expected =
            0.9 * 0.62

        assertClose(
            value("noetherCharge", in: monitor),
            expected
        )
    }

    // MARK: - Electromagnetic Coupling

    func testElectromagneticCoupling() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let motion =
            value("equationsOfMotion", in: monitor)

        let coordinate =
            sqrt(max(0.0, motion))

        let expected =
            0.62
            * 1.0
            * coordinate

        assertClose(
            value("electromagneticCoupling", in: monitor),
            expected
        )
    }

    func testZeroCouplingRemovesEMCoupling() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
            $0.couplingCoefficient = 0.0
        }

        XCTAssertEqual(
            value("electromagneticCoupling", in: monitor),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            value("shellMagneticMoment", in: monitor),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            value("poyntingFlux", in: monitor),
            0.0,
            accuracy: 1e-12
        )
    }

    func testZeroFieldRemovesEMCoupling() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
            $0.electromagneticFieldAmplitude = 0.0
        }

        XCTAssertEqual(
            value("electromagneticCoupling", in: monitor),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            value("poyntingFlux", in: monitor),
            0.0,
            accuracy: 1e-12
        )
    }

    func testMagneticMomentRelationship() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let coupling =
            value("electromagneticCoupling", in: monitor)

        let motion =
            value("equationsOfMotion", in: monitor)

        let coordinate =
            sqrt(max(0.0, motion))

        let expected =
            0.5 * coupling * coordinate

        assertClose(
            value("shellMagneticMoment", in: monitor),
            expected
        )
    }

    func testMagneticEnergyDensity() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let moment =
            value("shellMagneticMoment", in: monitor)

        let expected =
            0.5 * moment * moment

        assertClose(
            value("magneticEnergyDensity", in: monitor),
            expected
        )
    }

    func testPoyntingFlux() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let coupling =
            value("electromagneticCoupling", in: monitor)

        let expected =
            coupling
            * monitor.inputs.electromagneticFieldAmplitude

        assertClose(
            value("poyntingFlux", in: monitor),
            expected
        )
    }

    // MARK: - Resonance

    func testShellEnergySeparation() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let ground =
            value("shellEigenstateGround", in: monitor)

        let excited =
            value("shellEigenstateExcited", in: monitor)

        let expected =
            excited - ground

        assertClose(
            value("shellEnergySeparation", in: monitor),
            expected
        )
    }

    func testResonanceFrequencyUsesPlanckRelation() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let separationEv =
            value("shellEnergySeparation", in: monitor)

        let energyJ =
            separationEv
            * PhysicalConstants.electronVoltInJoules

        let expected =
            energyJ
            / PhysicalConstants.planckConstant

        assertClose(
            value("resonanceFrequency", in: monitor),
            expected,
            accuracy: 1e-6
        )
    }

    func testPressureResonanceShift() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let pressure =
            value("effectivePressure", in: monitor)

        let pressureCoupling =
            (
                monitor.inputs.pressureEnergyCouplingEvPerGPa
                * PhysicalConstants.electronVoltInJoules
            )
            / PhysicalConstants.planckConstant

        let expected =
            pressureCoupling
            * pressure

        assertClose(
            value("pressureResonanceShift", in: monitor),
            expected,
            accuracy: 1e-6
        )
    }

    func testDeuteriumPressureResonanceShift() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let pressureShift =
            value(
                "pressureResonanceShift",
                in: monitor
            )

        let expected =
            pressureShift
            * monitor.inputs.deuteriumToPalladiumRatio

        assertClose(
            value("dPdResonanceShift", in: monitor),
            expected,
            accuracy: 1e-6
        )
    }

    func testTemperatureResonanceShift() {

        let monitor = makeMonitor()

        let pressureCoupling =
            (
                monitor.inputs.pressureEnergyCouplingEvPerGPa
                * PhysicalConstants.electronVoltInJoules
            )
            / PhysicalConstants.planckConstant

        let expected =
            pressureCoupling
            * 0.002
            * (monitor.inputs.temperatureKelvin - 293.0)

        assertClose(
            value("temperatureResonanceShift", in: monitor),
            expected,
            accuracy: 1e-6
        )
    }

    func testLorentzianResponseIsBounded() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let response =
            value("lorentzianResponse", in: monitor)

        XCTAssertGreaterThanOrEqual(
            response,
            0.0
        )

        XCTAssertLessThanOrEqual(
            response,
            1.0
        )
    }

    func testExactResonanceProducesUnitLorentzianResponse() {

        var inputs = QRTLExperimentInputs()

        inputs.effectiveBulkModulusGPa = 10.0

        var monitor =
            QRTLColdFusionMonitor(
                inputs: inputs
            )

        let resonance =
            monitor.resonanceFrequencyHz

        monitor.inputs.appliedFrequencyHz =
            resonance

        monitor.recompute()

        XCTAssertEqual(
            monitor.resonanceFrequencyHz,
            resonance,
            accuracy: 1e-6
        )

        XCTAssertEqual(
            value(
                "lorentzianResponse",
                in: monitor
            ),
            1.0,
            accuracy: 1e-12
        )
    }
/*
 When deuterium enters the palladium, it changes the palladium lattice, and in the model this change produces pressure and strain that determine the energy state of the proposed QRTL energy shell. The energy shell is modeled as having different possible energy levels, and the difference between those levels determines a characteristic frequency called the resonance frequency, which can be thought of as the shell’s preferred frequency. When an electromagnetic field is applied, its frequency can be compared with the shell’s resonance frequency: if the applied frequency is far from resonance, the model predicts weaker coupling; as the applied frequency approaches resonance, the model predicts stronger coupling; and when the applied frequency matches the resonance frequency, the model predicts the strongest coupling. In simple terms, the shell has a preferred frequency, the electromagnetic field provides a frequency, and the closer those frequencies are, the stronger the modeled interaction. Most importantly, the resonance frequency does not create energy; rather, it identifies where externally applied electromagnetic energy can couple most strongly to the proposed energy shell, producing the modeled shell excitation.
 */
    func testLorentzianResponseSymmetry() {

    let monitor = makeMonitor {
        $0.effectiveBulkModulusGPa = 10.0
    }

    let resonance = monitor.resonanceFrequencyHz

    // The configured linewidth (4e16 Hz) is much larger than
    // the calculated resonance (~6.11e13 Hz), so it cannot be
    // used as a positive-frequency symmetric offset.
    //
    // Use a 10% frequency offset instead.
    let delta = resonance * 0.10

    let upperFrequency = resonance + delta
    let lowerFrequency = resonance - delta

    XCTAssertGreaterThan(
        lowerFrequency,
        0.0,
        "Lower frequency must remain positive."
    )

    // Test above resonance.
    monitor.inputs.appliedFrequencyHz = upperFrequency
    monitor.recompute()

    let upper = value(
        "lorentzianResponse",
        in: monitor
    )

    // Test below resonance.
    monitor.inputs.appliedFrequencyHz = lowerFrequency
    monitor.recompute()

    let lower = value(
        "lorentzianResponse",
        in: monitor
    )

    // The Lorentzian response should be symmetric
    // for equal frequency offsets around resonance.
    XCTAssertEqual(
        upper,
        lower,
        accuracy: 1e-12
    )

    }

    // MARK: - Nuclear Transition

    func testZeroCoherenceStopsTransitionRate() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
            $0.resonanceCoherence = 0.0
        }

        XCTAssertEqual(
            value("qrtlTransitionRate", in: monitor),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            value("transitionFraction", in: monitor),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            value("nuclearTransitionRate", in: monitor),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            value("nuclearEnergyProduction", in: monitor),
            0.0,
            accuracy: 1e-12
        )
    }

    func testQRTLTransitionRateRelationship() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let lorentzian =
            value(
                "lorentzianResponse",
                in: monitor
            )

        let expected =
            lorentzian
            * monitor.inputs.resonanceCoherence
            * monitor.inputs.resonanceFidelity
            * value("chargeFlowRate", in: monitor)

        assertClose(
            value("qrtlTransitionRate", in: monitor),
            expected,
            accuracy: 1e5
        )
    }

    func testNuclearMatrixElement() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let coupling =
            value(
                "electromagneticCoupling",
                in: monitor
            )

        let lorentzian =
            value(
                "lorentzianResponse",
                in: monitor
            )

        let expected =
            monitor.inputs.nuclearEnhancementBase
            * (
                1.0
                + coupling
                * lorentzian
                * monitor.inputs.resonanceCoherence
            )

        assertClose(
            value("nuclearMatrixElement", in: monitor),
            expected
        )
    }

    func testNuclearEnhancementFactorIsMatrixElementSquared() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let matrixElement =
            value(
                "nuclearMatrixElement",
                in: monitor
            )

        let expected =
            matrixElement * matrixElement

        assertClose(
            value("nuclearEnhancementFactor", in: monitor),
            expected
        )
    }

    func testTransitionFraction() {

        let monitor = makeMonitor {
            $0.effectiveBulkModulusGPa = 10.0
        }

        let response =
            value(
                "lorentzianResponse",
                in: monitor
            )

        let expected =
            monitor.inputs.maxResonantTransitionFraction
            * response
            * monitor.inputs.resonanceCoherence
            * 100.0

        assertClose(
            value("transitionFraction", in: monitor),
            expected
        )
    }

    func testFusionThresholdProgressIsBounded() {

        let monitor = makeMonitor()

        let progress =
            monitor.fusionThresholdProgress

        XCTAssertGreaterThanOrEqual(
            progress,
            0.0
        )

        XCTAssertLessThanOrEqual(
            progress,
            1.0
        )
    }

    func testEffectiveTransitionEnergy() {

        let monitor = makeMonitor()

        let progress =
            monitor.fusionThresholdProgress

        let expected =
            progress
            * monitor.inputs.transitionEnergyMeV

        assertClose(
            monitor.effectiveTransitionEnergyMeV,
            expected
        )
    }

    func testNuclearTransitionEnergyMeV() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            value(
                "nuclearTransitionEnergyMeV",
                in: monitor
            ),
            monitor.inputs.transitionEnergyMeV,
            accuracy: 1e-12
        )
    }

    func testNuclearTransitionEnergyJoules() {

        let monitor = makeMonitor()

        let expected =
            monitor.inputs.transitionEnergyMeV
            * 1.0e6
            * PhysicalConstants.electronVoltInJoules

        assertClose(
            value(
                "nuclearTransitionEnergyJ",
                in: monitor
            ),
            expected,
            accuracy: 1e-20
        )
    }

    // MARK: - Recovery

    func testRecoveryDynamics() {

        let monitor = makeMonitor()

        let expected =
            exp(
                -monitor.inputs.meanLifetimeSeconds
                * 1e9
            )

        assertClose(
            value(
                "recoveryDynamics",
                in: monitor
            ),
            expected
        )
    }

    func testMeanLifetimeStage() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            value("meanLifetime", in: monitor),
            monitor.inputs.meanLifetimeSeconds,
            accuracy: 1e-15
        )
    }

    // MARK: - Power Pipeline

    func testNuclearTransitionRate() {

        let monitor = makeMonitor()

        let chargeFlow =
            value(
                "chargeFlowRate",
                in: monitor
            )

        let transitionFraction =
            value(
                "transitionFraction",
                in: monitor
            ) / 100.0

        let recovery =
            value(
                "recoveryDynamics",
                in: monitor
            )

        let expected =
            chargeFlow
            * transitionFraction
            * recovery

        assertClose(
            value(
                "nuclearTransitionRate",
                in: monitor
            ),
            expected,
            accuracy: 1e5
        )
    }

    func testNuclearEnergyProduction() {

        let monitor = makeMonitor()

        let rate =
            value(
                "nuclearTransitionRate",
                in: monitor
            )

        let energy =
            value(
                "nuclearTransitionEnergyJ",
                in: monitor
            )

        let expected =
            rate * energy

        assertClose(
            value(
                "nuclearEnergyProduction",
                in: monitor
            ),
            expected,
            accuracy: 1e-10
        )
    }

    func testResonantOutflowPower() {

        let monitor = makeMonitor()

        let gross =
            value(
                "nuclearEnergyProduction",
                in: monitor
            )

        let expected =
            gross * (1.0 - 0.22)

        assertClose(
            value(
                "resonantOutflowPower",
                in: monitor
            ),
            expected,
            accuracy: 1e-10
        )
    }

    func testThermalOutputEqualsOutflowPower() {

        let monitor = makeMonitor()

        assertClose(
            value(
                "thermalOutput",
                in: monitor
            ),
            value(
                "resonantOutflowPower",
                in: monitor
            )
        )
    }

    func testElectricalOutput() {

        let monitor = makeMonitor()

        let thermal =
            value(
                "thermalOutput",
                in: monitor
            )

        let expected =
            thermal
            * monitor.inputs.electricalConversionEfficiency

        assertClose(
            value(
                "electricalOutput",
                in: monitor
            ),
            expected,
            accuracy: 1e-10
        )
    }

    func testNetUsablePower() {

        let monitor = makeMonitor()

        let electrical =
            value(
                "electricalOutput",
                in: monitor
            )

        let expected =
            electrical
            - monitor.inputs.apparatusInputPowerWatts

        assertClose(
            monitor.netUsablePowerWatts,
            expected,
            accuracy: 1e-10
        )
    }

    func testDefaultNetPowerIsNegative() {

        let monitor = makeMonitor()

        XCTAssertLessThan(
            monitor.netUsablePowerWatts,
            0.0
        )

        XCTAssertFalse(
            monitor.isNetPositive
        )
    }

    func testZeroElectricalConversionProducesZeroElectricalOutput() {

        let monitor = makeMonitor {
            $0.electricalConversionEfficiency = 0.0
        }

        XCTAssertEqual(
            value(
                "electricalOutput",
                in: monitor
            ),
            0.0,
            accuracy: 1e-12
        )

        XCTAssertEqual(
            monitor.netUsablePowerWatts,
            -monitor.inputs.apparatusInputPowerWatts,
            accuracy: 1e-12
        )
    }

    // MARK: - Convenience Accessors

    func testNetUsablePowerAccessor() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            monitor.netUsablePowerWatts,
            value(
                "netUsablePower",
                in: monitor
            ),
            accuracy: 1e-12
        )
    }

    func testResonanceFrequencyAccessor() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            monitor.resonanceFrequencyHz,
            value(
                "resonanceFrequency",
                in: monitor
            ),
            accuracy: 1e-12
        )
    }

    func testDeuteriumLoadingPercent() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            monitor.deuteriumLoadingPercent,
            85.0,
            accuracy: 1e-12
        )
    }

    func testFusionThresholdAccessor() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            monitor.fusionThresholdProgress,
            value(
                "fusionThresholdProgress",
                in: monitor
            ) / 100.0,
            accuracy: 1e-12
        )
    }

    func testEffectiveTransitionEnergyAccessor() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            monitor.effectiveTransitionEnergyMeV,
            value(
                "effectiveTransitionEnergy",
                in: monitor
            ),
            accuracy: 1e-12
        )
    }

    // MARK: - Section Filtering

    func testStagesCanBeFilteredBySection() {

        let monitor = makeMonitor()

        for section in PipelineSection.allCases {

            let sectionStages =
                monitor.stages(in: section)

            for stage in sectionStages {

                XCTAssertTrue(
                    monitor.stages.contains {
                        $0.id == stage.id
                    }
                )
            }
        }
    }

    func testSectionStageCounts() {

        let monitor = makeMonitor()

        XCTAssertEqual(
            monitor.stages(
                in: .latticePressure
            ).count,
            5
        )

        XCTAssertEqual(
            monitor.stages(
                in: .latticeDynamics
            ).count,
            6
        )

        XCTAssertEqual(
            monitor.stages(
                in: .shellHamiltonian
            ).count,
            3
        )

        XCTAssertEqual(
            monitor.stages(
                in: .shellGeometry
            ).count,
            3
        )

        XCTAssertEqual(
            monitor.stages(
                in: .nuclearBinding
            ).count,
            7
        )

        XCTAssertEqual(
            monitor.stages(
                in: .electromagnetic
            ).count,
            4
        )

        XCTAssertEqual(
            monitor.stages(
                in: .resonance
            ).count,
            8
        )

        XCTAssertEqual(
            monitor.stages(
                in: .nuclearTransition
            ).count,
            11
        )

        XCTAssertEqual(
            monitor.stages(
                in: .powerOutput
            ).count,
            5
        )
    }

    func testAllStagesBelongToExactlyOneSection() {

        let monitor = makeMonitor()

        var total = 0

        for section in PipelineSection.allCases {
            total += monitor.stages(
                in: section
            ).count
        }

        XCTAssertEqual(
            total,
            monitor.stages.count
        )
    }

    // MARK: - Input Sensitivity

    func testDeuteriumLoadingChangesPressure() {

        let baseline =
            makeMonitor()

        let modified =
            makeMonitor {
                $0.deuteriumToPalladiumRatio = 0.95
            }

        XCTAssertNotEqual(
            value(
                "effectivePressure",
                in: baseline
            ),
            value(
                "effectivePressure",
                in: modified
            )
        )
    }

    func testDeuteriumLoadingChangesContinuity() {

        let baseline =
            makeMonitor()

        let modified =
            makeMonitor {
                $0.deuteriumToPalladiumRatio = 0.50
            }

        XCTAssertNotEqual(
            value(
                "latticeContinuity",
                in: baseline
            ),
            value(
                "latticeContinuity",
                in: modified
            )
        )
    }

    func testCouplingChangesNoetherCharge() {

        let baseline =
            makeMonitor()

        let modified =
            makeMonitor {
                $0.couplingCoefficient = 0.80
            }

        XCTAssertNotEqual(
            value(
                "noetherCharge",
                in: baseline
            ),
            value(
                "noetherCharge",
                in: modified
            )
        )
    }

    func testTemperatureChangesTemperatureShift() {

        let baseline =
            makeMonitor()

        let modified =
            makeMonitor {
                $0.temperatureKelvin = 350.0
            }

        XCTAssertNotEqual(
            value(
                "temperatureResonanceShift",
                in: baseline
            ),
            value(
                "temperatureResonanceShift",
                in: modified
            )
        )
    }

    func testFrequencyChangesLorentzianResponse() {

        let monitor =
            makeMonitor {
                $0.effectiveBulkModulusGPa = 10.0
            }

        let resonance =
            monitor.resonanceFrequencyHz

        monitor.inputs.appliedFrequencyHz =
            resonance

        monitor.recompute()

        let onResonance =
            value(
                "lorentzianResponse",
                in: monitor
            )

        monitor.inputs.appliedFrequencyHz =
            resonance
            + monitor.inputs.resonanceLinewidthHz * 10.0

        monitor.recompute()

        let detuned =
            value(
                "lorentzianResponse",
                in: monitor
            )

        XCTAssertGreaterThan(
            onResonance,
            detuned
        )
    }

    // MARK: - Recompute

    func testRecomputeRebuildsStages() {

        let monitor = makeMonitor()

        let original =
            monitor.stages

        monitor.inputs.plateWidthCm = 10.0
        monitor.recompute()

        let updated =
            monitor.stages

        XCTAssertEqual(
            updated.count,
            52
        )

        XCTAssertNotEqual(
            value(
                "plateArea",
                in: monitor
            ),
            original.first {
                $0.id == "plateArea"
            }?.value ?? .nan
        )
    }

    func testRecomputeProducesFiniteValues() {

        let monitor = makeMonitor()

        for stage in monitor.stages {

            XCTAssertTrue(
                stage.value.isFinite,
                "Stage \(stage.id) is not finite: \(stage.value)"
            )
        }
    }

    func testRecomputeIsDeterministic() {

        let first =
            makeMonitor()

        let second =
            makeMonitor()

        XCTAssertEqual(
            first.stages,
            second.stages
        )
    }

    // MARK: - Simulation State

    func testInitialSimulationState() {

        let monitor = makeMonitor()

        XCTAssertFalse(
            monitor.isRunning
        )

        XCTAssertEqual(
            monitor.elapsedSimulationTime,
            0.0
        )

        XCTAssertEqual(
            monitor.cumulativeEnergyJoules,
            0.0
        )
    }

    func testStartSimulation() {

        let monitor = makeMonitor()

        monitor.startSimulation()

        XCTAssertTrue(
            monitor.isRunning
        )

        XCTAssertEqual(
            monitor.elapsedSimulationTime,
            0.0
        )

        XCTAssertEqual(
            monitor.cumulativeEnergyJoules,
            0.0
        )

        monitor.stopSimulation()
    }

    func testStartingSimulationTwiceDoesNotResetState() {

        let monitor = makeMonitor()

        monitor.startSimulation()

        XCTAssertTrue(
            monitor.isRunning
        )

        monitor.startSimulation()

        XCTAssertTrue(
            monitor.isRunning
        )

        XCTAssertEqual(
            monitor.elapsedSimulationTime,
            0.0
        )

        monitor.stopSimulation()
    }

    func testStopSimulation() {

        let monitor = makeMonitor()

        monitor.startSimulation()

        XCTAssertTrue(
            monitor.isRunning
        )

        monitor.stopSimulation()

        XCTAssertFalse(
            monitor.isRunning
        )
    }

    func testToggleSimulationStarts() {

        let monitor = makeMonitor()

        XCTAssertFalse(
            monitor.isRunning
        )

        monitor.toggleSimulation()

        XCTAssertTrue(
            monitor.isRunning
        )

        monitor.stopSimulation()
    }

    func testToggleSimulationStops() {

        let monitor = makeMonitor()

        monitor.startSimulation()

        XCTAssertTrue(
            monitor.isRunning
        )

        monitor.toggleSimulation()

        XCTAssertFalse(
            monitor.isRunning
        )
    }

    // MARK: - Model Invariants

    func testLorentzianResponseNeverExceedsOne() {

        let monitor =
            makeMonitor {
                $0.effectiveBulkModulusGPa = 10.0
            }

        XCTAssertGreaterThanOrEqual(
            value(
                "lorentzianResponse",
                in: monitor
            ),
            0.0
        )

        XCTAssertLessThanOrEqual(
            value(
                "lorentzianResponse",
                in: monitor
            ),
            1.0
        )
    }

    func testFusionProgressNeverExceedsOne() {

        let monitor =
            makeMonitor()

        XCTAssertGreaterThanOrEqual(
            monitor.fusionThresholdProgress,
            0.0
        )

        XCTAssertLessThanOrEqual(
            monitor.fusionThresholdProgress,
            1.0
        )
    }

    func testDefaultTransitionEnergyIsPositive() {

        let monitor =
            makeMonitor()

        XCTAssertGreaterThan(
            value(
                "nuclearTransitionEnergyJ",
                in: monitor
            ),
            0.0
        )

        XCTAssertGreaterThan(
            monitor.effectiveTransitionEnergyMeV,
            0.0
        )
    }
}
