//
//MIT License
//
//Copyright © 2025 Cong Le
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//
//  EarthquakeProtectionView.swift
//  MyApp
//
//  Created by Cong Le on 6/28/25.
//

import SwiftUI
import Combine

// MARK: - Main View: Earthquake Protection Demo

/// A SwiftUI view that visually demonstrates the principles of base isolation for protecting
/// structures from earthquake damage.
///
/// This simulation compares two buildings:
/// 1.  **Fixed-Base Building:** A conventional structure directly connected to the ground. It moves
///     in unison with the ground shaking, experiencing significant stress.
/// 2.  **Base-Isolated Building:** A modern structure built on flexible bearings (isolators).
///     These isolators absorb the earthquake's energy, allowing the ground to move beneath the
///     building while the superstructure remains relatively still.
///
/// The simulation uses a real-time physics model (a damped, forced harmonic oscillator) to
/// calculate the response of the isolated building, providing a realistic depiction of its behavior.
/// Users can adjust earthquake frequency and the building's physical properties to see how
/// these factors influence the outcome.
struct EarthquakeProtectionView: View {
    
    // MARK: - State Properties
    
    // --- Simulation Core State ---
    /// Tracks if the earthquake simulation is currently active.
    @State private var isSimulating = false
    
    /// A monotonic increasing value representing the elapsed time in the simulation.
    @State private var simulationTime: Double = 0.0
    
    /// A cancellable subscription to the timer that drives the animation frames.
    @State private var timerSubscription: Cancellable?
    
    // --- Physics & Environment Parameters ---
    /// The frequency of the earthquake's shaking motion in Hertz (Hz).
    @State private var earthquakeFrequency: Double = 1.2
    
    /// The amplitude (maximum displacement) of the ground shaking in points.
    @State private var earthquakeAmplitude: Double = 35.0
    
    /// The stiffness (`k`) of the base isolators. Lower values mean more flexibility.
    /// In physics terms, this is the spring constant of the isolation system.
    @State private var isolatorStiffness: Double = 30.0
    
    /// The damping coefficient (`b`) of the base isolators. This represents the system's
    /// ability to dissipate energy (e.g., as heat), preventing unchecked oscillations.
    @State private var isolatorDamping: Double = 4.5
    
    // --- Calculated Displacements ---
    /// The real-time horizontal offset of the ground, calculated each frame.
    @State private var groundOffset: CGFloat = 0
    
    /// The real-time horizontal offset of the isolated building's superstructure.
    @State private var isolatedBuildingOffset: CGFloat = 0
    
    // --- Physics Integration State ---
    /// The velocity of the isolated building, used for numerical integration.
    @State private var isolatedBuildingVelocity: CGFloat = 0
    
    // MARK: - Constants
    
    /// The time step for the physics simulation (60 frames per second).
    private let timeInterval: Double = 1.0 / 60.0
    
    /// The conceptual mass (`m`) of the building's superstructure.
    private let buildingMass: Double = 15.0
    
    // MARK: - UI Body
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(naturalFrequency: calculateNaturalFrequency())
            
            // --- MAIN VISUALIZATION CANVAS ---
            VStack(spacing: 0) {
                Spacer()
                
                // Buildings are rendered here
                HStack(alignment: .bottom, spacing: 60) {
                    BuildingView(
                        title: "Fixed-Base",
                        isIsolated: false,
                        buildingOffset: groundOffset // Fixed building moves with the ground
                    )
                    
                    BuildingView(
                        title: "Base-Isolated",
                        isIsolated: true,
                        buildingOffset: isolatedBuildingOffset, // Isolated building moves based on physics
                        groundOffset: groundOffset
                    )
                }
                
                // Ground plane
                Rectangle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(height: 60)
                    .overlay(Text("GROUND").font(.caption).bold().foregroundColor(.white))
                    .offset(x: groundOffset) // The ground itself shakes
                
                Spacer()
            }
            .background(Color(UIColor.systemGray6))
            .frame(maxHeight: .infinity)
            
            // --- CONTROL PANEL ---
            ControlPanelView(
                isSimulating: $isSimulating,
                earthquakeFrequency: $earthquakeFrequency,
                isolatorStiffness: $isolatorStiffness,
                isolatorDamping: $isolatorDamping,
                onToggleSimulation: toggleSimulation
            )
        }
        .navigationTitle("Base Isolation Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Simulation Logic
    
    /// Starts or stops the earthquake simulation.
    private func toggleSimulation() {
        isSimulating.toggle()
        if isSimulating {
            startSimulation()
        } else {
            stopSimulation()
        }
    }
    
    /// Initializes and starts the simulation timer.
    private func startSimulation() {
        // Reset state before starting
        resetSimulationState()
        
        // Create a timer publisher that fires on the main thread for UI updates.
        timerSubscription = Timer.publish(every: timeInterval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // This closure is called for every frame of the animation.
                updateFrame()
            }
    }
    
    /// Stops the simulation and cancels the timer.
    private func stopSimulation() {
        timerSubscription?.cancel()
        timerSubscription = nil
        withAnimation(.easeOut(duration: 0.5)) {
            resetSimulationState()
        }
    }
    
    /// Resets all dynamic properties to their initial states.
    private func resetSimulationState() {
        simulationTime = 0
        groundOffset = 0
        isolatedBuildingOffset = 0
        isolatedBuildingVelocity = 0
    }
    
    /// Calculates the physics for a single frame of the animation.
    private func updateFrame() {
        // 1. Advance the simulation time.
        simulationTime += timeInterval
        
        // 2. Calculate ground motion (the driving force).
        // This is a simple sine wave representing the ground shaking back and forth.
        let angularFrequency = 2.0 * .pi * earthquakeFrequency
        groundOffset = earthquakeAmplitude * sin(angularFrequency * simulationTime)
        
        // 3. Calculate the isolated building's response using a physics model.
        // This models a damped, forced harmonic oscillator.
        // The equation of motion is: m*a = -k*x_rel - b*v
        // where x_rel is the displacement of the building relative to the ground.
        let relativeDisplacement = isolatedBuildingOffset - groundOffset
        
        // Calculate forces acting on the building's mass.
        let springForce = -isolatorStiffness * relativeDisplacement
        let dampingForce = -isolatorDamping * isolatedBuildingVelocity
        
        // Calculate acceleration (Newton's Second Law: a = F_net / m).
        let acceleration = (springForce + dampingForce) / buildingMass
        
        // 4. Update velocity and position using Euler integration.
        // This is a simple numerical method to approximate the new state based on the old.
        isolatedBuildingVelocity += acceleration * timeInterval
        isolatedBuildingOffset += isolatedBuildingVelocity * timeInterval
    }
    
    /// Calculates the natural frequency of the base-isolated building.
    /// The goal of base isolation is to make this frequency much lower than the
    /// earthquake's frequency to avoid resonance.
    /// Formula: f_n = (1 / 2π) * sqrt(k / m)
    /// - returns: The natural frequency in Hertz (Hz).
    private func calculateNaturalFrequency() -> Double {
        return (1.0 / (2.0 * .pi)) * sqrt(isolatorStiffness / buildingMass)
    }
}

// MARK: - Subviews & Components

/// A helper view for the header section.
private struct HeaderView: View {
    let naturalFrequency: Double
    
    var body: some View {
        VStack {
            Text("Building Natural Frequency: **\(naturalFrequency, specifier: "%.2f") Hz**")
                .font(.footnote)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
            
            Text("Goal: Keep building frequency far from earthquake frequency to avoid resonance.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(Color(UIColor.systemBackground))
    }
}

/// A view that renders a single building and its foundation.
private struct BuildingView: View {
    let title: String
    let isIsolated: Bool
    var buildingOffset: CGFloat
    var groundOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Building Superstructure
            Rectangle()
                .fill(isIsolated ? Color.blue : Color.red)
                .frame(width: 80, height: 150)
                .overlay(
                    WindowGridView()
                )
                .overlay(
                    Text(title)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(4)
                        .offset(y: -20),
                    alignment: .top
                )
                .offset(x: buildingOffset)
            
            // Foundation / Isolator
            ZStack {
                if isIsolated {
                    // Visual representation of flexible base isolators
                    IsolatorView(
                        buildingOffset: buildingOffset,
                        groundOffset: groundOffset
                    )
                } else {
                    // Solid foundation for the fixed-base building
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 90, height: 30)
                        .offset(x: buildingOffset) // Moves with the building (and ground)
                }
            }
        }
    }
}

/// A view representing the flexible base isolators.
private struct IsolatorView: View {
    var buildingOffset: CGFloat
    var groundOffset: CGFloat
    
    var body: some View {
        // A custom path to draw a flexible connection that shears during motion.
        Path { path in
            let width: CGFloat = 80
            let height: CGFloat = 30
            let topY: CGFloat = 0
            let bottomY: CGFloat = height
            
            let topLeft = CGPoint(x: -width/2 + buildingOffset, y: topY)
            let topRight = CGPoint(x: width/2 + buildingOffset, y: topY)
            let bottomLeft = CGPoint(x: -width/2 + groundOffset, y: bottomY)
            let bottomRight = CGPoint(x: width/2 + groundOffset, y: bottomY)
            
            path.move(to: bottomLeft)
            path.addLine(to: topLeft)
            path.addLine(to: topRight)
            path.addLine(to: bottomRight)
            path.closeSubpath()
        }
        .fill(Color.orange)
    }
}

/// A view for the grid of windows on the building facade.
private struct WindowGridView: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<5) { _ in
                HStack(spacing: 8) {
                    ForEach(0..<2) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(8)
    }
}

/// A view containing the sliders and button to control the simulation.
private struct ControlPanelView: View {
    @Binding var isSimulating: Bool
    @Binding var earthquakeFrequency: Double
    @Binding var isolatorStiffness: Double
    @Binding var isolatorDamping: Double
    let onToggleSimulation: () -> Void
    
    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()
    
    var body: some View {
        Form {
            Section(header: Text("Simulation Controls")) {
                ParameterSlider(
                    label: "Earthquake Frequency (Hz)",
                    value: $earthquakeFrequency,
                    range: 0.2...2.5,
                    specifier: "%.1f"
                )
                
                ParameterSlider(
                    label: "Isolator Stiffness (k)",
                    value: $isolatorStiffness,
                    range: 10...100,
                    specifier: "%.0f"
                )
                
                ParameterSlider(
                    label: "Isolator Damping (b)",
                    value: $isolatorDamping,
                    range: 0...15,
                    specifier: "%.1f"
                )
                
                Button(action: onToggleSimulation) {
                    HStack {
                        Image(systemName: isSimulating ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundColor(isSimulating ? .red : .green)
                        Text(isSimulating ? "Stop Simulation" : "Start Earthquake")
                    }
                }
                .font(.headline)
            }
        }
        .frame(height: 280) // Fixed height for the control panel
    }
}

/// A reusable slider component for adjusting simulation parameters.
private struct ParameterSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let specifier: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: specifier, value))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct EarthquakeProtectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EarthquakeProtectionView()
        }
    }
}
