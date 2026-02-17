import 'dart:io';

import 'platform_capability_service.dart';

PlatformCapabilityService createPlatformCapabilityServiceImpl() {
  return _IoPlatformCapabilityService();
}

class _IoPlatformCapabilityService implements PlatformCapabilityService {
  @override
  bool get supportsOcr => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  bool get supportsEmbeddedBrowser =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  bool get supportsImagePicker => Platform.isAndroid || Platform.isIOS;

  @override
  bool get supportsCamera => Platform.isAndroid || Platform.isIOS;

  @override
  bool get isDesktopFfiPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
