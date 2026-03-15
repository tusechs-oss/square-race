# TODO: @tool is required for static initialization in editor, static variables are not initialized if imported from an @tool script; remove @tool if fixed
@tool
extends Object

## Encoding tables based on EAN-13 specification.
## Array[Array[int]]
const _ENCODING_GROUPS: Array[Array] = [
    [0, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 1, 1],
    [0, 0, 1, 1, 0, 1],
    [0, 0, 1, 1, 1, 0],
    [0, 1, 0, 0, 1, 1],
    [0, 1, 1, 0, 0, 1],
    [0, 1, 1, 1, 0, 0],
    [0, 1, 0, 1, 0, 1],
    [0, 1, 0, 1, 1, 0],
    [0, 1, 1, 0, 1, 0]
]

## Encoding table for L-code, G-code, and R-code.
## Array[Array[Array[int]]]
const _ENCODING_TABLE: Array[Array] = [
    # L-code
    [
        [0, 0, 0, 1, 1, 0, 1],
        [0, 0, 1, 1, 0, 0, 1],
        [0, 0, 1, 0, 0, 1, 1],
        [0, 1, 1, 1, 1, 0, 1],
        [0, 1, 0, 0, 0, 1, 1],
        [0, 1, 1, 0, 0, 0, 1],
        [0, 1, 0, 1, 1, 1, 1],
        [0, 1, 1, 1, 0, 1, 1],
        [0, 1, 1, 0, 1, 1, 1],
        [0, 0, 0, 1, 0, 1, 1]
    ],
    # G-code
    [
        [0, 1, 0, 0, 1, 1, 1],
        [0, 1, 1, 0, 0, 1, 1],
        [0, 0, 1, 1, 0, 1, 1],
        [0, 1, 0, 0, 0, 0, 1],
        [0, 0, 1, 1, 1, 0, 1],
        [0, 1, 1, 1, 0, 0, 1],
        [0, 0, 0, 0, 1, 0, 1],
        [0, 0, 1, 0, 0, 0, 1],
        [0, 0, 0, 1, 0, 0, 1],
        [0, 0, 1, 0, 1, 1, 1]
    ],
    # R-code
    [
        [1, 1, 1, 0, 0, 1, 0],
        [1, 1, 0, 0, 1, 1, 0],
        [1, 1, 0, 1, 1, 0, 0],
        [1, 0, 0, 0, 0, 1, 0],
        [1, 0, 1, 1, 1, 0, 0],
        [1, 0, 0, 1, 1, 1, 0],
        [1, 0, 1, 0, 0, 0, 0],
        [1, 0, 0, 0, 1, 0, 0],
        [1, 0, 0, 1, 0, 0, 0],
        [1, 1, 1, 0, 1, 0, 0]
    ]
]

static var _number_rx: RegEx = RegEx.create_from_string("[^\\d]*")

## Get the EAN-13 number including the check digit.
## `number` must be a string of 12 digits; all non-digit characters are removed automatically.
static func ean13(number: String) -> String:
    number = _number_rx.sub(number, "", true)
    if number.length() != 12:
        push_error("[EAN13] Input number must be 12 digits long (excluding hyphens and spaces).")
        return ""
    return ean13_int(int(number))

## Get the EAN-13 number including the check digit from an integer.
static func ean13_int(number: int) -> String:
    if number >= 1_000_000_000_000:
        push_error("[EAN-13] Number too large for EAN-13 generation.")
        return ""
    return str(10 * number + checksum(number)).pad_zeros(13)

## Calculates the checksum digit for the provided number represented as an integer.
static func checksum(number: int) -> int:
    if number >= 1_000_000_000_000:
        push_error("[EAN-13] Number too large for EAN-13 checksum calculation.")
        return -1

    var sum: int = 0
    var temp_number: int = number

    for idx: int in range(1, 13):
        var digit: int = temp_number % 10

        if idx % 2 == 1:
            sum += digit * 3
        else:
            sum += digit
        
        temp_number /= 10
    
    return (10 - (sum % 10)) % 10

## Validate the given EAN-13 number.
static func validate(number: String) -> bool:
    if number.length() != 13:
        return false

    var number_part: String = number.substr(0, 12)
    var checksum_digit: int = int(number[12])
    return checksum(int(number_part)) == checksum_digit

## Validates the provided EAN-13 code represented as an integer.
static func validate_int(number: int) -> bool:
    var number_part: int = number / 10
    var checksum_digit: int = number % 10
    return checksum(number_part) == checksum_digit

## Encode the given EAN-13 number and return the encoded data as a byte array. The returned array has a size of 95 bytes; each byte represents a module (`0` for light, `1` for dark).
static func encode(ean13: String) -> PackedByteArray:
    if ean13.length() != 13:
        push_error("[EAN-13] EAN-13 code must be 13 digits long.")
        return PackedByteArray()

    var bin_data: PackedByteArray = PackedByteArray()
    bin_data.resize(95)

    # start guard
    bin_data[0] = 1
    bin_data[1] = 0
    bin_data[2] = 1

    # left side
    var encoding_group: Array[int] = []
    encoding_group.assign(_ENCODING_GROUPS[int(ean13[0])])
    for idx: int in range(6):
        var digit: int = int(ean13[idx + 1])
        var encoding_type: int = encoding_group[idx]
        var encoding_pattern: Array[int] = []
        encoding_pattern.assign(_ENCODING_TABLE[encoding_type][digit])
        for bit_idx: int in range(7):
            bin_data[3 + idx * 7 + bit_idx] = encoding_pattern[bit_idx]
    
    # center guard
    bin_data[45] = 0
    bin_data[46] = 1
    bin_data[47] = 0
    bin_data[48] = 1
    bin_data[49] = 0

    # right side
    for idx: int in range(6):
        var digit: int = int(ean13[idx + 7])
        var encoding_pattern: Array[int] = []
        encoding_pattern.assign(_ENCODING_TABLE[2][digit])
        for bit_idx: int in range(7):
            bin_data[50 + idx * 7 + bit_idx] = encoding_pattern[bit_idx]
    
    # end guard
    bin_data[92] = 1
    bin_data[93] = 0
    bin_data[94] = 1

    return bin_data
