# OpenH264 Nim Bindings
#
# (c) 2025 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/openh264-nim

## This module provides high-level API for encoding and decoding H.264 video using the OpenH264 library.
## It wraps the low-level C API with Nim-friendly types and error handling.

import ./openh264/openh264_bindings
export openh264_bindings

{.passL: "-lopenh264".}

#
# Errors
#

type
  OpenH264Error* = object of CatchableError
  EncoderError*  = object of OpenH264Error
  DecoderError*  = object of OpenH264Error

template checkEncoder*(code: cint, msg: string) =
  if code != 0:
    raise newException(EncoderError, msg & " (code: " & $code & ")")

template checkDecoder*(code: clong, msg: string) =
  if code != 0:
    raise newException(DecoderError, msg & " (code: " & $code & ")")

#
# Encoder
#
type
  Encoder* = ref object
    ## Encoder wrapper type holding the underlying ISVCEncoder handle
    handle: ISVCEncoder

proc newEncoder*: Encoder =
  ## Create and return a new SVC encoder instance
  result = Encoder()
  let rc = WelsCreateSVCEncoder(addr result.handle)
  if rc != 0:
    raise newException(EncoderError, "Failed to create encoder (code: " & $rc & ")")

proc close*(enc: Encoder) =
  ## Release encoder resources. After calling this, the Encoder
  ## instance should not be used.
  if enc.handle != nil:
    discard enc.handle.vtbl.Uninitialize(enc.handle)
    WelsDestroySVCEncoder(enc.handle)
    enc.handle = nil

proc initialize*(enc: Encoder; width, height, bitrate: int;
                 frameRate: float = 30.0;
                 usage: EUsageType = CAMERA_VIDEO_REAL_TIME) =
  ## Initialize the encoder with the specified parameters. This must
  ## be called before encoding frames.
  var param: SEncParamBase
  zeroMem(addr param, sizeof(SEncParamBase))
  param.iUsageType     = usage
  param.iPicWidth      = cint(width)
  param.iPicHeight     = cint(height)
  param.iTargetBitrate = cint(bitrate)
  param.iRCMode        = RC_QUALITY_MODE
  param.fMaxFrameRate  = cfloat(frameRate)
  checkEncoder enc.handle.vtbl.Initialize(enc.handle, addr param),
    "Failed to initialize encoder"

proc initializeExt*(enc: Encoder; param: var SEncParamExt) =
  ## Initialize the encoder with extended parameters. This allows for more fine-grained
  ## control over encoding settings.
  checkEncoder enc.handle.vtbl.InitializeExt(enc.handle, addr param),
    "Failed to initialize encoder (ext)"

proc getDefaultParams*(enc: Encoder): SEncParamExt =
  ## Retrieve the default encoder parameters for the current configuration. This can be used
  ## as a starting point before modifying specific fields and re-initializing with initializeExt.
  checkEncoder enc.handle.vtbl.GetDefaultParams(enc.handle, addr result),
    "Failed to get default encoder params"

proc encodeFrame*(enc: Encoder; pic: var SSourcePicture): SFrameBSInfo =
  ## Encode a single frame. The input picture must be properly initialized with the
  ## correct format and data pointers.
  let rc = enc.handle.vtbl.EncodeFrame(enc.handle, addr pic, addr result)
  if rc != 0:
    raise newException(EncoderError, "EncodeFrame failed (code: " & $rc & ")")

proc encodeParameterSets*(enc: Encoder): SFrameBSInfo =
  ## Encode the parameter sets (SPS/PPS) for the current configuration. This is typically
  ## called before encoding the first frame to ensure the decoder has the necessary information.
  checkEncoder enc.handle.vtbl.EncodeParameterSets(enc.handle, addr result),
    "EncodeParameterSets failed"

proc forceIntraFrame*(enc: Encoder; idr: bool = true) =
  ## Force the next frame to be an intra frame (IDR). This can be used to create keyframes on demand.
  checkEncoder enc.handle.vtbl.ForceIntraFrame(enc.handle, idr),
    "ForceIntraFrame failed"

proc setOption*(enc: Encoder; option: ENCODER_OPTION; value: pointer) =
  ## Set an encoder option at runtime. The specific options and expected value types are
  ## defined in the OpenH264 API.
  checkEncoder enc.handle.vtbl.SetOption(enc.handle, option, value),
    "Encoder SetOption failed"

proc getOption*(enc: Encoder; option: ENCODER_OPTION; value: pointer) =
  ## Get an encoder option at runtime. The specific options and expected value types are
  ## defined in the OpenH264 API.
  checkEncoder enc.handle.vtbl.GetOption(enc.handle, option, value),
    "Encoder GetOption failed"

proc setFrameRate*(enc: Encoder; fps: float32) =
  ## Convenience: change frame rate at runtime
  var v = cfloat(fps)
  enc.setOption(ENCODER_OPTION_FRAME_RATE, addr v)

proc setBitrate*(enc: Encoder; bitrate: int) =
  ## Convenience: change target bitrate at runtime
  var info = SBitrateInfo(iLayer: SPATIAL_LAYER_ALL, iBitrate: cint(bitrate))
  enc.setOption(ENCODER_OPTION_BITRATE, addr info)

proc getStatistics*(enc: Encoder): SEncoderStatistics =
  ## Retrieve encoder statistics such as actual bitrate, frame rate, etc.
  enc.getOption(ENCODER_OPTION_GET_STATISTICS, addr result)

#
# Decoder
#
type
  Decoder* = ref object
    ## Decoder wrapper type holding the underlying ISVCDecoder handle
    handle: ISVCDecoder

  DecodedFrame* = object
    ## Represents a decoded video frame, including pointers to the
    ## YUV planes and associated metadata
    planes*:   array[3, ptr uint8]   ## Y, U, V planes
    width*:    int
    height*:   int
    info*:     SBufferInfo

proc hasOutput*(frame: DecodedFrame): bool =
  ## Returns true if the decoded frame contains valid output data
  frame.info.iBufferStatus == 1

proc newDecoder*: Decoder =
  ## Create and return a new SVC decoder instance
  result = Decoder()
  let rc = WelsCreateDecoder(addr result.handle)
  if rc != 0:
    raise newException(DecoderError, "Failed to create decoder (code: " & $rc & ")")

proc close*(dec: Decoder) =
  ## Release decoder resources. After calling this, the
  ## Decoder instance should not be used.
  if dec.handle != nil:
    discard dec.handle.vtbl.Uninitialize(dec.handle)
    WelsDestroyDecoder(dec.handle)
    dec.handle = nil

proc initialize*(dec: Decoder;
                 ecMode: ERROR_CON_IDC = ERROR_CON_FRAME_COPY;
                 bsType: VIDEO_BITSTREAM_TYPE = VIDEO_BITSTREAM_AVC) =
  ## Initialize the decoder with the specified error concealment mode and bitstream type.
  var param = SDecodingParam(
    uiCpuLoad:       0,
    uiTargetDqLayer: uint8(0xFF),
    eEcActiveIdc:    ecMode,
    bParseOnly:      false,
    sVideoProperty:  SVideoProperty(eVideoBsType: bsType)
  )
  checkDecoder dec.handle.vtbl.Initialize(dec.handle, addr param),
    "Failed to initialize decoder"

proc decodeFrame*(dec: Decoder; src: openArray[uint8]): DecodedFrame =
  ## Decode a single frame from the input bitstream. The input should be a complete NAL unit or frame.
  var
    info   = SBufferInfo()
    planes: array[3, ptr uint8]
  let state = dec.handle.vtbl.DecodeFrame2(
    dec.handle,
    unsafeAddr src[0], cint(src.len),
    cast[ptr ptr uint8](addr planes[0]),
    addr info
  )
  if state != dsErrorFree and state != dsFramePending:
    raise newException(DecoderError, "DecodeFrame2 failed (state: " & $state & ")")
  result = DecodedFrame(
    planes: planes,
    width:  int(info.UsrData.sSystemBuffer.iWidth),
    height: int(info.UsrData.sSystemBuffer.iHeight),
    info:   info
  )

proc flushFrame*(dec: Decoder): DecodedFrame =
  ## Flush the decoder to retrieve any remaining frames after the end of the stream.
  ## This should be called after all input frames have been decoded to ensure all output is retrieved.
  var
    info   = SBufferInfo()
    planes: array[3, ptr uint8]
  let state = dec.handle.vtbl.FlushFrame(
    dec.handle,
    cast[ptr ptr uint8](addr planes[0]),
    addr info
  )
  if state != dsErrorFree:
    raise newException(DecoderError, "FlushFrame failed (state: " & $state & ")")
  result = DecodedFrame(
    planes: planes,
    width:  int(info.UsrData.sSystemBuffer.iWidth),
    height: int(info.UsrData.sSystemBuffer.iHeight),
    info:   info
  )

proc setOption*(dec: Decoder; option: DECODER_OPTION; value: pointer) =
  ## Set a decoder option at runtime. The specific options and expected value types are
  ## defined in the OpenH264 API.
  checkDecoder dec.handle.vtbl.SetOption(dec.handle, option, value),
    "Decoder SetOption failed"

proc getOption*(dec: Decoder; option: DECODER_OPTION; value: pointer) =
  ## Get a decoder option at runtime. The specific options and expected value types are
  ## defined in the OpenH264 API.
  checkDecoder dec.handle.vtbl.GetOption(dec.handle, option, value),
    "Decoder GetOption failed"

#
# Misc
#
proc codecVersion*: OpenH264Version =
  ## Return the linked openh264 library version
  WelsGetCodecVersion()

proc codecVersionString*: string =
  ## Return the linked openh264 library version as a string
  let v = WelsGetCodecVersion()
  $v.uMajor & "." & $v.uMinor & "." & $v.uRevision

proc decoderCapability*: SDecoderCapability =
  ## Query decoder hardware/software capability
  let rc = WelsGetDecoderCapability(addr result)
  if rc != 0:
    raise newException(DecoderError, "WelsGetDecoderCapability failed (code: " & $rc & ")")