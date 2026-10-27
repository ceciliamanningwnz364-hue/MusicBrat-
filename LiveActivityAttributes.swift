import ActivityKit

struct MusicLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        var elapsed: TimeInterval
        var duration: TimeInterval
    }
    var title: String
}
