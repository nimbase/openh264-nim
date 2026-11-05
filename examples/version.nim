## Print the linked OpenH264 version and decoder capability.
## Run with: nim c -r examples/version.nim

import openh264

echo "OpenH264 version: ", codecVersionString()

let cap = decoderCapability()
echo "Decoder max bitrate (bps): ", cap.iMaxBr
echo "Decoder max FS: ", cap.iMaxFs
