<p align="center">
  Nim bindings for Cisco's Open Source H.264 Codec library<br>
</p>

<p align="center">
  <code>nimble install openh264</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/openh264-nim">API reference</a><br>
  <img src="https://github.com/openpeeps/openh264-nim/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/openh264-nim/workflows/docs/badge.svg" alt="Github Actions">
</p>

## Key Features
- Open Source H.264 Codec by Cisco Systems
- Support for both encoding and decoding H.264 video
- Low-level bindings for direct access to the OpenH264 C API
- High-level Nim wrapper for easier integration into Nim projects
- Cross-platform support (Windows, Linux, macOS (arm64, x86_64), Android, iOS)
- See [OpenH264 - Encoder Features](https://github.com/cisco/openh264#encoder-features)
- See [OpenH264 - Decoder Features](https://github.com/cisco/openh264#decoder-features)

## Installation

### 1. Install the native OpenH264 library

macOS (Homebrew):

```sh
brew install openh264
```

Ubuntu / Debian:

```sh
sudo apt install libopenh264-dev
```

Fedora:

```sh
sudo dnf install openh264-devel
```

Windows (vcpkg):

```sh
vcpkg install openh264
```

From source, follow the build instructions in the
[Cisco OpenH264 repository](https://github.com/cisco/openh264).

### 2. Install the Nim package

```sh
nimble install openh264
```

Requires Nim >= 2.2.0.

If the compiler cannot find the headers or the library on your system,
pass the locations explicitly:

```sh
nim c -r --passC:"-I/usr/local/include" --passL:"-L/usr/local/lib -lopenh264" examples/version.nim
```

## Examples

Every snippet below is a complete, runnable program. The same sources
also live in the `examples/` directory, so you can run them directly:

```sh
nim c -r examples/version.nim
nim c -r examples/encode.nim     # writes output.264 (play with: ffplay -framerate 30 output.264)
nim c -r examples/roundtrip.nim
nim c -r examples/decode.nim     # reads output.264, run encode first
nim c -r examples/decode_pooled.nim  # decode into a reused buffer pool
```

### 1. Print the linked version (`examples/version.nim`)

```nim
import openh264

echo "OpenH264 version: ", codecVersionString()

let cap = decoderCapability()
echo "Decoder max bitrate (bps): ", cap.iMaxBr
echo "Decoder max FS: ", cap.iMaxFs
```

### 2. Encode synthetic frames to a file (`examples/encode.nim`)

```nim
import std/os
import openh264

const
  Width = 320
  Height = 240
  Bitrate = 500_000
  Fps = 30.0
  Frames = 60
  OutPath = "output.264"

proc makeYuv(width, height, frameIdx: int): seq[uint8] =
  let
    ySize = width * height
    uvSize = (width div 2) * (height div 2)
  result = newSeq[uint8](ySize + 2 * uvSize)
  for y in 0 ..< height:
    for x in 0 ..< width:
      result[y * width + x] = uint8((x + y + frameIdx * 3) mod 256)
  for i in 0 ..< uvSize:
    result[ySize + i] = uint8((128 + frameIdx) mod 256)
    result[ySize + uvSize + i] = uint8((64 + frameIdx * 2) mod 256)

proc toSourcePicture(data: var seq[uint8]; width, height: int): SSourcePicture =
  result.iColorFormat = cint(videoFormatI420)
  result.iPicWidth = cint(width)
  result.iPicHeight = cint(height)
  result.iStride[0] = cint(width)
  result.iStride[1] = cint(width div 2)
  result.iStride[2] = cint(width div 2)
  result.pData[0] = addr data[0]
  result.pData[1] = addr data[width * height]
  result.pData[2] = addr data[width * height + (width div 2) * (height div 2)]

proc collectNals(bsInfo: SFrameBSInfo): seq[uint8] =
  for layerIdx in 0 ..< bsInfo.iLayerNum:
    let layer = bsInfo.sLayerInfo[layerIdx]
    var offset = 0
    for nalIdx in 0 ..< layer.iNalCount:
      let nalLen = cast[ptr UncheckedArray[cint]](layer.pNalLengthInByte)[nalIdx]
      for b in 0 ..< nalLen:
        result.add(cast[ptr UncheckedArray[uint8]](layer.pBsBuf)[offset + b])
      offset += nalLen

proc main() =
  let enc = newEncoder()
  defer: enc.close()
  enc.initialize(Width, Height, Bitrate, Fps)
  enc.forceIntraFrame(true) # start with an IDR frame

  let outFile = open(OutPath, fmWrite)
  defer: outFile.close()

  var totalBytes = 0
  for i in 0 ..< Frames:
    var yuv = makeYuv(Width, Height, i)
    var pic = toSourcePicture(yuv, Width, Height)
    let bsInfo = enc.encodeFrame(pic)
    if bsInfo.eFrameType == cint(videoFrameTypeSkip):
      echo "frame ", i, ": skipped"
      continue
    let nalData = collectNals(bsInfo)
    if nalData.len > 0:
      discard outFile.writeBytes(nalData, 0, nalData.len)
      totalBytes += nalData.len
    echo "frame ", i, ": ", nalData.len, " bytes"

  let stats = enc.getStatistics()
  outFile.flushFile()
  echo "wrote ", totalBytes, " bytes to ", OutPath,
    " (", getFileSize(OutPath), " bytes on disk)"
  echo "average QP: ", stats.uiAverageFrameQP

main()
```

### 3. Encode and decode in memory (`examples/roundtrip.nim`)

```nim
import openh264

const
  Width = 320
  Height = 240
  Bitrate = 500_000
  Fps = 30.0
  Frames = 30

proc makeYuv(width, height, frameIdx: int): seq[uint8] =
  let
    ySize = width * height
    uvSize = (width div 2) * (height div 2)
  result = newSeq[uint8](ySize + 2 * uvSize)
  for y in 0 ..< height:
    for x in 0 ..< width:
      result[y * width + x] = uint8((x + y + frameIdx * 3) mod 256)
  for i in 0 ..< uvSize:
    result[ySize + i] = uint8((128 + frameIdx) mod 256)
    result[ySize + uvSize + i] = uint8((64 + frameIdx * 2) mod 256)

proc toSourcePicture(data: var seq[uint8]; width, height: int): SSourcePicture =
  result.iColorFormat = cint(videoFormatI420)
  result.iPicWidth = cint(width)
  result.iPicHeight = cint(height)
  result.iStride[0] = cint(width)
  result.iStride[1] = cint(width div 2)
  result.iStride[2] = cint(width div 2)
  result.pData[0] = addr data[0]
  result.pData[1] = addr data[width * height]
  result.pData[2] = addr data[width * height + (width div 2) * (height div 2)]

proc collectNals(bsInfo: SFrameBSInfo): seq[uint8] =
  for layerIdx in 0 ..< bsInfo.iLayerNum:
    let layer = bsInfo.sLayerInfo[layerIdx]
    var offset = 0
    for nalIdx in 0 ..< layer.iNalCount:
      let nalLen = cast[ptr UncheckedArray[cint]](layer.pNalLengthInByte)[nalIdx]
      for b in 0 ..< nalLen:
        result.add(cast[ptr UncheckedArray[uint8]](layer.pBsBuf)[offset + b])
      offset += nalLen

proc main() =
  echo "OpenH264 version: ", codecVersionString()

  let enc = newEncoder()
  defer: enc.close()
  enc.initialize(Width, Height, Bitrate, Fps)

  let dec = newDecoder()
  defer: dec.close()
  dec.initialize()

  var decoded = 0
  for i in 0 ..< Frames:
    var yuv = makeYuv(Width, Height, i)
    var pic = toSourcePicture(yuv, Width, Height)
    if i == 0:
      enc.forceIntraFrame(true)
    let bsInfo = enc.encodeFrame(pic)
    if bsInfo.eFrameType == cint(videoFrameTypeSkip):
      echo "frame ", i, ": skipped by encoder"
      continue
    let nalData = collectNals(bsInfo)
    echo "frame ", i, ": encoded ", nalData.len, " bytes"
    if nalData.len > 0:
      let frame = dec.decodeFrame(nalData)
      if frame.hasOutput:
        inc decoded
        echo "  decoded: ", frame.width, "x", frame.height

  let flushed = dec.flushFrame()
  if flushed.hasOutput:
    inc decoded
    echo "flushed: ", flushed.width, "x", flushed.height

  echo "encoded ", Frames, " frames, decoded ", decoded, " frames"

main()
```

### 4. Decode a `.264` file (`examples/decode.nim`)

First create the input with `nim c -r examples/encode.nim`, then:

```nim
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
```

### 5. Decode into a reused buffer pool (`examples/decode_pooled.nim`)

`decodeFrame` hands out pointers to decoder-internal picture buffers, which
the decoder recycles on every call. Copy each picture out immediately into a
buffer checked out from a small fixed pool (`copyToPackedI420` honors the
decoder row strides for you), and decode-side memory stays flat no matter
how many frames pass through.

```nim
import openh264

const
  Width = 320
  Height = 240
  Bitrate = 500_000
  Fps = 30.0
  Frames = 30
  PoolSize = 2

proc makeYuv(width, height, frameIdx: int): seq[uint8] =
  let
    ySize = width * height
    uvSize = (width div 2) * (height div 2)
  result = newSeq[uint8](ySize + 2 * uvSize)
  for y in 0 ..< height:
    for x in 0 ..< width:
      result[y * width + x] = uint8((x + y + frameIdx * 3) mod 256)
  for i in 0 ..< uvSize:
    result[ySize + i] = uint8((128 + frameIdx) mod 256)
    result[ySize + uvSize + i] = uint8((64 + frameIdx * 2) mod 256)

proc toSourcePicture(data: var seq[uint8]; width, height: int): SSourcePicture =
  result.iColorFormat = cint(videoFormatI420)
  result.iPicWidth = cint(width)
  result.iPicHeight = cint(height)
  result.iStride[0] = cint(width)
  result.iStride[1] = cint(width div 2)
  result.iStride[2] = cint(width div 2)
  result.pData[0] = addr data[0]
  result.pData[1] = addr data[width * height]
  result.pData[2] = addr data[width * height + (width div 2) * (height div 2)]

proc collectNals(bsInfo: SFrameBSInfo): seq[uint8] =
  for layerIdx in 0 ..< bsInfo.iLayerNum:
    let layer = bsInfo.sLayerInfo[layerIdx]
    var offset = 0
    for nalIdx in 0 ..< layer.iNalCount:
      let nalLen = cast[ptr UncheckedArray[cint]](layer.pNalLengthInByte)[nalIdx]
      for b in 0 ..< nalLen:
        result.add(cast[ptr UncheckedArray[uint8]](layer.pBsBuf)[offset + b])
      offset += nalLen

type
  FramePool = object
    bufs: seq[seq[uint8]]
    next: int

proc newFramePool(slots, width, height: int): FramePool =
  ## Allocate the pool once, up front. No decoding-time allocation follows.
  result.bufs = newSeq[seq[uint8]](slots)
  for i in 0 ..< slots:
    result.bufs[i] = newSeq[uint8](i420FrameSize(width, height))

proc checkout(pool: var FramePool): int =
  ## Hand out the next pooled slot, round robin.
  result = pool.next
  pool.next = (pool.next + 1) mod pool.bufs.len

proc yChecksum(buf: seq[uint8]; width, height: int): int =
  for i in 0 ..< width * height:
    result += int(buf[i])

proc main() =
  echo "OpenH264 version: ", codecVersionString()

  let enc = newEncoder()
  defer: enc.close()
  enc.initialize(Width, Height, Bitrate, Fps)

  let dec = newDecoder()
  defer: dec.close()
  dec.initialize()

  var pool = newFramePool(PoolSize, Width, Height)
  echo "pool: ", PoolSize, " buffers x ", i420FrameSize(Width, Height), " bytes"

  var
    decoded = 0
    seenAddrs: seq[string] = @[]

  for i in 0 ..< Frames:
    var yuv = makeYuv(Width, Height, i)
    var pic = toSourcePicture(yuv, Width, Height)
    if i == 0:
      enc.forceIntraFrame(true)
    let bsInfo = enc.encodeFrame(pic)
    if bsInfo.eFrameType == cint(videoFrameTypeSkip):
      continue
    let nalData = collectNals(bsInfo)
    if nalData.len == 0:
      continue
    let frame = dec.decodeFrame(nalData)
    if not frame.hasOutput:
      continue
    # Copy out immediately: the decoder recycles frame.planes on the
    # next call, so the pooled copy is the only stable storage.
    let slot = pool.checkout()
    copyToPackedI420(frame, pool.bufs[slot])
    let bufAddr = repr(cast[pointer](addr pool.bufs[slot][0]))
    if bufAddr notin seenAddrs:
      seenAddrs.add(bufAddr)
    inc decoded
    echo "frame ", i, ": copied to pool slot ", slot,
      " addr=", bufAddr,
      " ySum=", yChecksum(pool.bufs[slot], frame.width, frame.height),
      " decoderBuf=", repr(cast[pointer](frame.planes[0]))

  let flushed = dec.flushFrame()
  if flushed.hasOutput:
    let slot = pool.checkout()
    copyToPackedI420(flushed, pool.bufs[slot])
    inc decoded
    echo "flushed: copied to pool slot ", slot

  echo "decoded ", decoded, " pictures using ", seenAddrs.len,
    " distinct pooled buffers (pool size ", PoolSize, ")"

main()
```

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/openh264-nim/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/openh264-nim/fork)

### 🎩 License
MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright OpenPeeps and Contributors. All rights reserved.
