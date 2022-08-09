//
// --------------------------------------------------------------------------
// TestAccelerationCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Use this to test how x values relate to physical speed of mouse 

import Foundation

class TestAccelerationCurve: AccelerationCurve {
    
    let thresholdSpeed: Double
    let firstSens: Double
    let secondSens: Double
    
    required init(thresholdSpeed: Double, firstSens: Double, secondSens: Double) {
        self.thresholdSpeed = thresholdSpeed
        self.firstSens = firstSens
        self.secondSens = secondSens
    }
    
    override func evaluate(at x: Double) -> Double {
        return x < thresholdSpeed ? firstSens : secondSens
    }
}