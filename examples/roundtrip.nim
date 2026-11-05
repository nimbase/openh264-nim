## Encode synthetic frames and decode them back in memory.
## Run with: nim c -r examples/roundtrip.nim

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
