# OpenH264 Nim Bindings
#
# (c) 2025 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/openh264-nim

## This module provides low-level bindings to the OpenH264 library. It defines the
## C types, constants, and function signatures needed to interact with the library. For a more
## Nim-friendly API, see the `openh264.nim` module which wraps these bindings.

#
# Codec app definitions
#

# Constants
const
  MAX_TEMPORAL_LAYER_NUM*  = 4
  MAX_SPATIAL_LAYER_NUM*   = 4
  MAX_QUALITY_LAYER_NUM*   = 4
  MAX_LAYER_NUM_OF_FRAME*  = 128
  MAX_NAL_UNITS_IN_LAYER*  = 128
  MAX_RTP_PAYLOAD_LEN*     = 1000
  AVERAGE_RTP_PAYLOAD_LEN* = 800
  SAVED_NALUNIT_NUM_TMP*   = (MAX_SPATIAL_LAYER_NUM * MAX_QUALITY_LAYER_NUM) + 1 + MAX_SPATIAL_LAYER_NUM
  MAX_SLICES_NUM_TMP*      = (MAX_NAL_UNITS_IN_LAYER - SAVED_NALUNIT_NUM_TMP) div 3
  AUTO_REF_PIC_COUNT*      = -1
  UNSPECIFIED_BIT_RATE*    = 0

{.push importc, header: "<wels/codec_app_def.h>".}

type
  OpenH264Version* {.importc: "OpenH264Version", bycopy.} = object
    uMajor*:    cuint
    uMinor*:    cuint
    uRevision*: cuint
    uReserved*: cuint

  DECODING_STATE* {.size: sizeof(cint).} = enum
    dsErrorFree           = 0x00
    dsFramePending        = 0x01
    dsRefLost             = 0x02
    dsBitstreamError      = 0x04
    dsDepLayerLost        = 0x08
    dsNoParamSets         = 0x10
    dsDataErrorConcealed  = 0x20
    dsRefListNullPtrs     = 0x40
    dsInvalidArgument     = 0x1000
    dsInitialOptExpected  = 0x2000
    dsOutOfMemory         = 0x4000
    dsDstBufNeedExpan     = 0x8000

  ENCODER_OPTION* {.size: sizeof(cint).} = enum
    ENCODER_OPTION_DATAFORMAT = 0
    ENCODER_OPTION_IDR_INTERVAL
    ENCODER_OPTION_SVC_ENCODE_PARAM_BASE
    ENCODER_OPTION_SVC_ENCODE_PARAM_EXT
    ENCODER_OPTION_FRAME_RATE
    ENCODER_OPTION_BITRATE
    ENCODER_OPTION_MAX_BITRATE
    ENCODER_OPTION_INTER_SPATIAL_PRED
    ENCODER_OPTION_RC_MODE
    ENCODER_OPTION_RC_FRAME_SKIP
    ENCODER_PADDING_PADDING
    ENCODER_OPTION_PROFILE
    ENCODER_OPTION_LEVEL
    ENCODER_OPTION_NUMBER_REF
    ENCODER_OPTION_DELIVERY_STATUS
    ENCODER_LTR_RECOVERY_REQUEST
    ENCODER_LTR_MARKING_FEEDBACK
    ENCODER_LTR_MARKING_PERIOD
    ENCODER_OPTION_LTR
    ENCODER_OPTION_COMPLEXITY
    ENCODER_OPTION_ENABLE_SSEI
    ENCODER_OPTION_ENABLE_PREFIX_NAL_ADDING
    ENCODER_OPTION_SPS_PPS_ID_STRATEGY
    ENCODER_OPTION_CURRENT_PATH
    ENCODER_OPTION_DUMP_FILE
    ENCODER_OPTION_TRACE_LEVEL
    ENCODER_OPTION_TRACE_CALLBACK
    ENCODER_OPTION_TRACE_CALLBACK_CONTEXT
    ENCODER_OPTION_GET_STATISTICS
    ENCODER_OPTION_STATISTICS_LOG_INTERVAL
    ENCODER_OPTION_IS_LOSSLESS_LINK
    ENCODER_OPTION_BITS_VARY_PERCENTAGE

  DECODER_OPTION* {.size: sizeof(cint).} = enum
    DECODER_OPTION_END_OF_STREAM = 1
    DECODER_OPTION_VCL_NAL
    DECODER_OPTION_TEMPORAL_ID
    DECODER_OPTION_FRAME_NUM
    DECODER_OPTION_IDR_PIC_ID
    DECODER_OPTION_LTR_MARKING_FLAG
    DECODER_OPTION_LTR_MARKED_FRAME_NUM
    DECODER_OPTION_ERROR_CON_IDC
    DECODER_OPTION_TRACE_LEVEL
    DECODER_OPTION_TRACE_CALLBACK
    DECODER_OPTION_TRACE_CALLBACK_CONTEXT
    DECODER_OPTION_GET_STATISTICS
    DECODER_OPTION_GET_SAR_INFO
    DECODER_OPTION_PROFILE
    DECODER_OPTION_LEVEL
    DECODER_OPTION_STATISTICS_LOG_INTERVAL
    DECODER_OPTION_IS_REF_PIC
    DECODER_OPTION_NUM_OF_FRAMES_REMAINING_IN_BUFFER
    DECODER_OPTION_NUM_OF_THREADS

  ERROR_CON_IDC* {.size: sizeof(cint).} = enum
    ERROR_CON_DISABLE = 0
    ERROR_CON_FRAME_COPY
    ERROR_CON_SLICE_COPY
    ERROR_CON_FRAME_COPY_CROSS_IDR
    ERROR_CON_SLICE_COPY_CROSS_IDR
    ERROR_CON_SLICE_COPY_CROSS_IDR_FREEZE_RES_CHANGE
    ERROR_CON_SLICE_MV_COPY_CROSS_IDR
    ERROR_CON_SLICE_MV_COPY_CROSS_IDR_FREEZE_RES_CHANGE

  FEEDBACK_VCL_NAL_IN_AU* {.size: sizeof(cint).} = enum
    FEEDBACK_NON_VCL_NAL = 0
    FEEDBACK_VCL_NAL
    FEEDBACK_UNKNOWN_NAL

  LAYER_TYPE* {.size: sizeof(cint).} = enum
    NON_VIDEO_CODING_LAYER = 0
    VIDEO_CODING_LAYER     = 1

  LAYER_NUM* {.size: sizeof(cint).} = enum
    SPATIAL_LAYER_0   = 0
    SPATIAL_LAYER_1   = 1
    SPATIAL_LAYER_2   = 2
    SPATIAL_LAYER_3   = 3
    SPATIAL_LAYER_ALL = 4

  VIDEO_BITSTREAM_TYPE* {.size: sizeof(cint).} = enum
    VIDEO_BITSTREAM_AVC     = 0
    VIDEO_BITSTREAM_SVC     = 1

  KEY_FRAME_REQUEST_TYPE* {.size: sizeof(cint).} = enum
    NO_RECOVERY_REQUSET     = 0
    LTR_RECOVERY_REQUEST    = 1
    IDR_RECOVERY_REQUEST    = 2
    NO_LTR_MARKING_FEEDBACK = 3
    LTR_MARKING_SUCCESS     = 4
    LTR_MARKING_FAILED      = 5

  SLTRRecoverRequest* {.importc: "SLTRRecoverRequest", bycopy.} = object
    uiFeedbackType*:       cuint
    uiIDRPicId*:           cuint
    iLastCorrectFrameNum*: cint
    iCurrentFrameNum*:     cint
    iLayerId*:             cint

  SLTRMarkingFeedback* {.importc: "SLTRMarkingFeedback", bycopy.} = object
    uiFeedbackType*: cuint
    uiIDRPicId*:     cuint
    iLTRFrameNum*:   cint
    iLayerId*:       cint

  SLTRConfig* {.importc: "SLTRConfig", bycopy.} = object
    bEnableLongTermReference*: bool
    iLTRRefNum*:               cint

  RC_MODES* {.size: sizeof(cint).} = enum
    RC_OFF_MODE            = -1
    RC_QUALITY_MODE        = 0
    RC_BITRATE_MODE        = 1
    RC_BUFFERBASED_MODE    = 2
    RC_TIMESTAMP_MODE      = 3
    RC_BITRATE_MODE_POST_SKIP = 4

  EProfileIdc* {.size: sizeof(cint).} = enum
    PRO_UNKNOWN            = 0
    PRO_BASELINE           = 66
    PRO_MAIN               = 77
    PRO_EXTENDED           = 88
    PRO_HIGH               = 100
    PRO_HIGH10             = 110
    PRO_HIGH422            = 122
    PRO_HIGH444            = 144
    PRO_CAVLC444           = 244
    PRO_SCALABLE_BASELINE  = 83
    PRO_SCALABLE_HIGH      = 86

  ELevelIdc* {.size: sizeof(cint).} = enum
    LEVEL_UNKNOWN = 0
    LEVEL_1_B     = 9
    LEVEL_1_0     = 10
    LEVEL_1_1     = 11
    LEVEL_1_2     = 12
    LEVEL_1_3     = 13
    LEVEL_2_0     = 20
    LEVEL_2_1     = 21
    LEVEL_2_2     = 22
    LEVEL_3_0     = 30
    LEVEL_3_1     = 31
    LEVEL_3_2     = 32
    LEVEL_4_0     = 40
    LEVEL_4_1     = 41
    LEVEL_4_2     = 42
    LEVEL_5_0     = 50
    LEVEL_5_1     = 51
    LEVEL_5_2     = 52

  SliceModeEnum* {.size: sizeof(cint).} = enum
    SM_SINGLE_SLICE      = 0
    SM_FIXEDSLCNUM_SLICE = 1
    SM_RASTER_SLICE      = 2
    SM_SIZELIMITED_SLICE = 3
    SM_RESERVED          = 4

  SSliceArgument* {.importc: "SSliceArgument", bycopy.} = object
    uiSliceMode*:           SliceModeEnum
    uiSliceNum*:            cuint
    uiSliceMbNum*:          array[MAX_SLICES_NUM_TMP, cuint]
    uiSliceSizeConstraint*: cuint

  EVideoFormatSPS* {.size: sizeof(cint).} = enum
    VF_COMPONENT
    VF_PAL
    VF_NTSC
    VF_SECAM
    VF_MAC
    VF_UNDEF
    VF_NUM_ENUM

  EColorPrimaries* {.size: sizeof(cint).} = enum
    CP_RESERVED0
    CP_BT709
    CP_UNDEF
    CP_RESERVED3
    CP_BT470M
    CP_BT470BG
    CP_SMPTE170M
    CP_SMPTE240M
    CP_FILM
    CP_BT2020
    CP_NUM_ENUM

  ETransferCharacteristics* {.size: sizeof(cint).} = enum
    TRC_RESERVED0
    TRC_BT709
    TRC_UNDEF
    TRC_RESERVED3
    TRC_BT470M
    TRC_BT470BG
    TRC_SMPTE170M
    TRC_SMPTE240M
    TRC_LINEAR
    TRC_LOG100
    TRC_LOG316
    TRC_IEC61966_2_4
    TRC_BT1361E
    TRC_IEC61966_2_1
    TRC_BT2020_10
    TRC_BT2020_12
    TRC_NUM_ENUM

  EColorMatrix* {.size: sizeof(cint).} = enum
    CM_GBR
    CM_BT709
    CM_UNDEF
    CM_RESERVED3
    CM_FCC
    CM_BT470BG
    CM_SMPTE170M
    CM_SMPTE240M
    CM_YCGCO
    CM_BT2020NC
    CM_BT2020C
    CM_NUM_ENUM

  ESampleAspectRatio* {.size: sizeof(cint).} = enum
    ASP_UNSPECIFIED = 0
    ASP_1x1         = 1
    ASP_12x11       = 2
    ASP_10x11       = 3
    ASP_16x11       = 4
    ASP_40x33       = 5
    ASP_24x11       = 6
    ASP_20x11       = 7
    ASP_32x11       = 8
    ASP_80x33       = 9
    ASP_18x11       = 10
    ASP_15x11       = 11
    ASP_64x33       = 12
    ASP_160x99      = 13
    ASP_EXT_SAR     = 255

  SSpatialLayerConfig* {.importc: "SSpatialLayerConfig", bycopy.} = object
    iVideoWidth*:               cint
    iVideoHeight*:              cint
    fFrameRate*:                cfloat
    iSpatialBitrate*:           cint
    iMaxSpatialBitrate*:        cint
    uiProfileIdc*:              EProfileIdc
    uiLevelIdc*:                ELevelIdc
    iDLayerQp*:                 cint
    sSliceArgument*:            SSliceArgument
    bVideoSignalTypePresent*:   bool
    uiVideoFormat*:             uint8
    bFullRange*:                bool
    bColorDescriptionPresent*:  bool
    uiColorPrimaries*:          uint8
    uiTransferCharacteristics*: uint8
    uiColorMatrix*:             uint8
    bAspectRatioPresent*:       bool
    eAspectRatio*:              ESampleAspectRatio
    sAspectRatioExtWidth*:      cushort
    sAspectRatioExtHeight*:     cushort

  EUsageType* {.size: sizeof(cint).} = enum
    CAMERA_VIDEO_REAL_TIME
    SCREEN_CONTENT_REAL_TIME
    CAMERA_VIDEO_NON_REAL_TIME
    SCREEN_CONTENT_NON_REAL_TIME
    INPUT_CONTENT_TYPE_ALL

  ECOMPLEXITY_MODE* {.size: sizeof(cint).} = enum
    LOW_COMPLEXITY    = 0
    MEDIUM_COMPLEXITY = 1
    HIGH_COMPLEXITY   = 2

  EParameterSetStrategy* {.size: sizeof(cint).} = enum
    CONSTANT_ID                    = 0
    INCREASING_ID                  = 0x01
    SPS_LISTING                    = 0x02
    SPS_LISTING_AND_PPS_INCREASING = 0x03
    SPS_PPS_LISTING                = 0x06

  SEncParamBase* {.importc: "SEncParamBase", bycopy.} = object
    iUsageType*:     EUsageType
    iPicWidth*:      cint
    iPicHeight*:     cint
    iTargetBitrate*: cint
    iRCMode*:        RC_MODES
    fMaxFrameRate*:  cfloat

  SEncParamExt* {.importc: "SEncParamExt", bycopy.} = object
    iUsageType*:              EUsageType
    iPicWidth*:               cint
    iPicHeight*:              cint
    iTargetBitrate*:          cint
    iRCMode*:                 RC_MODES
    fMaxFrameRate*:           cfloat
    iTemporalLayerNum*:       cint
    iSpatialLayerNum*:        cint
    sSpatialLayers*:          array[MAX_SPATIAL_LAYER_NUM, SSpatialLayerConfig]
    iComplexityMode*:         ECOMPLEXITY_MODE
    uiIntraPeriod*:           cuint
    iNumRefFrame*:            cint
    eSpsPpsIdStrategy*:       EParameterSetStrategy
    bPrefixNalAddingCtrl*:    bool
    bEnableSSEI*:             bool
    bSimulcastAVC*:           bool
    iPaddingFlag*:            cint
    iEntropyCodingModeFlag*:  cint
    bEnableFrameSkip*:        bool
    iMaxBitrate*:             cint
    iMaxQp*:                  cint
    iMinQp*:                  cint
    uiMaxNalSize*:            cuint
    bEnableLongTermReference*: bool
    iLTRRefNum*:              cint
    iLtrMarkPeriod*:          cuint
    iMultipleThreadIdc*:      cushort
    bUseLoadBalancing*:       bool
    iLoopFilterDisableIdc*:   cint
    iLoopFilterAlphaC0Offset*: cint
    iLoopFilterBetaOffset*:   cint
    bEnableDenoise*:          bool
    bEnableBackgroundDetection*: bool
    bEnableAdaptiveQuant*:    bool
    bEnableFrameCroppingFlag*: bool
    bEnableSceneChangeDetect*: bool
    bIsLosslessLink*:         bool

  SDecodingParam* {.importc: "SDecodingParam", bycopy.} = object
    pFileNameRestructed*: cstring
    uiCpuLoad*:           cuint
    uiTargetDqLayer*:     uint8
    eEcActiveIdc*:        ERROR_CON_IDC
    bParseOnly*:          bool
    sVideoProperty*:      SVideoProperty

  SVideoProperty* {.importc: "SVideoProperty", bycopy.} = object
    size*:          cuint
    eVideoBsType*:  VIDEO_BITSTREAM_TYPE

  SLayerBSInfo* {.importc: "SLayerBSInfo", bycopy.} = object
    uiTemporalId*:    uint8
    uiSpatialId*:     uint8
    uiQualityId*:     uint8
    eFrameType*:      cint  # EVideoFrameType from codec_def.h
    uiLayerType*:     uint8
    iSubSeqId*:       cint
    iNalCount*:       cint
    pNalLengthInByte*: ptr cint
    pBsBuf*:          ptr uint8
    rPsnr*:           array[3, cfloat]

  SFrameBSInfo* {.importc: "SFrameBSInfo", bycopy.} = object
    iLayerNum*:       cint
    sLayerInfo*:      array[MAX_LAYER_NUM_OF_FRAME, SLayerBSInfo]
    eFrameType*:      cint  # EVideoFrameType from codec_def.h
    iFrameSizeInBytes*: cint
    uiTimeStamp*:     clonglong

  SSourcePicture* {.importc: "SSourcePicture", bycopy.} = object
    iColorFormat*: cint
    iStride*:      array[4, cint]
    pData*:        array[4, ptr uint8]
    iPicWidth*:    cint
    iPicHeight*:   cint
    uiTimeStamp*:  clonglong
    bPsnrY*:       bool
    bPsnrU*:       bool
    bPsnrV*:       bool

  SBitrateInfo* {.importc: "SBitrateInfo", bycopy.} = object
    iLayer*:   LAYER_NUM
    iBitrate*: cint

  SDumpLayer* {.importc: "SDumpLayer", bycopy.} = object
    iLayer*:    cint
    pFileName*: cstring

  SProfileInfo* {.importc: "SProfileInfo", bycopy.} = object
    iLayer*:      cint
    uiProfileIdc*: EProfileIdc

  SLevelInfo* {.importc: "SLevelInfo", bycopy.} = object
    iLayer*:    cint
    uiLevelIdc*: ELevelIdc

  SDeliveryStatus* {.importc: "SDeliveryStatus", bycopy.} = object
    bDeliveryFlag*:  bool
    iDropFrameType*: cint
    iDropFrameSize*: cint

  SDecoderCapability* {.importc: "SDecoderCapability", bycopy.} = object
    iProfileIdc*: cint
    iProfileIop*: cint
    iLevelIdc*:   cint
    iMaxMbps*:    cint
    iMaxFs*:      cint
    iMaxCpb*:     cint
    iMaxDpb*:     cint
    iMaxBr*:      cint
    bRedPicCap*:  bool

  SParserBsInfo* {.importc: "SParserBsInfo", bycopy.} = object
    iNalNum*:            cint
    pNalLenInByte*:      ptr cint
    pDstBuff*:           ptr uint8
    iSpsWidthInPixel*:   cint
    iSpsHeightInPixel*:  cint
    uiInBsTimeStamp*:    culonglong
    uiOutBsTimeStamp*:   culonglong

  PParserBsInfo* = ptr SParserBsInfo

  SEncoderStatistics* {.importc: "SEncoderStatistics", bycopy.} = object
    uiWidth*:                    cuint
    uiHeight*:                   cuint
    fAverageFrameSpeedInMs*:     cfloat
    fAverageFrameRate*:          cfloat
    fLatestFrameRate*:           cfloat
    uiBitRate*:                  cuint
    uiAverageFrameQP*:           cuint
    uiInputFrameCount*:          cuint
    uiSkippedFrameCount*:        cuint
    uiResolutionChangeTimes*:    cuint
    uiIDRReqNum*:                cuint
    uiIDRSentNum*:               cuint
    uiLTRSentNum*:               cuint
    iStatisticsTs*:              clonglong
    iTotalEncodedBytes*:         culong
    iLastStatisticsBytes*:       culong
    iLastStatisticsFrameCount*:  culong

  SDecoderStatistics* {.importc: "SDecoderStatistics", bycopy.} = object
    uiWidth*:                    cuint
    uiHeight*:                   cuint
    fAverageFrameSpeedInMs*:     cfloat
    fActualAverageFrameSpeedInMs*: cfloat
    uiDecodedFrameCount*:        cuint
    uiResolutionChangeTimes*:    cuint
    uiIDRCorrectNum*:            cuint
    uiAvgEcRatio*:               cuint
    uiAvgEcPropRatio*:           cuint
    uiEcIDRNum*:                 cuint
    uiEcFrameNum*:               cuint
    uiIDRLostNum*:               cuint
    uiFreezingIDRNum*:           cuint
    uiFreezingNonIDRNum*:        cuint
    iAvgLumaQp*:                 cint
    iSpsReportErrorNum*:         cint
    iSubSpsReportErrorNum*:      cint
    iPpsReportErrorNum*:         cint
    iSpsNoExistNalNum*:          cint
    iSubSpsNoExistNalNum*:       cint
    iPpsNoExistNalNum*:          cint
    uiProfile*:                  cuint
    uiLevel*:                    cuint
    iCurrentActiveSpsId*:        cint
    iCurrentActivePpsId*:        cint
    iStatisticsLogInterval*:     cuint

  SVuiSarInfo* {.importc: "SVuiSarInfo", bycopy.} = object
    uiSarWidth*:              cuint
    uiSarHeight*:             cuint
    bOverscanAppropriateFlag*: bool

  PVuiSarInfo* = ptr SVuiSarInfo

{.pop.}

# WELS {.size: sizeof(cint).} = enum in C)
const
  WELS_LOG_QUIET*       = 0x00
  WELS_LOG_ERROR*       = 1 shl 0
  WELS_LOG_WARNING*     = 1 shl 1
  WELS_LOG_INFO*        = 1 shl 2
  WELS_LOG_DEBUG*       = 1 shl 3
  WELS_LOG_DETAIL*      = 1 shl 4
  WELS_LOG_RESV*        = 1 shl 5
  WELS_LOG_LEVEL_COUNT* = 6
  WELS_LOG_DEFAULT*     = WELS_LOG_WARNING

#
# Codec definitions
#
type
  EVideoFormatType* {.size: sizeof(cint).} = enum
    videoFormatRGB      = 1
    videoFormatRGBA     = 2
    videoFormatRGB555   = 3
    videoFormatRGB565   = 4
    videoFormatBGR      = 5
    videoFormatBGRA     = 6
    videoFormatABGR     = 7
    videoFormatARGB     = 8
    videoFormatYUY2     = 20
    videoFormatYVYU     = 21
    videoFormatUYVY     = 22
    videoFormatI420     = 23
    videoFormatYV12     = 24
    videoFormatInternal = 25
    videoFormatNV12     = 26
    videoFormatVFlip    = -2147483648

  EVideoFrameType* {.size: sizeof(cint).} = enum
    videoFrameTypeInvalid = 0
    videoFrameTypeIDR
    videoFrameTypeI
    videoFrameTypeP
    videoFrameTypeSkip
    videoFrameTypeIPMixed

  CM_RETURN* {.size: sizeof(cint).} = enum
    cmResultSuccess = 0
    cmInitParaError
    cmUnknownReason
    cmMallocMemeError
    cmInitExpected
    cmUnsupportedData

  ENalUnitType* {.size: sizeof(cint).} = enum
    NAL_UNKNOWN   = 0
    NAL_SLICE     = 1
    NAL_SLICE_DPA = 2
    NAL_SLICE_DPB = 3
    NAL_SLICE_DPC = 4
    NAL_SLICE_IDR = 5
    NAL_SEI       = 6
    NAL_SPS       = 7
    NAL_PPS       = 8

  ENalPriority* {.size: sizeof(cint).} = enum
    NAL_PRIORITY_DISPOSABLE = 0
    NAL_PRIORITY_LOW        = 1
    NAL_PRIORITY_HIGH       = 2
    NAL_PRIORITY_HIGHEST    = 3

  EDeblockingIdc* {.size: sizeof(cint).} = enum
    DEBLOCKING_IDC_0 = 0
    DEBLOCKING_IDC_1 = 1
    DEBLOCKING_IDC_2 = 2

  ERR_TOOL* = cushort

  TSliceInfo* = object
    pBufferOfSlices*:       ptr uint8
    iCodedSliceCount*:      cint
    pLengthOfSlices*:       ptr cuint
    iFecType*:              cint
    uiSliceIdx*:            uint8
    uiSliceCount*:          uint8
    iFrameIndex*:           cchar
    uiNalRefIdc*:           uint8
    uiNalType*:             uint8
    uiContainingFinalNal*:  uint8

  PSliceInfo* = ptr TSliceInfo

  SRateThresholds* = object
    iWidth*:                 cint
    iHeight*:                cint
    iThresholdOfInitRate*:   cint
    iThresholdOfMaxRate*:    cint
    iThresholdOfMinRate*:    cint
    iMinThresholdFrameRate*: cint
    iSkipFrameRate*:         cint
    iSkipFrameStep*:         cint

  PRateThresholds* = ptr SRateThresholds

  SSysMEMBuffer* = object
    iWidth*:  cint
    iHeight*: cint
    iFormat*: EVideoFormatType
    iStride*: array[2, cint]

  SBufferInfoUsrData* {.union.} = object
    sSystemBuffer*: SSysMEMBuffer

  SBufferInfo* = object
    iBufferStatus*:      cint
    uiInBsTimeStamp*:    culonglong
    uiOutYuvTimeStamp*:  culonglong
    UsrData*:            SBufferInfoUsrData
    pDst*:               array[3, ptr uint8]

template IS_PARAMETER_SET_NAL*(eNalRefIdc, eNalType: untyped): untyped =
  ((eNalRefIdc == NAL_PRIORITY_HIGHEST) and
   ((eNalType == (NAL_SPS or NAL_PPS)) or (eNalType == NAL_SPS)))

template IS_IDR_NAL*(eNalRefIdc, eNalType: untyped): untyped =
  ((eNalRefIdc == NAL_PRIORITY_HIGHEST) and (eNalType == NAL_SLICE_IDR))

const
  FRAME_NUM_PARAM_SET* = -1
  FRAME_NUM_IDR*       = 0

  DEBLOCKING_OFFSET*       = 6
  DEBLOCKING_OFFSET_MINUS* = -6

  ET_NONE*      = 0x00
  ET_IP_SCALE*  = 0x01
  ET_FMO*       = 0x02
  ET_IR_R1*     = 0x04
  ET_IR_R2*     = 0x08
  ET_IR_R3*     = 0x10
  ET_FEC_HALF*  = 0x20
  ET_FEC_FULL*  = 0x40
  ET_RFS*       = 0x80

  kiKeyNumMultiple* = [cchar(1), cchar(1), cchar(2), cchar(4), cchar(8), cchar(16)]


#
# Codec API
#

type
  WelsTraceCallback* = proc(ctx: pointer; level: cint; str: cstring) {.cdecl.}

  # Actual vtable (what vptr points to)
  ISVCEncoderVtbl* = object
    Initialize*:          proc(self: ISVCEncoder; pParam: ptr SEncParamBase): cint {.cdecl.}
    InitializeExt*:       proc(self: ISVCEncoder; pParam: ptr SEncParamExt): cint {.cdecl.}
    GetDefaultParams*:    proc(self: ISVCEncoder; pParam: ptr SEncParamExt): cint {.cdecl.}
    Uninitialize*:        proc(self: ISVCEncoder): cint {.cdecl.}
    EncodeFrame*:         proc(self: ISVCEncoder; kpSrcPic: ptr SSourcePicture; pBsInfo: ptr SFrameBSInfo): cint {.cdecl.}
    EncodeParameterSets*: proc(self: ISVCEncoder; pBsInfo: ptr SFrameBSInfo): cint {.cdecl.}
    ForceIntraFrame*:     proc(self: ISVCEncoder; bIDR: bool): cint {.cdecl.}
    SetOption*:           proc(self: ISVCEncoder; eOptionId: ENCODER_OPTION; pOption: pointer): cint {.cdecl.}
    GetOption*:           proc(self: ISVCEncoder; eOptionId: ENCODER_OPTION; pOption: pointer): cint {.cdecl.}

  # C++ object layout: first field IS the vptr
  ISVCEncoderObj* = object
    vtbl*: ptr ISVCEncoderVtbl

  # Pointer to C++ object (what WelsCreateSVCEncoder gives you)
  ISVCEncoder*    = ptr ISVCEncoderObj
  PPISVCEncoder*  = ptr ISVCEncoder

  # Actual vtable
  ISVCDecoderVtbl* = object
    Initialize*:         proc(self: ISVCDecoder; pParam: ptr SDecodingParam): clong {.cdecl.}
    Uninitialize*:       proc(self: ISVCDecoder): clong {.cdecl.}
    DecodeFrame*:        proc(self: ISVCDecoder; pSrc: ptr uint8; iSrcLen: cint;
                              ppDst: ptr ptr uint8; pStride: ptr cint;
                              iWidth: ptr cint; iHeight: ptr cint): DECODING_STATE {.cdecl.}
    DecodeFrameNoDelay*: proc(self: ISVCDecoder; pSrc: ptr uint8; iSrcLen: cint;
                              ppDst: ptr ptr uint8; pDstInfo: ptr SBufferInfo): DECODING_STATE {.cdecl.}
    DecodeFrame2*:       proc(self: ISVCDecoder; pSrc: ptr uint8; iSrcLen: cint;
                              ppDst: ptr ptr uint8; pDstInfo: ptr SBufferInfo): DECODING_STATE {.cdecl.}
    FlushFrame*:         proc(self: ISVCDecoder; ppDst: ptr ptr uint8;
                              pDstInfo: ptr SBufferInfo): DECODING_STATE {.cdecl.}
    DecodeParser*:       proc(self: ISVCDecoder; pSrc: ptr uint8; iSrcLen: cint;
                              pDstInfo: ptr SParserBsInfo): DECODING_STATE {.cdecl.}
    DecodeFrameEx*:      proc(self: ISVCDecoder; pSrc: ptr uint8; iSrcLen: cint;
                              pDst: ptr uint8; iDstStride: cint; iDstLen: ptr cint;
                              iWidth: ptr cint; iHeight: ptr cint;
                              iColorFormat: ptr cint): DECODING_STATE {.cdecl.}
    SetOption*:          proc(self: ISVCDecoder; eOptionId: DECODER_OPTION; pOption: pointer): clong {.cdecl.}
    GetOption*:          proc(self: ISVCDecoder; eOptionId: DECODER_OPTION; pOption: pointer): clong {.cdecl.}

  ISVCDecoderObj* = object
    vtbl*: ptr ISVCDecoderVtbl

  ISVCDecoder*    = ptr ISVCDecoderObj
  PPISVCDecoder*  = ptr ISVCDecoder

{.push importc, header: "<wels/codec_api.h>".}

proc WelsCreateSVCEncoder*(ppEncoder: ptr ISVCEncoder): cint
proc WelsDestroySVCEncoder*(pEncoder: ISVCEncoder)
proc WelsGetDecoderCapability*(pDecCapability: ptr SDecoderCapability): cint
proc WelsCreateDecoder*(ppDecoder: ptr ISVCDecoder): clong
proc WelsDestroyDecoder*(pDecoder: ISVCDecoder)
proc WelsGetCodecVersion*(): OpenH264Version
proc WelsGetCodecVersionEx*(pVersion: ptr OpenH264Version)

{.pop.}


