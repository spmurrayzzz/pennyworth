import Foundation
import os

enum PerformanceSignposts {
    private static let log = OSLog(subsystem: "com.local.pennyworth", category: "performance")
    private static let poster = OSSignposter(logHandle: log)

    enum Interval {
        static let panelPresentation = "PanelPresentation"
        static let queryParse = "QueryParse"
        static let search = "SearchRun"
        static let fileSearch = "FileSearch"
        static let mergeRank = "MergeRank"
        static let publish = "ResultsPublish"
        static let icon = "IconLoad"
        static let action = "ActionExecute"
        static let database = "DatabaseWrite"
    }

    @inline(__always)
    static func measure<R>(_ name: StaticString, _ work: () throws -> R) rethrows -> R {
        let state = poster.beginInterval(name)
        defer { poster.endInterval(name, state) }
        return try work()
    }

    static func begin(_ name: StaticString) -> OSSignpostIntervalState {
        poster.beginInterval(name)
    }

    static func end(_ name: StaticString, _ state: OSSignpostIntervalState) {
        poster.endInterval(name, state)
    }
}