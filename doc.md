# GeneratedContent

A type that represents structured, generated content.

struct GeneratedContent

## Mentioned in

Expanding generation with tool calling

Generating Swift data structures with guided generation

## Overview

Generated content may contain a single value, an array, or key-value pairs with unique keys.

## Topics

### Creating generated content

`init(_:)`

Creates generated content from another value.

`init(some ConvertibleToGeneratedContent, id: GenerationID)`

Creates content that contains a single value with a custom generation ID.

Creates content representing an array of elements you specify.

`init(kind: GeneratedContent.Kind, id: GenerationID?)`

Creates a new `GeneratedContent` instance with the specified kind and generation ID.

### Creating content from properties

Creates generated content representing a structure with the properties you specify.

Creates new generated content from the key-value pairs in the given sequence, using a combining closure to determine the value for any duplicate keys.

### Creating content from JSON

`init(json: String) throws`

Creates equivalent content from a JSON string.

### Creating content from kind

`enum Kind`

A representation of the different types of content that can be stored in `GeneratedContent`.

### Accessing instance properties

`var kind: GeneratedContent.Kind`

The kind representation of this generated content.

`var isComplete: Bool`

A Boolean that indicates whether the generated content is completed.

`var jsonString: String`

Returns a JSON string representation of the generated content.

### Getting the debug description

`var debugDescription: String`

A string representation for the debug description.

### Reads a value from the concrete type

Reads a top level, concrete partially generable type.

`func value(_:forProperty:)`

Reads a concrete generable type from named property.

### Retrieving the schema and content

`var generatedContent: GeneratedContent`

A representation of this instance.

### Getting the unique generation id

`var id: GenerationID?`

A unique id that is stable for the duration of a generated response.

## Relationships

### Conforms To

- `ConvertibleFromGeneratedContent`
- `ConvertibleToGeneratedContent`
- `CustomDebugStringConvertible`
- `Equatable`
- `Generable`
- `InstructionsRepresentable`
- `PromptRepresentable`
- `Sendable`
- `SendableMetatype`

---

https://developer.apple.com/documentation/foundationmodels/generatedcontent/init(_:id:)

- Foundation Models
- GeneratedContent
- init(\_:id:) Beta

Initializer

Creates content that contains a single value with a custom generation ID.

init(
\_ value: some ConvertibleToGeneratedContent,
id: GenerationID
)

## Parameters

`value`

The underlying value.

`id`

The generation ID for this content.

---

https://developer.apple.com/documentation/foundationmodels/generatedcontent/init(elements:id:)

- Foundation Models
- GeneratedContent
- init(elements:id:) Beta

Initializer

# init(elements:id:)

Creates content representing an array of elements you specify.

elements: S,
id: GenerationID? = nil
) where S : Sequence, S.Element == any ConvertibleToGeneratedContent

---

https://developer.apple.com/documentation/foundationmodels/generatedcontent/init(kind:id:)

- Foundation Models
- GeneratedContent
- init(kind:id:) Beta

Initializer

# init(kind:id:)

Creates a new `GeneratedContent` instance with the specified kind and generation ID.

init(
kind: GeneratedContent.Kind,
id: GenerationID? = nil
)

## Parameters

`kind`

The kind of content to create.

`id`

An optional generation ID to associate with this content.

## Discussion

This initializer provides a convenient way to create content from its kind representation.

---

https://developer.apple.com/documentation/foundationmodels/generatedcontent/init(properties:id:)

- Foundation Models
- GeneratedContent
- init(properties:id:) Beta

Initializer

# init(properties:id:)

Creates generated content representing a structure with the properties you specify.

init(

id: GenerationID? = nil
)

## Discussion

The order of properties is important. For `Generable` types, the order must match the order properties in the types `schema`.

---

https://developer.apple.com/documentation/foundationmodels/generatedcontent/init(properties:id:uniquingkeyswith:)

#app-main)

- Foundation Models
- GeneratedContent
- init(properties:id:uniquingKeysWith:) Beta

Initializer

# init(properties:id:uniquingKeysWith:)

Creates new generated content from the key-value pairs in the given sequence, using a combining closure to determine the value for any duplicate keys.

properties: S,
id: GenerationID? = nil,

) rethrows where S : Sequence, S.Element == (String, any ConvertibleToGeneratedContent)

## Parameters

`properties`

A sequence of key-value pairs to use for the new content.

`id`

A unique id associated with GeneratedContent.

## Discussion

The order of properties is important. For `Generable` types, the order must match the order properties in the types `schema`.

You use this initializer to create generated content when you have a sequence of key-value tuples that might have duplicate keys. As the content is built, the initializer calls the `combine` closure with the current and new values for any duplicate keys. Pass a closure as `combine` that returns the value to use in the resulting content: The closure can choose between the two values, combine them to produce a new value, or even throw an error.

The following example shows how to choose the first and last values for any duplicate keys:

let content = GeneratedContent(
properties: [("name", "John"), ("name", "Jane"), ("married": true)],
uniquingKeysWith: { (first, \_ in first }
)
// GeneratedContent(["name": "John", "married": true])


---

https://developer.apple.com/documentation/foundationmodels/generatedcontent/init(json:)


- Foundation Models
- GeneratedContent
- init(json:) Beta

Initializer

# init(json:)

Creates equivalent content from a JSON string.

init(json: String) throws

## Discussion

The JSON string you provide may be incomplete. This is useful for correctly handling partially generated responses.

@Generable struct NovelIdea {
let title: String
}

let partial = #"{"title": "A story of"#
let content = try GeneratedContent(json: partial)
let idea = try NovelIdea(content)
print(idea.title) // A story of

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

Learn more about using Apple's beta software

---

https://developer.apple.com/documentation/foundationmodels/generatedcontent/kind-swift.enum

- Foundation Models
- GeneratedContent
- GeneratedContent.Kind Beta

Enumeration

# GeneratedContent.Kind

A representation of the different types of content that can be stored in `GeneratedContent`.

enum Kind

## Overview

`Kind` represents the various types of JSON-compatible data that can be held within a `GeneratedContent` instance, including primitive types, arrays, and structured objects.

## Topics

### Getting the kind of content

[`case array([GeneratedContent])`](<https://developer.apple.com/documentation/foundationmodels/generatedcontent/kind-swift.enum/array(_:)>)

Represents an array of `GeneratedContent` elements.

`case bool(Bool)`

Represents a boolean value.

`case null`

Represents a null value.

`case number(Double)`

Represents a numeric value.

`case string(String)`

Represents a string value.

[`case structure(properties: [String : GeneratedContent], orderedKeys: [String])`](<https://developer.apple.com/documentation/foundationmodels/generatedcontent/kind-swift.enum/structure(properties:orderedkeys:)>)

Represents a structured object with key-value pairs.

## Relationships

### Conforms To

- `Equatable`
- `Sendable`
- `SendableMetatype`

---

# https://developer.apple.com/documentation/foundationmodels/generatedcontent/kind-swift.property

- Foundation Models
- GeneratedContent
- kind Beta

Instance Property

# kind

The kind representation of this generated content.

var kind: GeneratedContent.Kind { get }

## Discussion

This property provides access to the content in a strongly-typed enum representation, preserving the hierarchical structure of the data and the generation IDs.

## See Also

### Accessing instance properties

`var isComplete: Bool`

A Boolean that indicates whether the generated content is completed.

Beta

`var jsonString: String`

Returns a JSON string representation of the generated content.

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

Learn more about using Apple's beta software

---

# https://developer.apple.com/documentation/foundationmodels/generatedcontent/iscomplete

- Foundation Models
- GeneratedContent
- isComplete Beta

Instance Property

# isComplete

A Boolean that indicates whether the generated content is completed.

var isComplete: Bool { get }

## See Also

### Accessing instance properties

`var kind: GeneratedContent.Kind`

The kind representation of this generated content.

Beta

`var jsonString: String`

Returns a JSON string representation of the generated content.

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

Learn more about using Apple's beta software

---

# https://developer.apple.com/documentation/foundationmodels/generatedcontent/jsonstring

- Foundation Models
- GeneratedContent
- jsonString Beta

Instance Property

# jsonString

Returns a JSON string representation of the generated content.

var jsonString: String { get }

## Examples

// Object with properties
let content = GeneratedContent(properties: [\
"name": "Johnny Appleseed",\
"age": 30,\
])
print(content.jsonString)
// Output: {"name": "Johnny Appleseed", "age": 30}

## See Also

### Accessing instance properties

`var kind: GeneratedContent.Kind`

The kind representation of this generated content.

Beta

`var isComplete: Bool`

A Boolean that indicates whether the generated content is completed.

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

Learn more about using Apple's beta software

---

# https://developer.apple.com/documentation/foundationmodels/generatedcontent/debugdescription

- Foundation Models
- GeneratedContent
- debugDescription Beta

Instance Property

# debugDescription

A string representation for the debug description.

var debugDescription: String { get }

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

Learn more about using Apple's beta software

---

# https://developer.apple.com/documentation/foundationmodels/generatedcontent/value(_:)

#app-main)

- Foundation Models
- GeneratedContent
- value(\_:) Beta

Instance Method

# value(\_:)

Reads a top level, concrete partially generable type.

---

# https://developer.apple.com/documentation/foundationmodels/generatedcontent/value(_:forproperty:)

#app-main)

- Foundation Models
- GeneratedContent
- value(\_:forProperty:) Beta

Instance Method

# value(\_:forProperty:)

Reads a concrete generable type from named property.

\_ type: Value.Type = Value.self,
forProperty property: String

Show all declarations

## See Also

### Reads a value from the concrete type

Reads a top level, concrete partially generable type.

Beta

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

Learn more about using Apple's beta software

---

# https://developer.apple.com/documentation/foundationmodels/generatedcontent/generatedcontent

- Foundation Models
- GeneratedContent
- generatedContent Beta

Instance Property

# generatedContent

A representation of this instance.

var generatedContent: GeneratedContent { get }

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

Learn more about using Apple's beta software

---

# https://developer.apple.com/documentation/foundationmodels/generatedcontent/id

- Foundation Models
- GeneratedContent
- id Beta

Instance Property

# id

A unique ID used for the duration of a generated response.

var id: GenerationID?

## Discussion

A `LanguageModelSession` produces instances of `GeneratedContent` that have a non-nil `id`. When you stream a response, the `id` is the same for all partial generations in the response stream.

Instances of `GeneratedContent` that you produce manually with initializers have a nil `id` because the framework didn’t create them as part of a generation.

Beta Software

This documentation contains preliminary information about an API or technology in development. This information is subject to change, and software implemented according to this documentation should be tested with final operating system software.

Learn more about using Apple's beta software

---

# https://developer.apple.com/documentation/foundationmodels/convertiblefromgeneratedcontent

- Foundation Models
- ConvertibleFromGeneratedContent Beta

Protocol

# ConvertibleFromGeneratedContent

A type that can be initialized from generated content.

protocol ConvertibleFromGeneratedContent : SendableMetatype

## Topics

### Creating a convertable

`init(GeneratedContent) throws`

Creates an instance with the content.

**Required**

## Relationships

### Inherits From

- `SendableMetatype`

### Inherited By

- `Generable`

### Conforming Types

- `GeneratedContent`
