import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app/weaview_app.dart';
import 'src/core/app_utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureImageMemoryPolicy();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const WeaviewApp());
}
