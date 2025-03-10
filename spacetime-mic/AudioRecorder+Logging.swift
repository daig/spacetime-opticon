import Foundation
import AVFoundation
import SwiftUI

extension AudioRecorder {
    // MARK: - Logging
    
    /// Adds a message to the log
    internal func log(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages += message + "\n"
        }
    }
} 