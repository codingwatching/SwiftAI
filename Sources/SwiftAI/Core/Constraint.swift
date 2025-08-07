import Foundation

/// Constraints that can be applied to array values.
public enum ArrayConstraint: Sendable, Equatable {
    /// Constrains the number of elements in the array.
    ///
    /// - Parameters:
    ///   - lowerBound: The minimum number of elements (nil for no minimum)
    ///   - upperBound: The maximum number of elements (nil for no maximum)
    case count(lowerBound: Int?, upperBound: Int?)
    
    /// Applies a constraint to each element in the array.
    case element(ConstraintKind)
}

/// Constraints that can be applied to string values.
public enum StringConstraint: Sendable, Equatable {
    /// Requires the string to match a regular expression pattern.
    case pattern(String)
    
    /// Requires the string to be exactly the specified value.
    case constant(String)
    
    /// Requires the string to be one of the specified options.
    case anyOf([String])
    
    /// Constrains the length of the string.
    ///
    /// - Parameters:
    ///   - min: The minimum length (nil for no minimum)
    ///   - max: The maximum length (nil for no maximum)
    case len(min: Int?, max: Int?)
}

/// Constraints that can be applied to integer values.
public enum IntConstraint: Sendable, Equatable {
    /// Constrains the integer to be within a specific range.
    ///
    /// - Parameters:
    ///   - lowerBound: The minimum value (nil for no minimum)
    ///   - upperBound: The maximum value (nil for no maximum)
    case range(lowerBound: Int?, upperBound: Int?)
}

/// Constraints that can be applied to floating-point values.
public enum DoubleConstraint: Sendable, Equatable {
    /// Constrains the number to be within a specific range.
    ///
    /// - Parameters:
    ///   - lowerBound: The minimum value (nil for no minimum)
    ///   - upperBound: The maximum value (nil for no maximum)
    case range(lowerBound: Double?, upperBound: Double?)
}