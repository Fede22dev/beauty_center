class AppSecrets {
  AppSecrets._();

  // ignore: do_not_use_environment
  static const adminPin = String.fromEnvironment(
    'ADMIN_PIN',
    defaultValue: '000000',
  );
}
