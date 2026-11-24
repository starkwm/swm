import CoreGraphics
import Foundation

public enum IPCCommand: Codable, Equatable, Sendable {
  public enum Config: Codable, Equatable, Sendable {
    case animationDuration(Double?)
    case animationEasing(AnimationEasing?)
    case focusFollowsMouse(FocusFollowsMouseMode?)
    case layout(scope: ConfigScope, LayoutSelection?)
    case masterRatio(scope: ConfigScope, LayoutRatioChange?)
    case masterPlacement(scope: ConfigScope, MasterPlacementChange?)
    case splitRatio(scope: ConfigScope, LayoutRatioChange?)
    case preserveSplit(scope: ConfigScope, Bool?)
    case gap(scope: ConfigScope, NumericChange<Int>?)
    case padding(scope: ConfigScope, [PaddingSideChange])
  }

  public enum Reload: Codable, Equatable, Sendable {
    case begin(processID: pid_t)
    case commit(token: String)
    case rollback(token: String)
  }

  public enum Window: Codable, Equatable, Sendable {
    case focus(WindowTarget)
    case focusCycle(CycleDirection)
    case focusMaster(WindowSelection)
    case warp(WindowTarget)
    case minimize(WindowSelection)
    case unminimize(WindowSelection)
    case layout(WindowSelection, WindowLayoutSelection)
    case swap(WindowSelection, CardinalDirection)
    case swapCycle(CycleDirection)
    case swapWithMaster(WindowSelection)
    case splitRatio(WindowSelection, LayoutRatioChange)
    case toggleSplit(WindowSelection)
    case swapSplit(WindowSelection)
    case move(WindowSelection, NumericChange<IntPair>)
    case resize(WindowSelection, NumericChange<IntPair>)
    case grid(WindowSelection, WindowGrid)
    case display(WindowSelection, WindowDisplayTarget)
    case space(WindowSelection, WindowSpaceTarget)
  }

  public enum Rule: Codable, Equatable, Sendable {
    case add([String])
    case remove(String)
    case clear
    case list
  }

  case config(Config)
  case reload(Reload)
  case spaceActivate(index: Int)
  case displayFocus(DisplayTarget)
  case window(Window)
  case query(QueryKind, QuerySelection)
  case rule(Rule)

  var logDescription: String {
    switch self {
    case .config(let command):
      switch command {
      case .animationDuration: "config animation-duration"
      case .animationEasing: "config animation-easing"
      case .focusFollowsMouse: "config focus-follows-mouse"
      case .layout: "config layout"
      case .masterRatio: "config master-ratio"
      case .masterPlacement: "config master-placement"
      case .splitRatio: "config split-ratio"
      case .preserveSplit: "config preserve-split"
      case .gap: "config gap"
      case .padding: "config padding"
      }
    case .reload(let command):
      switch command {
      case .begin: "reload begin"
      case .commit: "reload commit"
      case .rollback: "reload rollback"
      }
    case .spaceActivate: "space activate"
    case .displayFocus: "display focus"
    case .window(let command):
      switch command {
      case .focus: "window focus"
      case .focusCycle: "window focus-cycle"
      case .focusMaster: "window focus-master"
      case .warp: "window warp"
      case .minimize: "window minimize"
      case .unminimize: "window unminimize"
      case .layout: "window layout"
      case .swap: "window swap"
      case .swapCycle: "window swap-cycle"
      case .swapWithMaster: "window swap-with-master"
      case .splitRatio: "window split-ratio"
      case .toggleSplit: "window toggle-split"
      case .swapSplit: "window swap-split"
      case .move: "window move"
      case .resize: "window resize"
      case .grid: "window grid"
      case .display: "window display"
      case .space: "window space"
      }
    case .query(let kind, _): "query \(kind.rawValue)"
    case .rule(let command):
      switch command {
      case .add: "rule add"
      case .remove: "rule remove"
      case .clear: "rule clear"
      case .list: "rule list"
      }
    }
  }
}

public enum ConfigScope: Codable, Equatable, Sendable {
  case global
  case currentSpace
  case space(Int)
}

public enum MasterPlacementChange: Codable, Equatable, Sendable {
  case set(MasterPlacement)
  case cycle(CycleDirection)
}

public enum QueryKind: String, Codable, Equatable, Sendable {
  case displays
  case spaces
  case windows
}

public enum WindowSelection: Codable, Equatable, Sendable {
  case focused
  case recent
  case id(CGWindowID)

  public init?(argument: String) {
    if argument == "recent" {
      self = .recent
    } else if let id = UInt32(argument), id > 0 {
      self = .id(CGWindowID(id))
    } else {
      return nil
    }
  }
}

public enum WindowTarget: Codable, Equatable, Sendable {
  case selected(WindowSelection)
  case direction(CardinalDirection)
}

public struct IntPair: Codable, Equatable, Sendable {
  public let first: Int
  public let second: Int

  public init(_ first: Int, _ second: Int) {
    self.first = first
    self.second = second
  }
}
