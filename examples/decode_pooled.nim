## Decode into a reused pool of user-owned buffers.
## The decoder hands out pointers to its own internal picture buffers,
## which it recycles on every decode call, so each picture is copied out
## immediately into the next pooled buffer. Total decode-side memory stays
## flat no matter how many frames are processed.
## Run with: nim c -r examples/decode_pooled.nim

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
