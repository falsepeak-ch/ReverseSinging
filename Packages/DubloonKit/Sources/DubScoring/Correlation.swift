//
//  Correlation.swift
//  DubScoring
//

import Accelerate

enum Correlation {

    /// Pearson correlation, -1...1.
    ///
    /// Zero for two series of different lengths, for a series too short to vary, and for a
    /// constant one, where "how do these two vary together" has no answer.
    static func pearson(_ x: [Float], _ y: [Float]) -> Float {
        guard x.count == y.count, x.count > 1 else { return 0 }

        let centredX = vDSP.add(-vDSP.mean(x), x)
        let centredY = vDSP.add(-vDSP.mean(y), y)

        let varianceX = vDSP.dot(centredX, centredX)
        let varianceY = vDSP.dot(centredY, centredY)
        guard varianceX > 0, varianceY > 0 else { return 0 }

        return vDSP.dot(centredX, centredY) / (varianceX * varianceY).squareRoot()
    }
}
