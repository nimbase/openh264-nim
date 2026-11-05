## Encode synthetic I420 frames to a raw Annex-B .264 file.
## Run with: nim c -r examples/encode.nim
## Play the result with: ffplay -framerate 30 output.264

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
