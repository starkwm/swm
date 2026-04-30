import Foundation
import Testing

@testable import SwmLib

@Suite("QueryResponse")
struct QueryResponseTests {
  @Test("dispatcher returns query JSON arrays")
  func dispatcherReturnsQueryJSONArrays() {
    let dispatcher = DefaultIPCCommandDispatcher()

    for command in ["--displays", "--windows", "--spaces"] {
      let request = IPCRequest(
        id: "request-id",
        domain: .query,
        command: command,
        args: []
      )

      let response = dispatcher.dispatch(request)

      #expect(response.id == "request-id")
      #expect(response.ok)
      #expect(response.errorCode == nil)
      #expect(response.message.hasPrefix("["))
      #expect(response.message.hasSuffix("]"))
    }
  }

  @Test("unsupported query command returns structured failure")
  func unsupportedQueryCommandReturnsStructuredFailure() {
    let dispatcher = DefaultIPCCommandDispatcher()
    let request = IPCRequest(
      id: "request-id",
      domain: .query,
      command: "--unknown",
      args: []
    )

    let response = dispatcher.dispatch(request)

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported query command: --unknown")
  }

  @Test("display DTO encodes kebab-case keys")
  func displayDTOEncodesKebabCaseKeys() throws {
    let display = QueryDisplay(
      id: "display-id",
      uuid: nil,
      index: 0,
      frame: QueryFrame(.zero),
      spaces: [1],
      hasFocus: true
    )

    let object = try encodedObject(display)

    #expect(object["has-focus"] as? Bool == true)
    #expect(object["uuid"] is NSNull)
  }

  @Test("window DTO encodes nullable kebab-case keys")
  func windowDTOEncodesNullableKebabCaseKeys() throws {
    let window = QueryWindow(
      id: 1,
      pid: nil,
      app: nil,
      title: nil,
      frame: nil,
      role: nil,
      subrole: nil,
      rootWindow: nil,
      display: nil,
      space: nil,
      level: nil,
      subLevel: nil,
      layer: nil,
      subLayer: nil,
      opacity: nil,
      canMove: nil,
      canResize: nil,
      hasFocus: nil,
      hasShadow: nil,
      hasParentZoom: nil,
      hasFullscreenZoom: nil,
      hasAXReference: false,
      isNativeFullscreen: nil,
      isVisible: nil,
      isMinimized: nil,
      isHidden: nil,
      isFloating: nil,
      isSticky: nil
    )

    let object = try encodedObject(window)

    #expect(object["root-window"] is NSNull)
    #expect(object["has-ax-reference"] as? Bool == false)
    #expect(object["is-native-fullscreen"] is NSNull)
  }

  @Test("space DTO encodes serialized windows")
  func spaceDTOEncodesSerializedWindows() throws {
    let window = QueryWindow(
      id: 1,
      pid: nil,
      app: nil,
      title: nil,
      frame: nil,
      role: nil,
      subrole: nil,
      rootWindow: nil,
      display: nil,
      space: nil,
      level: nil,
      subLevel: nil,
      layer: nil,
      subLayer: nil,
      opacity: nil,
      canMove: nil,
      canResize: nil,
      hasFocus: nil,
      hasShadow: nil,
      hasParentZoom: nil,
      hasFullscreenZoom: nil,
      hasAXReference: false,
      isNativeFullscreen: nil,
      isVisible: nil,
      isMinimized: nil,
      isHidden: nil,
      isFloating: nil,
      isSticky: nil
    )
    let space = QuerySpace(
      id: 1,
      uuid: nil,
      index: 0,
      label: nil,
      type: "normal",
      display: nil,
      windows: [window],
      hasFocus: false,
      isVisible: false,
      isNativeFullscreen: false
    )

    let object = try encodedObject(space)
    let windows = try #require(object["windows"] as? [[String: Any]])
    let encodedWindow = try #require(windows.first)

    #expect(encodedWindow["id"] as? Int == 1)
    #expect(encodedWindow["has-ax-reference"] as? Bool == false)
    #expect(object["first-window"] == nil)
    #expect(object["last-window"] == nil)
    #expect(object["has-focus"] as? Bool == false)
    #expect(object["is-native-fullscreen"] as? Bool == false)
  }

  @Test("space DTO encodes empty window array")
  func spaceDTOEncodesEmptyWindowArray() throws {
    let space = QuerySpace(
      id: 1,
      uuid: nil,
      index: 0,
      label: nil,
      type: "normal",
      display: nil,
      windows: [],
      hasFocus: false,
      isVisible: false,
      isNativeFullscreen: false
    )

    let object = try encodedObject(space)
    let windows = try #require(object["windows"] as? [Any])

    #expect(windows.isEmpty)
    #expect(object["first-window"] == nil)
    #expect(object["last-window"] == nil)
  }

  private func encodedObject<T: Encodable>(_ value: T) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
  }
}
