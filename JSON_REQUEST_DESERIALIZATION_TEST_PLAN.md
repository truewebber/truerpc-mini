# JSON Request Deserialization — Test Plan

This document defines **exhaustive test scenarios** for turning a gRPC request JSON body
into a `SwiftProtoReflect.DynamicMessage` in TrueRPC-mini.

The plan describes **target behavior** — how every valid protobuf JSON input *must* be
parsed according to the [proto3 JSON mapping spec](https://protobuf.dev/programming-guides/proto3/#json).
Where the current implementation does not yet satisfy a scenario, the test must be written
first (red), and the implementation updated to make it pass (green).

---

## 1. Scope

### 1.1 System under test (SUT)

Two levels of testing:

| Level | SUT | Purpose |
|-------|-----|---------|
| **Unit — Normalizer** | `GrpcRequestProtobufJSONNormalizer.normalizeMessageObject` | Verify that protobuf-JSON forms (WKT strings, `null`, wrapper unwrapping, etc.) are rewritten into the object shapes `JSONDeserializer` accepts. Input/output: `[String: Any]`. |
| **Unit — Full chain** | `GrpcSwiftDynamicClient.parseJSON(_:using:typeRegistry:)` | End-to-end: UTF-8 JSON string → `DynamicMessage`. Covers `JSONSerialization` → Normalizer → `JSONDeserializer`. |
| **Integration** | Real `.proto` files parsed via `FileSystemProtoRepository` + full chain | Catches `json_name`, `isMap`/`mapEntryInfo`, import resolution, and registry gaps. |

### 1.2 Goals

- **Positive cases**: given any valid protobuf-JSON input + schema, the resulting `DynamicMessage`
  must match the **entire expected message** (full structural equality).
- **Negative cases**: invalid JSON, type mismatches, and spec violations must surface as a
  **deterministic error** (`GrpcClientError.invalidJSON` or a specific library error), never
  silent partial data.

---

## 2. Full-message comparison harness

### 2.1 `assertDynamicMessagesEqual`

Implement a **test-only** helper:

1. Assert `expected.descriptor.fullName == actual.descriptor.fullName`.
2. Walk `descriptor.allFields()` in field-number order.
3. For each field, compare values recursively:
   - `DynamicMessage` → recurse.
   - `[DynamicMessage]` (repeated message) → element-wise recurse.
   - `[AnyHashable: Any]` (map) → compare as unordered key-value sets; recurse for message values.
   - Scalars → exact Swift type match (e.g. `Int32`, `Int64`, `String`, `Bool`, `Data`).
4. **Missing optional field** vs **default value** rule: treat both as equal (proto3 has no
   field presence for scalars; messages default to absent).
5. Print clear diff on failure: field path, expected value, actual value.

### 2.2 Golden expected messages

Build expected `DynamicMessage` with `MessageFactory` + `set(_:forField:)`, **not** by
deserializing JSON — that would test the SUT with itself.

---

## 3. Test fixtures

### 3.1 Schema sources

- **Synthetic descriptors** (`FileDescriptor`, `MessageDescriptor`, `FieldDescriptor`,
  `MapEntryInfo`, `EnumDescriptor`) — fast, deterministic, used in unit tests.
- **Real `.proto` files** — parsed with `SwiftProtoParser` via `FileSystemProtoRepository`,
  used in integration tests. Required to validate `json_name`, `isMap`/`mapEntryInfo`,
  transitive imports, and `TypeRegistry` completeness.

### 3.2 TypeRegistry

Every scenario must define a `TypeRegistry` that registers:

- All message types reachable from the root request type (nested, map entries, WKT).
- Built-in pool types via `DescriptorPool(includeBuiltinDescriptors: true)`.

---

## 4. Scenario matrix — scalars (proto3, singular)

Fixture: message `Scalars` with one field per scalar type.

| # | Field type | Valid JSON inputs | Invalid / edge |
|---|------------|-------------------|----------------|
| S1 | `double` | number `1.25`; strings `"1.25"`, `"NaN"`, `"Infinity"`, `"-Infinity"` | bool `true`; string `"abc"` |
| S2 | `float` | number `1.5`; string `"1.5"` | overflow `1e+39`; string `"abc"` |
| S3 | `int32` | number `42`; string `"42"` | out of range `2147483648`; float `1.5` |
| S4 | `int64` | number `100`; **string** `"9223372036854775807"` (max int64, exceeds JS precision) | out of range; float |
| S5 | `uint32` | number `42`; string `"42"` | negative `-1` |
| S6 | `uint64` | number `100`; **string** `"18446744073709551615"` (max uint64) | negative `-1` |
| S7 | `sint32` | number `42`; number `-42` | out of range |
| S8 | `sint64` | number `100`; string `"-100"` | out of range |
| S9 | `fixed32` / `fixed64` | number | out of range for fixed32 |
| S10 | `sfixed32` / `sfixed64` | number | out of range for sfixed32 |
| S11 | `bool` | `true` / `false` | string `"true"`; number `1` |
| S12 | `string` | `"hello"`; `""` (empty); Unicode `"Привет 🌍"` | number `42`; bool `true` |
| S13 | `bytes` | base64 `"SGVsbG8="` | invalid base64 `"!!!"`; number |

**Assertion**: full message equals expected for each valid row; error for each invalid row.

---

## 5. Scenario matrix — enums

| # | Case | JSON | Expect |
|---|------|------|--------|
| E1 | Numeric value (known) | `0`, `1` | match (enum stored as Int32) |
| E2 | String name | `"ACTIVE"`, `"INACTIVE"` | match — normalizer must convert string name to numeric value using `EnumDescriptor` |
| E3 | Unknown numeric value (proto3 open enums) | `999` | stored as-is (proto3 preserves unknown enum values) |
| E4 | Unknown string name | `"BOGUS"` | error |
| E5 | `null` | `null` | default value `0` |

---

## 6. Scenario matrix — `json_name` / field name resolution

The protobuf JSON spec uses `json_name` (camelCase by default) as the canonical key.
Implementations *should* also accept the proto field name. The normalizer and deserializer
must resolve **both** forms.

| # | Case | JSON key | Proto field name | `json_name` | Expect |
|---|------|----------|------------------|-------------|--------|
| JN1 | camelCase key (canonical) | `"createdAt"` | `created_at` | `createdAt` | field matched, full equality |
| JN2 | snake_case key (original name) | `"created_at"` | `created_at` | `createdAt` | field matched, full equality |
| JN3 | Wrong case (neither) | `"CreatedAt"` | `created_at` | `createdAt` | field ignored (unknown field, `ignoreUnknownFields: true`) |
| JN4 | Custom `json_name` in proto | `"myCustomName"` | `original` | `myCustomName` | field matched |
| JN5 | Nested message fields with `json_name` | camelCase keys at all levels | — | — | full equality at all nesting levels |
| JN6 | Map value message fields with `json_name` | camelCase inside map value object | — | — | full equality |

---

## 7. Scenario matrix — `null` values

Per proto3 JSON spec, `null` represents the default value for the field type.

| # | Case | JSON | Expect |
|---|------|------|--------|
| NL1 | `null` for scalar string | `{"name": null}` | `name` = `""` (default) |
| NL2 | `null` for scalar int32 | `{"count": null}` | `count` = `0` |
| NL3 | `null` for scalar bool | `{"flag": null}` | `flag` = `false` |
| NL4 | `null` for message field | `{"sub": null}` | field absent |
| NL5 | `null` for repeated field | `{"tags": null}` | empty list `[]` |
| NL6 | `null` for map field | `{"labels": null}` | empty map `{}` |
| NL7 | `null` for Timestamp | `{"ts": null}` | field absent (normalizer must not crash on `NSNull`) |
| NL8 | `null` for Duration | `{"dur": null}` | field absent |
| NL9 | `null` for enum | `{"status": null}` | default value `0` |
| NL10 | `null` for bytes | `{"data": null}` | empty `Data()` |
| NL11 | `null` inside map value | `{"m": {"k": null}}` | value = default for value type |
| NL12 | `null` inside repeated | `[null, "a"]` | error or default — document chosen rule |

---

## 8. Scenario matrix — nested messages

| # | Case | JSON | Expect |
|---|------|------|--------|
| N1 | Single nested, all fields set | `{"sub": {"a": 1, "b": "x"}}` | full equality |
| N2 | Nested message omitted | key absent | field absent in result |
| N3 | Nested message empty object | `{"sub": {}}` | sub-message present with all defaults |
| N4 | Deep nesting (3+ levels) | A → B → C → D | full equality at all levels |
| N5 | Nested with its own nested message | outer + inner + innermost | full equality (normalizer recursion) |

---

## 9. Scenario matrix — `repeated`

| # | Case | JSON | Expect |
|---|------|------|--------|
| R1 | Repeated scalar, empty | `[]` | empty list |
| R2 | Repeated scalar, single element | `[42]` | list with one element |
| R3 | Repeated scalar, multiple elements | `[1, 2, 3]` | full equality |
| R4 | Repeated message | `[{"a": 1}, {"a": 2}]` | full equality per element |
| R5 | Repeated enum | `[0, 1, "ACTIVE"]` | normalized to numeric values |
| R6 | Empty array vs omitted field | `{"tags": []}` vs `{}` | both produce empty list (equivalent in proto3) |
| R7 | Wrong JSON type (object for repeated) | `{"tags": {}}` | error |
| R8 | `null` element inside repeated scalar | `[1, null, 3]` | error or default — document rule |

---

## 10. Scenario matrix — `map`

Protobuf JSON encodes maps as JSON objects. All keys become strings.

Fixture: message `Maps` with one field per map variant.

| # | Map type | Example JSON | Expect |
|---|----------|--------------|--------|
| M1 | `map<string, string>` | `{"a": "x", "b": "y"}` | full equality |
| M2 | `map<string, int32>` | `{"k": 42}` | full equality |
| M3 | `map<int32, string>` | `{"1": "a", "-2": "b"}` (stringified keys) | keys deserialized as Int32 |
| M4 | `map<int64, string>` | `{"9223372036854775807": "big"}` | key deserialized as Int64 |
| M5 | `map<uint32, string>` | `{"42": "v"}` | key deserialized as UInt32 |
| M6 | `map<bool, string>` | `{"true": "a", "false": "b"}` | keys deserialized as Bool |
| M7 | `map<string, SubMessage>` | nested objects as values | full subtree equality |
| M8 | `map<string, Timestamp>` — string form | `{"k": "2024-01-01T00:00:00Z"}` | normalizer converts; full equality |
| M9 | `map<string, Timestamp>` — object form | `{"k": {"seconds": 100}}` | pass-through; full equality |
| M10 | `map<string, Duration>` — string form | `{"k": "1.5s"}` | normalizer converts; full equality |
| M11 | `map<string, Duration>` — object form | `{"k": {"seconds": 1, "nanos": 500000000}}` | pass-through; full equality |
| M12 | Empty map | `{}` | empty map |
| M13 | Invalid map value type | `{"k": true}` for `map<string, int32>` | error |
| M14 | Invalid stringified key | `{"abc": "v"}` for `map<int32, string>` | error |
| M15 | `map<string, EnumType>` | `{"k": 1}` and `{"k": "ACTIVE"}` | full equality |

---

## 11. Scenario matrix — well-known types (WKT)

### 11.1 `google.protobuf.Timestamp`

| # | Case | JSON | Expect |
|---|------|------|--------|
| TS1 | RFC 3339 string (UTC, no fractional) | `"2024-01-01T00:00:00Z"` | `{seconds: 1704067200, nanos: 0}` |
| TS2 | RFC 3339 string with fractional seconds | `"2024-01-01T00:00:00.123456789Z"` | `{seconds: …, nanos: 123456789}` |
| TS3 | RFC 3339 with timezone offset | `"2024-01-01T03:00:00+03:00"` | same as `2024-01-01T00:00:00Z` |
| TS4 | Epoch (zero value) | `"1970-01-01T00:00:00Z"` | `{seconds: 0, nanos: 0}` |
| TS5 | Before epoch | `"1969-12-31T23:59:59Z"` | `{seconds: -1, nanos: 0}` |
| TS6 | Object form (pass-through) | `{"seconds": 100, "nanos": 0}` | full equality without conversion |
| TS7 | Singular field | `{"created_at": "…"}` | full equality |
| TS8 | Repeated field | `["…", "…"]` | full equality per element |
| TS9 | Map value (string form) | covered by M8 | — |
| TS10 | Nested under custom message | `{"event": {"ts": "…"}}` | normalizer recurses into nested |
| TS11 | Mixed repeated (string + object) | `["2024-01-01T00:00:00Z", {"seconds": 100}]` | both normalized; full equality |
| TS12 | Empty string | `""` | error: `GrpcClientError.invalidJSON` |
| TS13 | Invalid date string | `"not-a-date"` | error |
| TS14 | `null` | `null` | field absent |

### 11.2 `google.protobuf.Duration`

| # | Case | JSON | Expect |
|---|------|------|--------|
| DUR1 | Positive integer seconds | `"10s"` | `{seconds: 10, nanos: 0}` |
| DUR2 | Positive fractional | `"1.5s"` | `{seconds: 1, nanos: 500000000}` |
| DUR3 | Zero | `"0s"` | `{seconds: 0, nanos: 0}` |
| DUR4 | Negative | `"-1.5s"` | `{seconds: -1, nanos: -500000000}` |
| DUR5 | Sub-nanosecond precision | `"0.000000001s"` | `{seconds: 0, nanos: 1}` |
| DUR6 | Object form (pass-through) | `{"seconds": 1, "nanos": 0}` | full equality |
| DUR7 | Singular / repeated / map value | same patterns as Timestamp | — |
| DUR8 | Mixed repeated (string + object) | `["1s", {"seconds": 2}]` | both forms handled |
| DUR9 | Missing 's' suffix | `"10"` | error |
| DUR10 | Empty string | `""` | error |
| DUR11 | Only 's' | `"s"` | error |
| DUR12 | Non-numeric | `"abcs"` | error |
| DUR13 | `null` | `null` | field absent |

### 11.3 `google.protobuf.Empty`

| # | Case | JSON | Expect |
|---|------|------|--------|
| EM1 | Empty object | `{}` | empty message |
| EM2 | Omitted field | key absent | field absent |
| EM3 | Object with unknown fields | `{"x": 1}` | ignored (with `ignoreUnknownFields`) |

### 11.4 `google.protobuf.Struct`

Per spec, `Struct` maps to a JSON object. Each value is a `google.protobuf.Value`.

| # | Case | JSON | Expect |
|---|------|------|--------|
| ST1 | Flat string values | `{"a": "x", "b": "y"}` | Struct with Value entries |
| ST2 | Mixed value types | `{"n": 1, "s": "x", "b": true, "nil": null}` | correct Value kinds |
| ST3 | Nested Struct (object in object) | `{"inner": {"k": "v"}}` | recursive Struct/Value |
| ST4 | With ListValue | `{"arr": [1, 2, 3]}` | Value.listValue |
| ST5 | Empty | `{}` | empty Struct |

### 11.5 `google.protobuf.Value`

| # | Case | JSON | Expect |
|---|------|------|--------|
| V1 | null | `null` | `Value.nullValue` |
| V2 | number | `3.14` | `Value.numberValue` |
| V3 | string | `"hello"` | `Value.stringValue` |
| V4 | bool | `true` | `Value.boolValue` |
| V5 | object | `{"k": "v"}` | `Value.structValue` |
| V6 | array | `[1, 2]` | `Value.listValue` |

### 11.6 `google.protobuf.ListValue`

| # | Case | JSON | Expect |
|---|------|------|--------|
| LV1 | Array of mixed values | `[1, "a", true, null]` | list of Value |
| LV2 | Empty array | `[]` | empty ListValue |
| LV3 | Nested arrays | `[[1, 2], [3]]` | nested ListValue inside Value |

### 11.7 Wrapper types (`google.protobuf.*Value`)

Per spec, wrappers serialize as the inner value directly (unwrapped).

| # | Wrapper type | JSON | Expect |
|---|-------------|------|--------|
| W1 | `StringValue` | `"hello"` / `null` | unwrapped string / field absent |
| W2 | `Int32Value` | `42` / `null` | unwrapped int32 / field absent |
| W3 | `Int64Value` | `"100"` / `null` | string-encoded int64 / field absent |
| W4 | `UInt32Value` | `42` / `null` | unwrapped uint32 / field absent |
| W5 | `UInt64Value` | `"100"` / `null` | string-encoded / field absent |
| W6 | `FloatValue` | `1.5` / `null` | unwrapped float / field absent |
| W7 | `DoubleValue` | `1.5` / `null` | unwrapped double / field absent |
| W8 | `BoolValue` | `true` / `null` | unwrapped bool / field absent |
| W9 | `BytesValue` | `"SGVsbG8="` / `null` | unwrapped bytes / field absent |

### 11.8 `google.protobuf.FieldMask`

| # | Case | JSON | Expect |
|---|------|------|--------|
| FM1 | Single path | `"foo"` | FieldMask with `paths: ["foo"]` |
| FM2 | Multiple paths (comma-separated camelCase) | `"fooBar,bazQux"` | paths converted to snake_case: `["foo_bar", "baz_qux"]` |
| FM3 | Empty string | `""` | empty FieldMask |

### 11.9 `google.protobuf.Any`

| # | Case | JSON | Expect |
|---|------|------|--------|
| ANY1 | Known type URL with value | `{"@type": "type.googleapis.com/pkg.Msg", "field": 1}` | Any with packed message |
| ANY2 | WKT inside Any (special encoding) | `{"@type": "…/google.protobuf.Duration", "value": "1s"}` | correct unpacking |
| ANY3 | Missing `@type` | `{"field": 1}` | error |
| ANY4 | Unknown type URL | `{"@type": "type.googleapis.com/unknown.Msg"}` | error (type not in registry) |

---

## 12. Scenario matrix — `oneof`

| # | Case | JSON | Expect |
|---|------|------|--------|
| O1 | Branch A set (scalar) | `{"str_val": "hello"}` | full equality; other branches unset |
| O2 | Branch B set (message) | `{"msg_val": {"x": 1}}` | full equality |
| O3 | Multiple branches in JSON | `{"str_val": "a", "msg_val": {}}` | error (violates spec) |
| O4 | No branch set | `{}` | all branches absent |
| O5 | `null` for oneof branch | `{"str_val": null}` | branch unset (same as absent) |
| O6 | Nested message inside oneof | `{"msg_val": {"inner": {"deep": 1}}}` | full equality, normalizer recurses |

---

## 13. Root JSON shape and transport

| # | Case | Expect |
|---|------|--------|
| T1 | Root is object `{}` | OK |
| T2 | Root is array `[]` | `GrpcClientError.invalidJSON` |
| T3 | Root is string `"hello"` | `GrpcClientError.invalidJSON` |
| T4 | Root is number `42` | `GrpcClientError.invalidJSON` |
| T5 | Root is `null` | `GrpcClientError.invalidJSON` |
| T6 | Root is `true` / `false` | `GrpcClientError.invalidJSON` |
| T7 | Invalid UTF-8 bytes | error (from `JSONSerialization`) |
| T8 | Malformed JSON `{invalid` | error |
| T9 | Empty string `""` | error |

---

## 14. Unknown fields

| # | Case | Expect |
|---|------|--------|
| U1 | Unknown field, `ignoreUnknownFields: true` | field ignored; message contains only known fields |
| U2 | Multiple unknown fields | all ignored |
| U3 | Unknown field with same name as nested type | ignored (not confused with type name) |

---

## 15. Default values (proto3 semantics)

Absent fields in JSON default to proto3 zero values. Explicitly set zero values must be
indistinguishable from absent fields in the resulting `DynamicMessage`.

| # | Case | JSON | Expect |
|---|------|------|--------|
| D1 | All fields absent | `{}` | message with all defaults |
| D2 | Scalar set to zero value explicitly | `{"count": 0}` | same as absent `count` |
| D3 | String set to empty explicitly | `{"name": ""}` | same as absent `name` |
| D4 | Bool set to false explicitly | `{"flag": false}` | same as absent `flag` |
| D5 | Repeated set to empty explicitly | `{"tags": []}` | same as absent `tags` |
| D6 | Map set to empty explicitly | `{"labels": {}}` | same as absent `labels` |

---

## 16. Negative / error catalog

For **each** field type, at least one negative scenario. Grouped by error class.

### 16.1 Type mismatches

| JSON value | Field type | Expect |
|------------|-----------|--------|
| `true` | `int32` | error |
| `"hello"` | `int32` | error (non-numeric string) |
| `42` | `string` | error |
| `{}` | `int32` (scalar) | error |
| `[]` | `string` (scalar) | error |
| `"hello"` | message field | error |
| `42` | message field | error |

### 16.2 Range / overflow

| JSON value | Field type | Expect |
|------------|-----------|--------|
| `2147483648` | `int32` | error (> INT32_MAX) |
| `-1` | `uint32` | error |
| `"99999999999999999999"` | `int64` | error (> INT64_MAX) |
| `1e+39` | `float` | error (overflow) |

### 16.3 WKT format errors

| JSON value | WKT type | Expect |
|------------|----------|--------|
| `""` | Timestamp | `GrpcClientError.invalidJSON` |
| `"not-a-date"` | Timestamp | `GrpcClientError.invalidJSON` |
| `""` | Duration | `GrpcClientError.invalidJSON` |
| `"10"` (no 's') | Duration | `GrpcClientError.invalidJSON` |
| `"abcs"` | Duration | `GrpcClientError.invalidJSON` |

### 16.4 Structural errors

| Case | Expect |
|------|--------|
| Map where value should be array | error |
| Array where value should be object | error |
| Duplicate JSON keys | last-value-wins or error — document rule |

---

## 17. Test suite layout

```
Tests/
  UnitTests/
    Data/
      Clients/
        GrpcRequestProtobufJSONNormalizerTests.swift   # normalizer in isolation
        RequestJSONDeserializationTests.swift           # full parseJSON chain
        DynamicMessageAssertionHelpers.swift            # assertDynamicMessagesEqual
  IntegrationTests/
    RequestJSONDeserializationIntegrationTests.swift    # real .proto + FileSystemProtoRepository
```

### 17.1 Normalizer-only tests

`GrpcRequestProtobufJSONNormalizerTests` tests the normalizer as a pure function:
- Input: `[String: Any]` + `MessageDescriptor` + `TypeRegistry`
- Output: `[String: Any]`
- Verifies rewriting without involving `JSONDeserializer`.
- Covers: WKT string→object, `null` pass-through, recursive descent, map value normalization.

### 17.2 Full-chain tests

`RequestJSONDeserializationTests` tests `parseJSON()`:
- Input: JSON `String` + `MessageDescriptor` + `TypeRegistry`
- Output: `DynamicMessage`
- Uses `assertDynamicMessagesEqual` for golden comparison.
- Covers: all scenario matrices (sections 4–16).

### 17.3 Integration tests

`RequestJSONDeserializationIntegrationTests`:
- Parses real `.proto` files with `FileSystemProtoRepository`.
- Builds `TypeRegistry` via `makeJSONTypeRegistry(for:)`.
- Verifies that `isMap`, `mapEntryInfo`, `json_name`, nested type registration, and WKT
  resolution work end-to-end.

---

## 18. Implementation phases

| Phase | Scope | Depends on |
|-------|-------|------------|
| **P0** | Harness: `assertDynamicMessagesEqual`, fixture helpers, registry builder | — |
| **P1** | Scalars (§4) + enums (§5) + `null` (§7) + defaults (§15) | P0 |
| **P2** | `json_name` resolution (§6) | P0 |
| **P3** | Nested messages (§8) + repeated (§9) | P0 |
| **P4** | Maps — all key/value types (§10) | P0 |
| **P5** | WKT Timestamp + Duration — all forms and positions (§11.1–11.2) | P0 |
| **P6** | WKT Empty (§11.3) + Struct/Value/ListValue (§11.4–11.6) | P0, may require normalizer changes |
| **P7** | Wrapper types (§11.7) + FieldMask (§11.8) + Any (§11.9) | P0, requires normalizer changes |
| **P8** | Oneof (§12) | P0 |
| **P9** | Root shape + negative catalog (§13, §16) | P0 |
| **P10** | Integration: real `.proto` files (§17.3) — covers `isMap`/`mapEntryInfo` from repository | P1–P9 |
| **P11** | Normalizer-only unit tests (§17.1) — retroactive isolation of normalizer logic | P5–P7 |

---

## 19. Known implementation gaps

Issues that tests will surface (write failing test first, then fix):

| Gap | Impact | Section |
|-----|--------|---------|
| `FileSystemProtoRepository.convertToFieldDescriptor` does not set `isMap` / `mapEntryInfo` | Maps not normalized when using real `.proto` descriptors | §10, P10 |
| Normalizer does not handle `null` (`NSNull`) — passes it through without conversion | May crash or produce wrong result for nullable WKT fields | §7 |
| Normalizer only handles Timestamp and Duration; no support for Struct, Value, wrappers, FieldMask | WKT §11.4–11.8 will fail | P6, P7 |
| Enum string name → numeric conversion not implemented in normalizer | E2 will fail | §5 |
| Wrapper type unwrapping not implemented | W1–W9 will fail | §11.7 |
| `json_name` matching depends on `FieldDescriptor.jsonName` being populated — verify repository sets it | JN1–JN6 may fail with real protos | §6, P10 |

---

## 20. Success criteria

- Every row in sections **4–16** is either implemented with **full-message assertion** or
  explicitly marked `XCTSkip("reason / link to issue")`.
- No test asserts only "one field" for multi-field fixtures — always full-message comparison.
- Normalizer-only tests (§17.1) cover every code path in `GrpcRequestProtobufJSONNormalizer`.
- Integration tests (§17.3) prove that real `.proto` parsing produces correct `isMap`,
  `mapEntryInfo`, `json_name`, and complete `TypeRegistry`.
- CI runs the full suite on macOS with deterministic results (no time-dependent assertions;
  fixed RFC 3339 strings and durations only).

---

## 21. Maintenance

Update this plan when:

- New WKT support is added to the normalizer.
- New error types are introduced.
- `parseJSON` signature or pipeline changes.
- `FileSystemProtoRepository` descriptor conversion is modified.

Last updated: 2026-03-28
