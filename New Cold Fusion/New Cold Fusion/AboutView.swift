//
//  AboutView.swift
//  QRTL Cold Fusion
//
//  Created by David S. Nishimoto on 9/10/26.
//  Copyright © 2026 David S. Nishimoto.
//

import SwiftUI

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    @ObservedObject var monitor: QRTLColdFusionMonitor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {

                    header

                    introduction

                    analogy

                    currentParameters

                    pipeline

                    finalPrediction

                    interpretation

                    disclaimer

                    author
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // ============================================================
    // MARK: - Header
    // ============================================================

    private var header: some View {
        VStack(spacing: 10) {

            Image(systemName: "atom")
                .font(.system(size: 58))
                .foregroundStyle(.blue)

            Text("QRTL Cold Fusion")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Palladium–Deuterium QRTL Resonance Model")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Computational research prototype")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // ============================================================
    // MARK: - Introduction
    // ============================================================

    private var introduction: some View {
        section(
            title: "What This App Models",
            icon: "waveform.path.ecg"
        ) {

            Text("""
            This application models a proposed QRTL pathway for a
            palladium–deuterium system.

            The calculation starts with the physical and operating
            parameters supplied to the model. Those parameters are
            transformed through a sequence of lattice, shell,
            electromagnetic, resonance, nuclear-transition, and
            power calculations.

            The important point is that the result is a MODEL
            PREDICTION. It is not automatically an experimental
            measurement.
            """)
        }
    }

    // ============================================================
    // MARK: - Analogy
    // ============================================================

    private var analogy: some View {
        section(
            title: "Understanding the Process: The Musical Instrument Analogy",
            icon: "music.note"
        ) {

            Text("""
            Imagine the palladium lattice as a very complicated musical
            instrument.

            Deuterium loading is like tightening or changing the strings.
            The lattice pressure determines how tightly the instrument
            is being stressed.

            The QRTL lattice dynamics describe how that instrument moves.

            The QRTL shell is like the resonant body of the instrument.
            It has preferred energy states, just as a violin string has
            preferred frequencies.

            The electromagnetic drive is the musician exciting the
            instrument.

            Resonance occurs when the musician plays the right note.

            The Lorentzian response represents how strongly the instrument
            responds when the applied frequency approaches its natural
            frequency.

            Coherence and fidelity describe how well the excitation is
            synchronized with the desired resonant state.

            The proposed nuclear transition is analogous to the instrument
            transferring enough organized energy into another mode.

            Finally, the model converts the calculated transition rate and
            transition energy into predicted power.

            In short:

            LOAD → STRESS → OSCILLATE → RESONATE → TRANSITION → POWER

            This analogy explains the computational flow. It does not
            imply that a palladium lattice is literally a musical
            instrument or that the proposed nuclear mechanism has been
            experimentally established.
            """)
            .font(.body)
        }
    }

    // ============================================================
    // MARK: - Current Parameters
    // ============================================================

    private var currentParameters: some View {
        section(
            title: "Current Model Parameters",
            icon: "slider.horizontal.3"
        ) {

            Text("""
            These are the values currently contained in the QRTL
            experiment input structure. Changing a parameter changes
            the calculation and therefore can change the predicted
            results.
            """)
            .foregroundStyle(.secondary)

            let values = parameterValues()

            ForEach(values, id: \.name) { parameter in
                parameterRow(
                    name: parameter.name,
                    value: parameter.value
                )
            }
        }
    }

    // ============================================================
    // MARK: - Pipeline
    // ============================================================

    private var pipeline: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("The QRTL Pipeline")
                .font(.title2)
                .fontWeight(.bold)

            stepCard(
                number: 1,
                title: "Palladium Geometry & Electrical Operating Point",
                icon: "rectangle.grid.2x2",
                parameters: """
                The model uses the currently configured palladium
                plate dimensions and current density.

                These values are shown above in Current Model Parameters.
                """,
                how: """
                Plate width × plate height produces the reference
                palladium plate area.

                The area is multiplied by current density to calculate
                the reference operating current.

                Current is then converted into an elementary-charge
                flow rate.
                """,
                why: """
                This establishes the starting operating condition for
                the rest of the calculation. Without an input flow,
                the later transition-rate calculation has no population
                of modeled charge-flow events to act on.
                """,
                resultIDs: [
                    "plateArea",
                    "referenceCurrent",
                    "chargeFlowRate"
                ]
            )

            stepCard(
                number: 2,
                title: "Deuterium Loading & Effective QRTL Pressure",
                icon: "arrow.down.to.line",
                parameters: """
                The important inputs are the D/Pd ratio, lattice
                expansion at full loading, volumetric strain multiplier,
                effective bulk modulus, and deuterium pressure coefficient.
                """,
                how: """
                The D/Pd ratio determines the fractional lattice change.
                That change is multiplied by the volumetric strain
                multiplier.

                The model then combines the elastic bulk-modulus term
                with the deuterium pressure contribution to produce
                effective pressure.
                """,
                why: """
                This converts deuterium loading into the model's
                mechanical driving condition. It is the bridge between
                material loading and the proposed QRTL lattice dynamics.
                """,
                resultIDs: [
                    "volumetricStrain",
                    "effectivePressure"
                ]
            )

            stepCard(
                number: 3,
                title: "Local Lattice Continuity",
                icon: "circle.grid.3x3",
                parameters: """
                The model uses the configured lattice-continuity
                sensitivity and reference D/Pd loading.
                """,
                how: """
                Continuity is calculated from how far the actual D/Pd
                loading is from the model's reference loading.

                Loading closer to the reference condition produces a
                higher modeled continuity value.
                """,
                why: """
                The model treats spatially consistent lattice activity
                as important because the following QRTL action calculation
                depends on this continuity factor.
                """,
                resultIDs: [
                    "latticeContinuity"
                ]
            )

            stepCard(
                number: 4,
                title: "QRTL Lattice Action & Motion",
                icon: "waveform",
                parameters: """
                The primary parameters are effective pressure,
                lattice continuity, shell stiffness, and nonlinear
                coefficient.
                """,
                how: """
                QRTL lattice action is calculated from:

                effective pressure × lattice continuity × shell stiffness.

                The action is then divided by the nonlinear response
                term to obtain a modeled oscillation amplitude.

                Resonance energy is proportional to the square of that
                motion amplitude.
                """,
                why: """
                This is where the model changes from a static loading
                condition into a dynamic lattice state.
                """,
                resultIDs: [
                    "latticeAction",
                    "equationsOfMotion",
                    "latticeResonanceEnergy",
                    "stabilityCondition",
                    "energyStabilityScore"
                ]
            )

            stepCard(
                number: 5,
                title: "QRTL Shell Hamiltonian & Energy States",
                icon: "circle.dashed",
                parameters: """
                The shell calculation uses shell stiffness,
                nonlinear coefficient, equilibrium coordinate, and
                excited-state coordinate multiplier.
                """,
                how: """
                The model's shell energy contains a quadratic term and
                a nonlinear fourth-power term.

                The Hamiltonian is evaluated at the modeled equilibrium
                coordinate.

                Ground and excited shell coordinates are then evaluated
                to obtain two modeled energy states.
                """,
                why: """
                The energy difference between the modeled shell states
                becomes the basis for calculating the QRTL resonance
                frequency.
                """,
                resultIDs: [
                    "shellHamiltonian",
                    "shellEigenstateGround",
                    "shellEigenstateExcited"
                ]
            )

            stepCard(
                number: 6,
                title: "Nuclear Binding & Stability",
                icon: "atom",
                parameters: """
                This stage uses the model's nuclear-binding parameters,
                including its lattice binding, Coulomb contribution,
                forbidden-pair penalty, and nuclear-radius parameters.
                """,
                how: """
                The model compares the configured QRTL binding
                contribution with the modeled Coulomb and stability
                terms.

                It also calculates a modeled nuclear radius and an
                energy-momentum bookkeeping residual.
                """,
                why: """
                The purpose of this stage is to determine whether the
                proposed configuration is energetically acceptable
                within the assumptions of the QRTL model before the
                transition calculation proceeds.
                """,
                resultIDs: [
                    "nuclearBinding",
                    "forbiddenPairPenalty",
                    "nuclearRadiusRelation",
                    "energyMomentumConservation",
                    "noetherCharge"
                ]
            )

            stepCard(
                number: 7,
                title: "Electromagnetic Coupling",
                icon: "bolt.horizontal.circle",
                parameters: """
                The model uses the configured electromagnetic field
                amplitude and coupling coefficient.
                """,
                how: """
                QRTL electromagnetic coupling is calculated from the
                coupling coefficient, electromagnetic field amplitude,
                and equilibrium coordinate.

                That coupling is then used to calculate a modeled
                shell magnetic moment, magnetic energy density, and
                Poynting energy flux.
                """,
                why: """
                This represents the proposed pathway by which the
                external electromagnetic drive interacts with the
                modeled QRTL shell.
                """,
                resultIDs: [
                    "electromagneticCoupling",
                    "shellMagneticMoment",
                    "magneticEnergyDensity",
                    "poyntingFlux"
                ]
            )

            stepCard(
                number: 8,
                title: "Resonance Frequency",
                icon: "dot.radiowaves.left.and.right",
                parameters: """
                The resonance calculation uses the shell-energy
                separation, Planck's constant, pressure coupling,
                temperature coefficient, applied frequency, and
                resonance linewidth.
                """,
                how: """
                The modeled shell-energy separation is converted to
                joules and divided by Planck's constant.

                This produces the modeled QRTL resonance frequency.

                Pressure, D/Pd loading, and temperature can then shift
                that frequency.
                """,
                why: """
                Resonance is the central selection mechanism in this
                computational pathway. The model is looking for an
                applied frequency condition that strongly couples to
                the calculated shell transition.
                """,
                resultIDs: [
                    "shellEnergySeparation",
                    "resonanceFrequency",
                    "pressureResonanceShift",
                    "dPdResonanceShift",
                    "temperatureResonanceShift"
                ]
            )

            stepCard(
                number: 9,
                title: "Lorentzian Resonance Response",
                icon: "waveform.path",
                parameters: """
                The important inputs are applied frequency, calculated
                resonance frequency, resonance linewidth, and detuning
                multiplier.
                """,
                how: """
                The model calculates frequency detuning relative to
                resonance.

                The response follows a Lorentzian relationship:

                Response = 1 / (1 + detuning²)

                A frequency closer to resonance therefore produces a
                larger modeled response.
                """,
                why: """
                This converts frequency alignment into a quantitative
                response strength that feeds the subsequent transition
                calculation.
                """,
                resultIDs: [
                    "lorentzianResponse"
                ]
            )

            stepCard(
                number: 10,
                title: "Coherence, Fidelity & Shell Transition",
                icon: "arrow.triangle.2.circlepath",
                parameters: """
                The model uses resonance coherence, resonance fidelity,
                coupling, nuclear enhancement parameters, and the
                maximum resonant transition fraction.
                """,
                how: """
                The shell transition rate is proportional to resonance
                response × coherence × fidelity × charge flow.

                The model then applies its enhancement function and
                calculates the proposed transition fraction.
                """,
                why: """
                This stage determines how efficiently the resonant
                condition is converted into the modeled population of
                proposed nuclear transitions.
                """,
                resultIDs: [
                    "resonanceCoherence",
                    "resonanceFidelity",
                    "qrtlTransitionRate",
                    "matrixElementEnhancement",
                    "transitionFraction",
                    "fusionThresholdProgress",
                    "effectiveTransitionEnergy"
                ]
            )

            stepCard(
                number: 11,
                title: "Proposed Nuclear Transition Energy",
                icon: "sparkles",
                parameters: """
                The configured transition energy is the key parameter
                for this stage.
                """,
                how: """
                The configured transition energy in MeV is converted
                into joules using the electron-volt conversion.

                The model also reports how much of that configured
                transition energy is currently realized according to
                the calculated threshold progress.
                """,
                why: """
                Energy per transition is what converts a modeled
                transition rate into a modeled power output.
                """,
                resultIDs: [
                    "nuclearTransitionEnergyMeV",
                    "nuclearTransitionEnergyJ",
                    "effectiveTransitionEnergy",
                    "nuclearTransitionRate"
                ]
            )

            stepCard(
                number: 12,
                title: "Recovery & Transition Rate",
                icon: "arrow.clockwise",
                parameters: """
                The relevant parameter is the configured mean lifetime
                of the modeled shell state.
                """,
                how: """
                The model calculates a recovery factor from the configured
                lifetime and uses that factor together with charge flow
                and transition fraction to determine the final modeled
                nuclear transition rate.
                """,
                why: """
                This prevents the transition calculation from simply
                assuming that every available charge-flow event produces
                a successful transition.
                """,
                resultIDs: [
                    "recoveryDynamics",
                    "meanLifetime",
                    "nuclearTransitionRate"
                ]
            )

            stepCard(
                number: 13,
                title: "Predicted Power",
                icon: "bolt.fill",
                parameters: """
                The final power calculation uses transition rate,
                transition energy, recycled-energy fraction, electrical
                conversion efficiency, and apparatus input power.
                """,
                how: """
                The model multiplies transition rate by transition
                energy to obtain modeled gross nuclear-energy production.

                It then applies the configured recycling fraction and
                electrical-conversion efficiency.

                Finally, apparatus input power is subtracted to obtain
                net usable power.
                """,
                why: """
                This is the final engineering-level output of the
                computational chain. It tells us whether the configured
                assumptions produce a positive or negative modeled
                energy balance.
                """,
                resultIDs: [
                    "nuclearEnergyProduction",
                    "resonantOutflowPower",
                    "thermalOutput",
                    "electricalOutput",
                    "netUsablePower"
                ]
            )
        }
    }

    // ============================================================
    // MARK: - Final Prediction
    // ============================================================

    private var finalPrediction: some View {
        section(
            title: "Predicted Results",
            icon: "chart.bar.xaxis"
        ) {

            predictionCard(
                title: "D/Pd Loading",
                value: format(monitor.deuteriumLoadingPercent),
                unit: "%",
                explanation: """
                Current deuterium loading relative to palladium according
                to the configured model input.
                """
            )

            predictionCard(
                title: "QRTL Resonance Frequency",
                value: formatScientific(monitor.resonanceFrequencyHz),
                unit: "Hz",
                explanation: """
                Calculated from the modeled shell-energy separation.
                """
            )

            predictionCard(
                title: "Effective Transition Energy",
                value: format(monitor.effectiveTransitionEnergyMeV),
                unit: "MeV",
                explanation: """
                The currently realized modeled fraction of the configured
                transition energy.
                """
            )

            predictionCard(
                title: "Net Usable Power",
                value: formatScientific(monitor.netUsablePowerWatts),
                unit: "W",
                explanation: """
                Modeled electrical output after recycling and conversion,
                minus the configured apparatus input power.
                """
            )

            HStack(spacing: 10) {

                Image(
                    systemName:
                        monitor.isNetPositive
                        ? "checkmark.circle.fill"
                        : "minus.circle.fill"
                )

                Text(
                    monitor.isNetPositive
                    ? "The current model configuration predicts positive net usable power."
                    : "The current model configuration does not predict positive net usable power."
                )
                .fontWeight(.semibold)
            }
            .foregroundStyle(
                monitor.isNetPositive ? .green : .secondary
            )
        }
    }

    // ============================================================
    // MARK: - Interpretation
    // ============================================================

    private var interpretation: some View {
        section(
            title: "How to Interpret the Prediction",
            icon: "questionmark.circle"
        ) {

            Text("""
            The predicted values answer a computational question:

            "Given these parameters and these equations, what does the
            QRTL model calculate?"

            They do NOT automatically answer the experimental question:

            "Does this physical mechanism actually occur in nature?"

            The second question requires experimental evidence.
            """)

            VStack(alignment: .leading, spacing: 8) {

                Text("Model prediction")
                    .fontWeight(.bold)

                Text("A numerical result generated by the equations and current parameters.")
                    .foregroundStyle(.secondary)

                Text("Experimental observation")
                    .fontWeight(.bold)

                Text("A quantity independently measured from a physical experiment.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // ============================================================
    // MARK: - Disclaimer
    // ============================================================

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 12) {

            Label("Scientific Disclaimer", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)

            Text("""
            QRTL Cold Fusion is an experimental computational model.

            QRTL lattice action, shell states, resonance enhancement,
            nuclear stabilization, and the proposed D–D transition
            mechanism are hypothetical model constructs.

            A calculated positive energy balance is a model prediction
            and is not, by itself, experimental evidence of cold fusion,
            excess energy, or nuclear fusion.

            Experimental validation would require independent measurements
            of nuclear products, energy balance, radiation, isotopic
            composition, and appropriate controls.
            """)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // ============================================================
    // MARK: - Author
    // ============================================================

    private var author: some View {
        VStack(spacing: 5) {

            Text("QRTL Cold Fusion")
                .font(.headline)

            Text("David S. Nishimoto")
                .font(.subheadline)

            Text("Copyright © 2026 David S. Nishimoto")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    // ============================================================
    // MARK: - Step Card
    // ============================================================

    private func stepCard(
        number: Int,
        title: String,
        icon: String,
        parameters: String,
        how: String,
        why: String,
        resultIDs: [String]
    ) -> some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 12) {

                Text("\(number)")
                    .font(.headline)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                    )

                Image(systemName: icon)
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.headline)
            }

            subsection(
                title: "Parameters",
                text: parameters
            )

            subsection(
                title: "How It Works",
                text: how
            )

            subsection(
                title: "Why This Step Is Important",
                text: why
            )

            if !resultIDs.isEmpty {

                VStack(alignment: .leading, spacing: 6) {

                    Text("Predicted / Calculated Results")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    ForEach(resultIDs, id: \.self) { id in
                        stageResultRow(id: id)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.06))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.07))
        )
    }

    // ============================================================
    // MARK: - Stage Result
    // ============================================================

    @ViewBuilder
    private func stageResultRow(id: String) -> some View {

        if let stage = monitor.stages.first(where: { $0.id == id }) {

            HStack(alignment: .firstTextBaseline) {

                Text(stage.name)
                    .font(.caption)

                Spacer()

                Text(format(stage.value))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)

                Text(stage.unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // ============================================================
    // MARK: - Parameter Reflection
    // ============================================================

    private struct ParameterValue {
        let name: String
        let value: String
    }

    private func parameterValues() -> [ParameterValue] {

        Mirror(reflecting: monitor.inputs).children.compactMap { child in

            guard let label = child.label else {
                return nil
            }

            return ParameterValue(
                name: prettyParameterName(label),
                value: formatAny(child.value)
            )
        }
    }

    private func prettyParameterName(_ name: String) -> String {

        var result = ""

        for character in name {

            if character.isUppercase {
                result += " "
                result += String(character)
            } else {
                result += String(character)
            }
        }

        return result
            .replacingOccurrences(
                of: "Ma Per Cm",
                with: "mA/cm"
            )
            .replacingOccurrences(
                of: "Cm",
                with: "cm"
            )
            .replacingOccurrences(
                of: "Hz",
                with: "Hz"
            )
            .capitalized
    }

    private func formatAny(_ value: Any) -> String {

        if let value = value as? Double {
            return format(value)
        }

        if let value = value as? Float {
            return format(Double(value))
        }

        if let value = value as? Int {
            return "\(value)"
        }

        if let value = value as? Bool {
            return value ? "true" : "false"
        }

        return String(describing: value)
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func subsection(
        title: String,
        text: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 5) {

            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func parameterRow(
        name: String,
        value: String
    ) -> some View {

        HStack {

            Text(name)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
        }
        .padding(.vertical, 3)
    }

    private func predictionCard(
        title: String,
        value: String,
        unit: String,
        explanation: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .font(.system(.title3, design: .monospaced))

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.07))
        )
    }

    private func section<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(alignment: .leading, spacing: 14) {

            Label(title, systemImage: icon)
                .font(.headline)

            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func format(_ value: Double) -> String {

        if abs(value) >= 1_000_000 ||
            (abs(value) > 0 && abs(value) < 0.001) {

            return String(format: "%.4e", value)
        }

        return String(format: "%.6g", value)
    }

    private func formatScientific(_ value: Double) -> String {
        String(format: "%.4e", value)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    AboutView(
        monitor: QRTLColdFusionMonitor()
    )
}
