## Decode a raw Annex-B .264 file produced by examples/encode.nim.
## Run with:
##   nim c -r examples/encode.nim   # produces output.264
##   nim c -r examples/decode.nim

import std/os
import openh264

const InPath = "output.264"

proc findStart(data: seq[uint8]; fromPos: int): int =
  ## Return the index of the next Annex-B start code at or after fromPos,
  ## or -1 when there is none.
  var i = fromPos
  while i + 2 < data.len:
    if data[i] == 0 and data[i + 1] == 0:
      if data[i + 2] == 1:
        return i
      if i + 3 < data.len and data[i + 2] == 0 and data[i + 3] == 1:
        return i
    inc i
  return -1

proc splitAnnexB(data: seq[uint8]): seq[seq[uint8]] =
  var pos = findStart(data, 0)
  if pos < 0:
    return @[data]
  while pos >= 0:
    let next = findStart(data, pos + 3)
    if next < 0:
      result.add(data[pos .. ^1])
      break
    result.add(data[pos ..< next])
    pos = next

proc main() =
  if not fileExists(InPath):
    quit "input file not found: " & InPath & " (run `nim c -r examples/encode.nim` first)"

  let blob = readFile(InPath)
  var raw = newSeq[uint8](blob.len)
  for i, ch in blob:
    raw[i] = uint8(ch)
  echo "read ", raw.len, " bytes from ", InPath

  let units = splitAnnexB(raw)
  echo "found ", units.len, " NAL units"

  let dec = newDecoder()
  defer: dec.close()
  dec.initialize()

  var decoded = 0
  for idx, unit in units:
    if unit.len == 0:
      continue
    let frame = dec.decodeFrame(unit)
    if frame.hasOutput:
      inc decoded
      echo "NAL ", idx, " (", unit.len, " bytes): ",
        frame.width, "x", frame.height
    else:
      echo "NAL ", idx, " (", unit.len, " bytes): no picture yet"

  let flushed = dec.flushFrame()
  if flushed.hasOutput:
    inc decoded
    echo "flushed: ", flushed.width, "x", flushed.height

  echo "decoded ", decoded, " pictures from ", units.len, " NAL units"

main()
