/*
 The QRTL cold-fusion recomputation begins with the physical and experimental inputs describing the palladium-deuterium system: palladium plate dimensions, applied current density, deuterium-to-palladium loading ratio, temperature, effective bulk modulus, deuterium pressure coefficient, QRTL shell stiffness, nonlinear coefficient, pressure-to-energy coupling, applied electromagnetic frequency, resonance linewidth, electromagnetic field amplitude, coupling coefficient, resonance coherence and fidelity, mean lifetime, electrical conversion efficiency, and apparatus input power. The model first calculates the palladium plate area, reference current, and charge-flow rate. The deuterium loading is then converted into a fractional lattice expansion using the lattice-expansion parameter, and that expansion is converted into volumetric strain. The effective bulk modulus converts the strain into a mechanical pressure contribution, while the deuterium pressure term represents the loading-dependent contribution. These terms are combined to produce the effective lattice pressure.

 The effective pressure and deuterium loading are then used to determine lattice continuity. Lattice continuity represents how effectively the loaded palladium lattice remains connected for the proposed QRTL interaction. The pressure, lattice continuity, and QRTL shell stiffness produce a lattice action density, which is converted into a QRTL motion amplitude through the nonlinear coefficient. That amplitude determines the QRTL lattice-resonance energy. The model then evaluates the curvature of the effective shell-energy function through its second derivative. A positive second derivative identifies a locally stable configuration. From this stability calculation, the model produces an energy-stability score and establishes the equilibrium coordinate used by the subsequent shell calculations.

 The equilibrium coordinate is inserted into the QRTL shell Hamiltonian, using the nonlinear shell-energy relationship containing both quadratic and quartic terms. The model calculates ground-state and excited-state coordinates and their corresponding shell energies. The difference between the excited and ground states produces the shell-energy separation. That separation is converted from model energy units into electron-volts and then into joules. The corresponding mass-equivalent quantity is calculated using Einstein's energy-mass relationship. The model also calculates the proposed nuclear-state energy scale, now set to approximately **23.8 MeV**, rather than the previous 25 MeV value. This 23.8 MeV value is used as the conventional nuclear energy reference for the proposed helium-4 transition rather than being presented as a newly measured QRTL binding energy.

 The nuclear section then evaluates the proposed stability of the resulting state. The model calculates a lattice binding-energy contribution from its baseline and pressure-dependent terms, compares it with the Coulomb repulsion term, and produces a stability margin. A forbidden-pair penalty is applied only when the model's stability condition is not satisfied. The model also calculates a nuclear-radius scale and an energy/conservation residual. The conservation residual currently functions primarily as an internal bookkeeping check because the shell Hamiltonian and ground-state energy are derived from the same energy function; therefore, it should not be interpreted as independent experimental validation. The QRTL Noether charge is calculated from resonance coherence and coupling, providing a quantity that carries the coherence information into the electromagnetic and transition calculations.

 The electromagnetic portion of the pipeline calculates the effective QRTL electromagnetic coupling from the coupling coefficient, field amplitude, and equilibrium coordinate. From this coupling the model calculates a magnetic-moment-like quantity, magnetic energy density, and Poynting-like energy flux. The shell-energy separation is converted into a resonance frequency using Planck's constant. The applied frequency is then compared with that calculated resonance frequency through the detuning parameter, with the resonance linewidth controlling the width of the response. The resulting Lorentzian response provides the principal resonance factor. Coherence and fidelity then reduce the effective transition probability according to the quality of the resonance. This creates a direct chain from lattice loading and QRTL shell dynamics to the electromagnetic resonance condition rather than using a separate photon-acceleration or index-gradient shortcut.

 The transition section combines the Lorentzian resonance response, coherence, fidelity, charge-flow rate, and the proposed QRTL nuclear enhancement mechanism to calculate the nuclear transition rate. The maximum resonant transition fraction limits how much of the available transition population can participate. The resonance progress is calculated from the product of resonance response, coherence, and fidelity and is limited to the physically meaningful range from zero to one. This produces an effective transition-energy quantity, while the approximately 23.8 MeV nuclear transition energy provides the reference energy scale for the proposed helium-4 pathway. The model then applies the mean lifetime through a recovery factor and calculates the resulting nuclear transition rate.

 Finally, the transition rate is converted into gross energy production by multiplying the transition rate by the nuclear transition energy in joules. A specified recycled fraction is removed from the gross output to represent internal energy recycling or losses, producing the thermal output. The thermal output is multiplied by the electrical conversion efficiency to obtain electrical output, and the apparatus input power is subtracted to obtain net usable power. The complete recomputation therefore follows a single dependency chain: **palladium geometry and electrical loading → deuterium loading → lattice expansion → strain → effective pressure → lattice continuity → QRTL action → shell motion → shell energy → resonance energy separation → electromagnetic resonance → coherence and fidelity → proposed nuclear transition → helium-4-associated energy scale → transition rate → gross energy → thermal output → electrical output → net usable power.**

 The central reasoning of the model is therefore that the palladium-deuterium environment establishes the lattice conditions, those conditions determine the proposed QRTL shell state, the shell state determines an energy separation and resonance condition, and resonance determines the probability of the proposed nuclear transition. The model does **not** treat the observation of helium-4 as proof of the mechanism. Instead, reported helium-4 observations provide experimental motivation, while the approximately **23.8 MeV** value supplies a conventional nuclear energy reference. The scientifically important test is whether the complete QRTL calculation can produce a quantitative prediction of transition probability, helium-4 production, and associated energy **before** the experimental result is used to adjust the parameters.

 */

import Foundation
import SwiftUI

struct QRTLExperimentInputs {
    var latticeExpansionAtFullLoading: Double = 0.045
    var latticeContinuityReferenceLoading: Double = 0.70
    var latticeContinuitySensitivity: Double = 0.40
    var volumetricStrainMultiplier: Double = 3.0
    var excitedStateCoordinateMultiplier: Double = 1.62
    var radialShellRadiusFm: Double = 1.20
    var radialShellPressureCoefficientPerGPa: Double = 0.05
    var nuclearBaselineBindingEnergyMeV: Double = 23.8
    var nuclearBindingPressureCoefficientMeVPerGPa: Double = 0.60
    var coulombRepulsionMeV: Double = 0.72
    var forbiddenPairPenaltyMeV: Double = 12.0
    var nuclearRadiusCoefficientFm: Double = 1.25

    // MARK: Transition / Energy Accounting

    /// Fraction of gross transition energy recycled internally.
    var recycledEnergyFraction: Double = 0.22

    // MARK: Temperature / Resonance Model

    /// Temperature-dependent resonance coefficient.
    var temperatureResonanceCoefficientPerKelvin: Double = 0.002

    /// Reference temperature for the resonance-temperature shift.
    var referenceTemperatureKelvin: Double = 293.0

    /// Lorentzian detuning convention.
    var resonanceDetuningMultiplier: Double = 2.0

    /// Energy-to-model-unit conversion used by the shell model.
    var shellEnergyToEVScale: Double = 1.0

    // MARK: Simulation Controls

    /// Wall-clock interval represented by one simulation integration step.
    var simulationTickIntervalSeconds: Double = 0.2

    /// Resonance sweep span in linewidths.
    var resonanceSweepSpanLinewidths: Double = 3.0

    /// Resonance sweep period.
    var resonanceSweepPeriodSeconds: Double = 20.0
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
