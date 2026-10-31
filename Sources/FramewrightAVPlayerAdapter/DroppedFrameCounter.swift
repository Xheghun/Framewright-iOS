struct DroppedFrameCounter {
    private var counts: [Int] = []
    private var reported = false
    private var lastMs: Int64 = 0

    mutating func reset(baseline: [Int], at milliseconds: Int64) {
        counts = baseline
        reported = false
        lastMs = milliseconds
    }

    mutating func sample(_ values: [Int], at milliseconds: Int64) -> (count: Int, elapsedMs: Int64)? {
        guard values.count >= counts.count else {
            reset(baseline: values, at: milliseconds)
            return nil
        }
        var delta = 0
        var known = false
        for (index, value) in values.enumerated() where value >= 0 {
            known = true
            let previous = index < counts.count ? max(0, counts[index]) : 0
            let increment = max(0, value - previous)
            let sum = delta.addingReportingOverflow(increment)
            guard !sum.overflow, sum.partialValue <= Int(Int32.max) else { return nil }
            delta = sum.partialValue
        }
        guard known else { return nil }
        for (index, value) in values.enumerated() {
            if index >= counts.count {
                counts.append(value)
            } else if value >= 0 {
                counts[index] = max(counts[index], value)
            }
        }
        guard !reported || delta > 0 else { return nil }
        reported = true
        let elapsed = max(0, milliseconds - lastMs)
        lastMs = milliseconds
        return (delta, elapsed)
    }
}
