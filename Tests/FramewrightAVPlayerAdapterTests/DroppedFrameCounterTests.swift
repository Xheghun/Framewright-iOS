import Testing

@testable import FramewrightAVPlayerAdapter

@Test func droppedFrameCountersDeduplicateAndKeepUnknownDistinctFromZero() {
    var counter = DroppedFrameCounter()
    counter.reset(baseline: [], at: 10)
    #expect(counter.sample([], at: 20) == nil)
    #expect(counter.sample([-1], at: 20) == nil)
    let zero = counter.sample([0], at: 30)
    #expect(zero?.count == 0)
    #expect(zero?.elapsedMs == 20)
    #expect(counter.sample([0], at: 40) == nil)
    #expect(counter.sample([3], at: 50)?.count == 3)
    #expect(counter.sample([3, 2], at: 60)?.count == 2)
    #expect(counter.sample([-1, 2], at: 70) == nil)
    #expect(counter.sample([3, 2], at: 80) == nil)
}

@Test func droppedFramesExcludeEarlierSessionsAndHandleLogResets() {
    var counter = DroppedFrameCounter()
    counter.reset(baseline: [5, 2], at: 10)
    #expect(counter.sample([5, 2], at: 20)?.count == 0)
    #expect(counter.sample([5, 4], at: 30)?.count == 2)
    #expect(counter.sample([0], at: 40) == nil)
    #expect(counter.sample([1], at: 50)?.count == 1)
}
