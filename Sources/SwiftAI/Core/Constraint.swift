import Foundation

/// A type-safe constraint that can be applied to specific types during generation.
public struct Constraint<Value>: Sendable, Equatable {
  internal let kind: ConstraintKind

  internal init(kind: ConstraintKind) {
    self.kind = kind
  }
}

/// The internal representation of constraint types.
public enum ConstraintKind: Sendable, Equatable {
  case string(StringConstraint)
  case int(IntConstraint)
  case double(DoubleConstraint)
  case boolean(BooleanConstraint)
  indirect case array(ArrayConstraint)
}

// MARK: - String Constraints

extension Constraint where Value == String {
  /// Requires the string to match a regular expression pattern.
  public static func pattern(_ regex: String) -> Constraint<String> {
    Constraint(kind: .string(.pattern(regex)))
  }

  /// Requires the string to be exactly the specified value.
  public static func constant(_ value: String) -> Constraint<String> {
    Constraint(kind: .string(.constant(value)))
  }

  /// Requires the string to be one of the specified options.
  public static func anyOf(_ options: [String]) -> Constraint<String> {
    Constraint(kind: .string(.anyOf(options)))
  }

  /// Constrains the minimum length of the string.
  public static func minLength(_ length: Int) -> Constraint<String> {
    Constraint(kind: .string(.len(min: length, max: nil)))
  }

  /// Constrains the maximum length of the string.
  public static func maxLength(_ length: Int) -> Constraint<String> {
    Constraint(kind: .string(.len(min: nil, max: length)))
  }
}

// MARK: - Integer Constraints

extension Constraint where Value == Int {
  /// Sets a minimum value for the integer.
  public static func minimum(_ value: Int) -> Constraint<Int> {
    Constraint(kind: .int(.range(lowerBound: value, upperBound: nil)))
  }

  /// Sets a maximum value for the integer.
  public static func maximum(_ value: Int) -> Constraint<Int> {
    Constraint(kind: .int(.range(lowerBound: nil, upperBound: value)))
  }

  /// Constrains the integer to be within a specific range.
  public static func range(_ range: ClosedRange<Int>) -> Constraint<Int> {
    Constraint(kind: .int(.range(lowerBound: range.lowerBound, upperBound: range.upperBound)))
  }
}

// MARK: - Double Constraints

extension Constraint where Value == Double {
  /// Sets a minimum value for the number.
  public static func minimum(_ value: Double) -> Constraint<Double> {
    Constraint(kind: .double(.range(lowerBound: value, upperBound: nil)))
  }

  /// Sets a maximum value for the number.
  public static func maximum(_ value: Double) -> Constraint<Double> {
    Constraint(kind: .double(.range(lowerBound: nil, upperBound: value)))
  }

  /// Constrains the number to be within a specific range.
  public static func range(_ range: ClosedRange<Double>) -> Constraint<Double> {
    Constraint(kind: .double(.range(lowerBound: range.lowerBound, upperBound: range.upperBound)))
  }
}

// MARK: - Boolean Constraints

extension Constraint where Value == Bool {
  /// Requires the boolean to be exactly the specified value.
  public static func constant(_ value: Bool) -> Constraint<Bool> {
    Constraint(kind: .boolean(.constant(value)))
  }
}

// MARK: - Array Constraints

extension Constraint {
  /// Constrains the exact number of elements in an array.
  public static func count<Element>(_ count: Int) -> Constraint<[Element]>
  where Value == [Element] {
    Constraint(kind: .array(.count(lowerBound: count, upperBound: count)))
  }

  /// Sets a minimum number of elements in an array.
  public static func minimumCount<Element>(_ count: Int) -> Constraint<[Element]>
  where Value == [Element] {
    Constraint(kind: .array(.count(lowerBound: count, upperBound: nil)))
  }

  /// Sets a maximum number of elements in an array.
  public static func maximumCount<Element>(_ count: Int) -> Constraint<[Element]>
  where Value == [Element] {
    Constraint(kind: .array(.count(lowerBound: nil, upperBound: count)))
  }

  /// Applies a constraint to each element in the array.
  public static func element<Element>(_ constraint: Constraint<Element>) -> Constraint<[Element]>
  where Value == [Element] {
    Constraint(kind: .array(.element(constraint.kind)))
  }
}

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

/// Constraints that can be applied to boolean values.
public enum BooleanConstraint: Sendable, Equatable {
  /// Requires the boolean to be exactly the specified value.
  case constant(Bool)
}
