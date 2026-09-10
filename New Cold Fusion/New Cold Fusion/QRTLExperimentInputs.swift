//
//  File.swift
//  New Cold Fusion
//
//  Created by David Nishimoto on 9/10/26.
//

import Foundation
import SwiftUI

struct QRTLExperimentInputs {
    var latticeExpansionAtFullLoading: Double = 0.065
    var latticeContinuityReferenceLoading: Double = 0.70
    var latticeContinuitySensitivity: Double = 0.40
    var volumetricStrainMultiplier: Double = 3.0
    var excitedStateCoordinateMultiplier: Double = 1.62
    var radialShellRadiusFm: Double = 1.20
    var radialShellPressureCoefficientPerGPa: Double = 0.05
    var nuclearBaselineBindingEnergyMeV: Double = 25.0
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
