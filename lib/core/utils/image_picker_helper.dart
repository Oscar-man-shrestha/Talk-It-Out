import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart'
    as picker;

Future<String?> pickImageFile() async {
  return picker.pickImageAsDataUrl();
}
