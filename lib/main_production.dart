import 'package:pos_printer/app/app.dart';
import 'package:pos_printer/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
