import 'platform_capability_service_stub.dart'
    if (dart.library.io) 'platform_capability_service_io.dart'
    if (dart.library.html) 'platform_capability_service_web.dart';

abstract class PlatformCapabilityService {
  bool get supportsOcr;
  bool get supportsEmbeddedBrowser;
  bool get supportsImagePicker;
  bool get supportsCamera;
  bool get isDesktopFfiPlatform;
}

PlatformCapabilityService createPlatformCapabilityService() =>
    createPlatformCapabilityServiceImpl();
