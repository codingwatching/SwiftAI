import Foundation

/// A type-safe constraint that can be applied to specific types during generation.
public struct Constraint<Value>: Sendable, Equatable {
  internal let payload: ConstraintPayload

  init(payload: ConstraintPayload) {
    self.payload = payload
  }

  init(kind: ConstraintKind) {
    // TODO: The fact that the init is internal means that no external code can create new constraints.
    //  Revisit this decision.
    self.payload = .this(kind)
  }
}

/// The constraint payload - either constrains this value or in case of collections constraints
/// one or more of its sub-values.
enum ConstraintPayload: Sendable, Equatable {
  case this(ConstraintKind)  // constrains this value
  indirect case sub(AnyConstraint)  // constrains sub-values
}

/// The internal representation of constraint types.
public enum ConstraintKind: Sendable, Equatable {
  case string(StringConstraint)
  case int(IntConstraint)
  case double(DoubleConstraint)
  case boolean
  indirect case array(ArrayConstraint)
}

/// A type-erased constraint that can be applied to any schema.
public struct AnyConstraint: Sendable, Equatable {  // FIXME: Does this need to be PUBLIC?
  let payload: ConstraintPayload

  public init<Value>(_ constraint: Constraint<Value>) {
    self.payload = constraint.payload
  }

  init(payload: ConstraintPayload) {
    self.payload = payload
  }

  public init(kind: ConstraintKind) {
    self.payload = .this(kind)
  }
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

// MARK: - Array Constraints

extension Constraint {
  /// Enforces that the array has exactly a certain number elements.
  public static func count<Element>(_ count: Int) -> Constraint<[Element]>
  where Value == [Element] {
    Constraint(kind: .array(.count(lowerBound: count, upperBound: count)))
  }

  /// Enforces a minimum number of elements in the array.
  public static func minimumCount<Element>(_ count: Int) -> Constraint<[Element]>
  where Value == [Element] {
    Constraint(kind: .array(.count(lowerBound: count, upperBound: nil)))
  }

  /// Enforces a maximum number of elements in the array.
  public static func maximumCount<Element>(_ count: Int) -> Constraint<[Element]>
  where Value == [Element] {
    Constraint(kind: .array(.count(lowerBound: nil, upperBound: count)))
  }

  /// Applies a constraint to each element in the array.
  public static func element<Element>(_ constraint: Constraint<Element>) -> Constraint<[Element]>
  where Value == [Element] {
    Constraint(payload: .sub(AnyConstraint(constraint)))
  }
}

// MARK: - Array Constraints for Never Type

extension Constraint where Value == [Never] {

  /// Enforces a minimum number of elements in the array.
  ///
  /// - Warning: This overload is only used for macro expansion. Don't call `Constraint<[Never]>.minimumCount(_:)` on your own.
  public static func minimumCount(_ count: Int) -> Constraint<Value> {
    Constraint(kind: .array(.count(lowerBound: count, upperBound: nil)))
  }

  /// Enforces a maximum number of elements in the array.
  ///
  /// - Warning: This overload is only used for macro expansion. Don't call `Constraint<[Never]>.maximumCount(_:)` on your own.
  public static func maximumCount(_ count: Int) -> Constraint<Value> {
    Constraint(kind: .array(.count(lowerBound: nil, upperBound: count)))
  }

  /// Enforces that the number of elements in the array fall within a closed range.
  ///
  /// Bounds are inclusive.
  ///
  /// - Warning: This overload is only used for macro expansion. Don't call `Constraint<[Never]>.count(_:)` on your own.
  public static func count(_ range: ClosedRange<Int>) -> Constraint<Value> {
    Constraint(kind: .array(.count(lowerBound: range.lowerBound, upperBound: range.upperBound)))
  }

  /// Enforces that the array has exactly a certain number elements.
  ///
  /// - Warning: This overload is only used for macro expansion. Don't call `Constraint<[Never]>.count(_:)` on your own.
  public static func count(_ count: Int) -> Constraint<Value> {
    Constraint(kind: .array(.count(lowerBound: count, upperBound: count)))
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
}

/// Constraints that can be applied to boolean values.
public enum BoolConstraint: Sendable, Equatable {}

/// Constraints that can be applied to string values.
public enum StringConstraint: Sendable, Equatable {
  /// Requires the string to match a regular expression pattern.
  case pattern(String)  // TODO: Consider accepting a Regex object. It's safer.

  /// Requires the string to be exactly the specified value.
  case constant(String)

  /// Requires the string to be one of the specified options.
  case anyOf([String])
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
