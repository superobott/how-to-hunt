extends RefCounted
## Bounded snapshot datagrams. Incomplete snapshots never replace displayed state.
const PROTOCOL := "how-to-hunt-v3"
const CHUNK_BYTES := 1000
const MAX_CHUNKS := 64
const MAX_DECODED_BYTES := 1048576
var sequence := -1
var parts: Dictionary = {}
var expected := 0
var completed := false

static func encode(snapshot: Dictionary) -> Array[PackedByteArray]:
	var raw := var_to_bytes(snapshot)
	var result: Array[PackedByteArray] = []
	if raw.size() > MAX_DECODED_BYTES:
		return result
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	if packed.size() > CHUNK_BYTES * MAX_CHUNKS:
		return result
	for offset in range(0, packed.size(), CHUNK_BYTES):
		result.append(packed.slice(offset, mini(offset + CHUNK_BYTES, packed.size())))
	return result

func accept(number: int, index: int, count: int, payload: PackedByteArray) -> Dictionary:
	if number < sequence or count < 1 or count > MAX_CHUNKS or index < 0 or index >= count or payload.is_empty() or payload.size() > CHUNK_BYTES:
		return {}
	if number > sequence:
		sequence = number
		expected = count
		parts.clear()
		completed = false
	if completed or count != expected or parts.has(index):
		return {}
	parts[index] = payload
	if parts.size() != expected:
		return {}
	var packed := PackedByteArray()
	for part in expected:
		packed.append_array(parts[part])
	parts.clear()
	completed = true
	var raw := packed.decompress_dynamic(MAX_DECODED_BYTES, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return {}
	var decoded: Variant = bytes_to_var(raw)
	return decoded if decoded is Dictionary else {}
