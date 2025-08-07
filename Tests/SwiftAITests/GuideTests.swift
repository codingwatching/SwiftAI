import Foundation
import SwiftAI
import Testing

// MARK: - Test Types

@Generable
struct SimpleProduct {
  @Guide("The unique product identifier")
  let id: String

  @Guide("The product name")
  let name: String

  @Guide("Price in USD")
  let price: Double
}

@Generable
struct ConstrainedProduct {
  @Guide("Product SKU", .pattern("[A-Z]{3}-\\d{4}"))
  let sku: String

  @Guide("Quantity in stock", .minimum(0))
  let quantity: Int

  @Guide("Price in USD", .range(0.01...9999.99))
  let price: Double
}

// MARK: - Basic @Guide Macro Tests

@Test func guideWithDescriptionOnly() throws {
  // This test verifies that @Guide macro can be applied with just a description
  let expectedSchema = Schema.object(
    properties: [
      "id": Schema.Property(
        schema: .string(
          constraints: [],
          metadata: Schema.Metadata(description: "The unique product identifier")),
        isOptional: false),
      "name": Schema.Property(
        schema: .string(
          constraints: [], metadata: Schema.Metadata(description: "The product name")),
        isOptional: false),
      "price": Schema.Property(
        schema: .number(
          constraints: [], metadata: Schema.Metadata(description: "Price in USD")),
        isOptional: false),
    ],
    metadata: nil
  )

  #expect(SimpleProduct.schema == expectedSchema)
}

@Test func guideWithConstraints() throws {
  // This test verifies that @Guide macro can be applied with constraints
  let expectedSchema = Schema.object(
    properties: [
      "sku": Schema.Property(
        schema: .string(
          constraints: [], metadata: Schema.Metadata(description: "Product SKU")),
        isOptional: false),
      "quantity": Schema.Property(
        schema: .integer(
          constraints: [], metadata: Schema.Metadata(description: "Quantity in stock")),
        isOptional: false),
      "price": Schema.Property(
        schema: .number(
          constraints: [], metadata: Schema.Metadata(description: "Price in USD")),
        isOptional: false),
    ],
    metadata: nil
  )

  #expect(ConstrainedProduct.schema == expectedSchema)
}
