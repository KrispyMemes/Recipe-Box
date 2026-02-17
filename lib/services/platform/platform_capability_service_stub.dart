import 'platform_capability_service.dart';

PlatformCapabilityService createPlatformCapabilityServiceImpl() {
  return _StubPlatformCapabilityService();
}

class _StubPlatformCapabilityService implements PlatformCapabilityService {
  @override
  bool get supportsOcr => false;

  @override
  bool get supportsEmbeddedBrowser => false;

  @override
  bool get supportsImagePicker => false;

  @override
  bool get supportsCamera => false;

  @override
  bool get isDesktopFfiPlatform => false;
}
