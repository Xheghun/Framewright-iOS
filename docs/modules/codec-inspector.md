# Codec format inspection

Use `FramewrightCodecInspector` to load the format descriptions of an AVAsset's video tracks.
Use `AVPlayerFormatInspection.inspectCurrentVideoFormats()` on the main actor for the
current item. It discards results if the item changes during inspection. The result describes the asset tracks: codec FourCC, coded dimensions,
nominal frame rate if known, and whether VideoToolbox reports hardware support for the codec type.

This result does not identify AVPlayer's selected decoder, measure its initialization, or prove
hardware use for a particular playback session. The Android decoder catalog and capability fields
remain separate parity requirements. See the OpenSpec API audit for their status.

For HLS, `inspectHLSVariants(in:)` reports the asset's declared variant rates and dimensions.
It does not identify the variant currently selected by AVPlayer.
