import 'package:logger/logger.dart';

class AppLog {
  AppLog._();

  static final Logger logger = Logger(
    printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 5,
        lineLength: 200,
        dateTimeFormat: DateTimeFormat.dateAndTime),
  );
}
