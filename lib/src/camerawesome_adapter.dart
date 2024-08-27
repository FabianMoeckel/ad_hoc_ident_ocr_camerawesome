import 'dart:async';

import 'package:ad_hoc_ident_ocr/ad_hoc_ident_ocr.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';

/// Wraps a Camerawesome widget.
///
/// Using this widget locks the app in portrait mode, even after leaving the
/// view that contained it. This issue is documented in
/// https://github.com/Apparence-io/CamerAwesome/issues/241.
class CamerawesomeAdapter extends StatelessWidget {
  static Future<OcrImage> _convert(AnalysisImage anImg) async {
    return await anImg.when<Future<OcrImage>>(
        nv21: _nv21ToOcr,
        bgra8888: _bgraToOcr,
        yuv420: _yuv420ToOcr,
        jpeg: _jpegToOcr)!;
  }

  static Future<OcrImage> _yuv420ToOcr(Yuv420Image image) async =>
      _nv21ToOcr(await image.toNv21());

  static Future<OcrImage> _nv21ToOcr(Nv21Image image) async {
    final rotation = image.rotation.index * 90;
    var orientation = DeviceOrientation.fromInt(rotation);
    //https://developers.google.com/android/reference/com/google/mlkit/vision/common/InputImage#constants
    const rawFormat = 17;

    return OcrImage(
        singlePlaneBytes: image.bytes,
        singlePlaneBytesPerRow: image.planes[0].bytesPerRow,
        width: image.width,
        height: image.height,
        cameraSensorOrientation: orientation,
        rawImageFormat: rawFormat);
  }

  static Future<OcrImage> _bgraToOcr(Bgra8888Image image) async {
    final rotation =
        (image.rotation.index * 90 + (image.flipXY() ? 180 : 0)) ~/ 360;
    final orientation = DeviceOrientation.fromInt(rotation);
    //https://developers.google.com/android/reference/com/google/mlkit/vision/common/InputImage#constants
    const rawFormat = 1111970369;

    return OcrImage(
        singlePlaneBytes: image.bytes,
        singlePlaneBytesPerRow: image.planes[0].bytesPerRow,
        width: image.width,
        height: image.height,
        cameraSensorOrientation: orientation,
        rawImageFormat: rawFormat);
  }

  static Future<OcrImage> _jpegToOcr(JpegImage image) async {
    //https://developers.google.com/android/reference/com/google/mlkit/vision/common/InputImage#constants
    const rawFormat = 256;
    return OcrImage(
        singlePlaneBytes: image.bytes,
        singlePlaneBytesPerRow: image.width,
        width: image.width,
        height: image.height,
        rawImageFormat: rawFormat);
  }

  /// Processes the taken image after it has been converted to an [OcrImage].
  final FutureOr<void> Function(OcrImage image) onImage;

  /// A builder to be used to create the CameraAwesome widget.
  ///
  /// The builder's onImageForAnalysis argument contains the conversion
  /// delegate to set as [CameraAwesomeBuilder.onImageForAnalysis].
  final CameraAwesomeBuilder Function(BuildContext context,
      Future Function(AnalysisImage) onImageForAnalysis)? builder;

  /// Creates a wrapped Camerawesome widget,
  /// converting the images to [OcrImage].
  ///
  /// Converted images are passed to the [onImage] callback. By default,
  /// images are created in nv21 format on Android and bgra8888 format on iOS.
  /// Yuv_420 format is always converted to nv21. If a [builder] is provided,
  /// the camera conversion is passed as a delegate and has to be set as
  /// [CameraAwesomeBuilder.onImageForAnalysis].
  const CamerawesomeAdapter({super.key, required this.onImage, this.builder});

  @override
  Widget build(BuildContext context) {
    return builder != null
        ? (builder!(context, _onAnalysisImage))
        : CameraAwesomeBuilder.awesome(
            sensorConfig: SensorConfig.single(
                sensor: Sensor.position(SensorPosition.back),
                aspectRatio: CameraAspectRatios.ratio_4_3,
                flashMode: FlashMode.none,
                zoom: 0.0),
            availableFilters: const [],
            topActionsBuilder: (state) => Container(),
            progressIndicator: const Align(
              alignment: Alignment.center,
              child: CircularProgressIndicator(),
            ),
            middleContentBuilder: (state) => Column(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AwesomeCameraSwitchButton(
                        state: state,
                        scale: 1,
                      ),
                      AwesomeZoomSelector(state: state),
                      AwesomeFlashButton(
                        state: state,
                        onFlashTap: (sensor, flashMode) => sensor.setFlashMode(
                            flashMode == FlashMode.always
                                ? FlashMode.none
                                : FlashMode.always),
                        iconBuilder: (flashMode) => AwesomeCircleWidget.icon(
                          icon: flashMode == FlashMode.always
                              ? Icons.flashlight_on
                              : Icons.flashlight_off,
                          scale: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomActionsBuilder: (state) => Container(),
            saveConfig: SaveConfig.photo(
                exifPreferences: ExifPreferences(saveGPSLocation: false)),
            onImageForAnalysis: _onAnalysisImage,
            imageAnalysisConfig: AnalysisConfig(
              androidOptions: const AndroidAnalysisOptions.nv21(
                width: 640,
              ),
              cupertinoOptions: const CupertinoAnalysisOptions.bgra8888(),
              autoStart: true,
              maxFramesPerSecond: 20,
            ),
          );
  }

  Future _onAnalysisImage(AnalysisImage image) async {
    final ocrImage = await _convert(image);
    await onImage(ocrImage);
  }
}
