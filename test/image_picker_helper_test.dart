import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ImagePickerHelper toggles useAndroidPhotoPicker correctly', () {
    final androidPicker = ImagePickerAndroid();
    ImagePickerPlatform.instance = androidPicker;

    // 1. By default or when configured with false, should be false (device gallery intent)
    ImagePickerHelper.configureAndroidPicker(usePhotoPicker: false);
    expect(androidPicker.useAndroidPhotoPicker, isFalse);

    // 2. When configured with true, should be true (Google Photos photo picker)
    ImagePickerHelper.configureAndroidPicker(usePhotoPicker: true);
    expect(androidPicker.useAndroidPhotoPicker, isTrue);

    // 3. Revert to false
    ImagePickerHelper.configureAndroidPicker(usePhotoPicker: false);
    expect(androidPicker.useAndroidPhotoPicker, isFalse);
  });
}
