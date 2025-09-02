import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'beauty_center_app.dart';
import 'core/connectivity/connectivity_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityRepository.instance.init();
  runApp(ProviderScope(child: BeautyCenterApp()));
}
