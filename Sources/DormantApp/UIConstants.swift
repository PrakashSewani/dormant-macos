import SwiftUI

enum UIConstants {
  static let minButtonWidth: CGFloat = 84
  static let buttonSpacing: CGFloat = 12
  static let dialogPadding: CGFloat = 20
  static let dialogSpacing: CGFloat = 16
  static let dialogMinWidth: CGFloat = 440
  static let toolbarButtonMinWidth: CGFloat = 68
}

struct DialogButtonSizing: ViewModifier {
  func body(content: Content) -> some View {
    content
      .controlSize(.large)
      .frame(minWidth: UIConstants.minButtonWidth)
  }
}

extension View {
  func dialogButton() -> some View {
    modifier(DialogButtonSizing())
  }
}
