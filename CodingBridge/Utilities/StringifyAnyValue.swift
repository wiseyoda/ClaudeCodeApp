import Foundation

// MARK: - Global Utility Functions

/// Convert Any value to a display string, handling nested types properly.
/// This avoids showing type wrappers like "AnyCodable(value: ...)" in the UI.
///
/// **Note**: This function uses explicit type checks rather than Mirror reflection
/// because it's more performant and handles the specific types we care about:
/// - String: Return as-is
/// - NSNumber: Use stringValue
/// - AnyCodableValue: Use stringValue property
/// - Dictionary: Extract "stdout" for bash results, or serialize to JSON
/// - Array: Serialize to JSON
/// - Fallback: Strip wrapper patterns from String(describing:)
func stringifyAnyValue(_ value: Any) -> String {
    // Handle String directly
    if let str = value as? String {
        return str
    }
    // Handle numbers and bools
    if let num = value as? NSNumber {
        return num.stringValue
    }
    // Handle AnyCodableValue wrapper (from CLIBridgeAppTypes.swift)
    if let codable = value as? AnyCodableValue, let str = codable.stringValue {
        return str
    }
    // Handle dictionaries - convert to JSON or extract common fields
    if let dict = value as? [String: Any] {
        // Try to extract "stdout" for bash results
        if let stdout = dict["stdout"] as? String {
            return stdout
        }
        // Convert to JSON
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
    }
    // Handle arrays
    if let array = value as? [Any] {
        if let data = try? JSONSerialization.data(withJSONObject: array, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
    }
    // Fallback - use String(describing:) but avoid showing type names
    let description = String(describing: value)
    // Strip common wrapper patterns like "AnyCodable(value: ...)" or "Optional(...)"
    if description.hasPrefix("AnyCodable(value: ") && description.hasSuffix(")") {
        let inner = description.dropFirst("AnyCodable(value: ".count).dropLast()
        return String(inner)
    }
    if description.hasPrefix("AnyCodableValue(value: ") && description.hasSuffix(")") {
        let inner = description.dropFirst("AnyCodableValue(value: ".count).dropLast()
        return String(inner)
    }
    return description
}
