#if os(iOS)
import SwiftUI
import UIKit
import MiradorCore

struct RemoteKeyboardInputView: UIViewRepresentable {
    @Binding var isActive: Bool
    let onText: (String) -> Void
    let onKey: (RemoteKeyboardKey) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.autocorrectionType = .yes
        textField.autocapitalizationType = .sentences
        textField.spellCheckingType = .yes
        textField.returnKeyType = .default
        textField.textContentType = nil
        textField.tintColor = .clear
        textField.textColor = .clear
        textField.backgroundColor = .clear
        textField.accessibilityLabel = "Remote keyboard input"
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.input = self
        if isActive, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !isActive, textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var input: RemoteKeyboardInputView

        init(_ input: RemoteKeyboardInputView) {
            self.input = input
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            if string.isEmpty, range.length > 0 {
                for _ in 0..<range.length {
                    input.onKey(.deleteBackward)
                }
            } else if !string.isEmpty {
                input.onText(string)
            }

            textField.text = ""
            return false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            input.onKey(.returnKey)
            return false
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            input.isActive = false
        }
    }
}
#endif
