import std/unittest
import ../src/openh264

test "encode and decode":
  {.passL:"-L /usr/local/lib -lopenh264".}
  {.passC:"-I /usr/local/include".}

  const
    Width   = 640
    Height  = 480
    Bitrate = 500_000
    FPS     = 30.0
    Frames  = 60

  proc makeYUVFrame(width, height, frameIdx: int): seq[uint8] =
    ## Generate a synthetic I420 YUV frame
    let
      ySize  = width * height
      uvSize = (width div 2) * (height div 2)
    result = newSeq[uint8](ySize + 2 * uvSize)
    # Y plane - moving gradient
    for y in 0 ..< height:
      for x in 0 ..< width:
        result[y * width + x] = uint8((x + y + frameIdx * 3) mod 256)
    # U plane
    for i in 0 ..< uvSize:
      result[ySize + i] = uint8((128 + frameIdx) mod 256)
    # V plane
    for i in 0 ..< uvSize:
      result[ySize + uvSize + i] = uint8((64 + frameIdx * 2) mod 256)

  proc buildSourcePicture(data: var seq[uint8]; width, height: int): SSourcePicture =
    result.iColorFormat = cint(videoFormatI420)
    result.iPicWidth    = cint(width)
    result.iPicHeight   = cint(height)
    result.iStride[0]   = cint(width)
    result.iStride[1]   = cint(width div 2)
    result.iStride[2]   = cint(width div 2)
    result.pData[0]     = addr data[0]
    result.pData[1]     = addr data[width * height]
    result.pData[2]     = addr data[width * height + (width div 2) * (height div 2)]

  proc runExample() =
    echo "openh264 version: ", codecVersionString()

    # --- Encoder setup ---
    echo "\n[Encoder] Creating..."
    let enc = newEncoder()
    defer: enc.close()

    enc.initialize(Width, Height, Bitrate, FPS)
    echo "[Encoder] Initialized ", Width, "x", Height,
        " @ ", FPS, " fps, ", Bitrate div 1000, " kbps"

    # --- Decoder setup ---
    echo "\n[Decoder] Creating..."
    let dec = newDecoder()
    defer: dec.close()

    dec.initialize()
    echo "[Decoder] Initialized"

    # --- Encode/decode loop ---
    echo "\n[Loop] Processing ", Frames, " frames...\n"

    var
      totalEncBytes = 0
      decodedCount  = 0

    for i in 0 ..< Frames:
      # Build source picture
      var yuv  = makeYUVFrame(Width, Height, i)
      var pic  = buildSourcePicture(yuv, Width, Height)

      # Force IDR on first frame
      if i == 0:
        enc.forceIntraFrame(true)

      # Encode
      let bsInfo = enc.encodeFrame(pic)

      if bsInfo.eFrameType == cint(videoFrameTypeSkip):
        echo "  Frame ", i, ": skipped"
        continue

      # Collect NAL units from all layers
      var nalData: seq[uint8]
      for layerIdx in 0 ..< bsInfo.iLayerNum:
        let layer = bsInfo.sLayerInfo[layerIdx]
        var offset = 0
        for nalIdx in 0 ..< layer.iNalCount:
          let nalLen = cast[ptr UncheckedArray[cint]](layer.pNalLengthInByte)[nalIdx]
          for b in 0 ..< nalLen:
            nalData.add(cast[ptr UncheckedArray[uint8]](layer.pBsBuf)[offset + b])
          offset += nalLen

      totalEncBytes += nalData.len
      echo "  Frame ", i, " [", bsInfo.eFrameType, "]: ",
          nalData.len, " bytes encoded"

      # Decode the encoded data
      if nalData.len > 0:
        let frame = dec.decodeFrame(nalData)
        if frame.hasOutput:
          inc decodedCount
          echo "    -> Decoded: ", frame.width, "x", frame.height

    # Flush remaining frames
    echo "\n[Decoder] Flushing..."
    var flushing = true
    while flushing:
      let frame = dec.flushFrame()
      if frame.hasOutput:
        inc decodedCount
        echo "  Flushed frame: ", frame.width, "x", frame.height
      else:
        flushing = false

    # Summary
    echo "\n--- Summary ---"
    echo "Encoded frames : ", Frames
    echo "Decoded frames : ", decodedCount
    echo "Total bytes    : ", totalEncBytes
    echo "Avg frame size : ", totalEncBytes div Frames, " bytes"
    echo "Avg bitrate    : ",
        (totalEncBytes * 8 * int(FPS)) div (Frames * 1000), " kbps"

    # Show encoder statistics
    let encStats = enc.getStatistics()
    echo "\n[Encoder Stats]"
    echo "  Average QP     : ", encStats.uiAverageFrameQP
    echo "  Input  fps     : ", encStats.fAverageFrameSpeedInMs

  runExample()