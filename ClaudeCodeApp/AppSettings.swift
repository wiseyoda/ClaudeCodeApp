import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("serverURL") var serverURL: String = "http://10.0.3.2:8080"

    var baseURL: URL? {
        URL(string: serverURL)
    }
}
