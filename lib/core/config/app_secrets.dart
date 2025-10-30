class AppSecrets {
  static const adminPin = String.fromEnvironment(
    'ADMIN_PIN',
    defaultValue: '000000',
  );
}
