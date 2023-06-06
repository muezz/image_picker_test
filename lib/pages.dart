import 'dart:developer';
import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

typedef ImageMetadata = Map<String, IfdTag>;

class FirstPage extends HookWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    final image = useState<File?>(null);
    final imageMetadata = useState<ImageMetadata?>(null);
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await getImageFromCamera((i) => image.value = i).then(
                      (value) async {
                        var res = await getRotationMetadata(image.value!);
                        imageMetadata.value = res;
                      },
                    );
                  },
                  child: const Text('Capture Image'),
                ),
                MyImage(image: image),
                if (imageMetadata.value != null) ...[
                  Text(
                    '- Exif Metadata -',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...imageMetadata.value!.entries
                      .map(
                        (e) => RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: '${e.key}: ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: '${e.value}'),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          var res =
                              await applyRotationFixManually(image.value!);

                          image.value = res;
                          imageMetadata.value = await getRotationMetadata(res);
                        },
                        child: const Text('Fix Manually'),
                      ),
                      // ElevatedButton(
                      //   onPressed: () async {
                      //     var res =
                      //         await usingFlutterImageCompress(image.value!);

                      //     image.value = res;
                      //     imageMetadata.value = await getRotationMetadata(res);
                      //   },
                      //   child: const Text('Method 2'),
                      // ),
                      // ElevatedButton(
                      //   onPressed: () async {
                      //     var res =
                      //         await usingFlutterExifRotation(image.value!);

                      //     image.value = res;
                      //     imageMetadata.value = await getRotationMetadata(res);
                      //   },
                      //   child: const Text('Method 3'),
                      // ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyImage extends StatelessWidget {
  const MyImage({
    super.key,
    required this.image,
  });

  final ValueNotifier<File?> image;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: image.value != null
          ? Card(
              shape: Border.all(),
              child: Image.file(image.value!),
            )
          : Card(
              shape: Border.all(),
              child: const Center(
                child: Text(
                  'No Image Selected',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}

Future<void> getImageFromCamera(
  void Function(File)? onImageSelect,
) async {
  try {
    var res = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      // maxWidth: 1200,
      // maxHeight: 1200,
      // requestFullMetadata: true,
    );
    if (res == null) {
      return;
    }

    onImageSelect?.call(File(res.path));
  } on PlatformException catch (e) {
    log('Unable to capture image: $e');
  }
}

Future<ImageMetadata> getRotationMetadata(File f) async {
  var imageBytes = await f.readAsBytes();

  final exifData = await readExifFromBytes(imageBytes);
  return Map.from(exifData)
    ..removeWhere(
      (key, value) => ![
        'Image ImageWidth',
        'Image ImageLength',
        'Image Orientation',
      ].contains(key),
    );
}

/// Method 1
Future<File> applyRotationFixManually(File file) async {
  var tempFile = File.fromUri(file.uri);
  try {
    Map<String, IfdTag> data = await readExifFromFile(tempFile);
    log(data.toString());

    int? length = int.tryParse(data['EXIF ExifImageLength'].toString());
    int? width = int.tryParse(data['EXIF ExifImageWidth'].toString());
    String? orientation = data['Image Orientation']?.toString();

    if (length != null && width != null && orientation != null) {
      if (length > width) {
        log(orientation);
        if (orientation.contains('Rotated 90 CW')) {
          log('Rotated 90 CW');
          img.Image? original = img.decodeImage(tempFile.readAsBytesSync());
          img.Image? fixed = img.copyRotate(original!, angle: -90);
          tempFile.writeAsBytesSync(img.encodeJpg(fixed));
        } else if (orientation.contains('Rotated 180 CW')) {
          log('Rotated 180 CW');
          img.Image? original = img.decodeImage(tempFile.readAsBytesSync());
          img.Image fixed = img.copyRotate(original!, angle: -180);
          tempFile.writeAsBytesSync(img.encodeJpg(fixed));
        } else if (orientation.contains('Rotated 270 CW')) {
          log('Rotated 270 CW');
          img.Image? original = img.decodeImage(tempFile.readAsBytesSync());
          img.Image fixed = img.copyRotate(original!, angle: -270);
          tempFile.writeAsBytesSync(img.encodeJpg(fixed));
        }
      }
    }
  } catch (e) {
    log(e.toString());
  }
  return tempFile;
}

/// Method 2
Future<File> usingFlutterImageCompress(File image) async {
  var imageBytes = await image.readAsBytes();

  var result = await FlutterImageCompress.compressWithList(
    imageBytes,
    quality: 100,
    rotate: 0,
  );

  final tempDir = await getTemporaryDirectory();
  final file = await File('${tempDir.path}/image.png').create();
  file.writeAsBytesSync(result);

  return file;
}

/// Method 3
Future<File> usingFlutterExifRotation(File image) async {
  var result = await FlutterExifRotation.rotateImage(path: image.path);
  return result;
}
