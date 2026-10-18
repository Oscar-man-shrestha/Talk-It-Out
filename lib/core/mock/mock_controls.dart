/// Delay and forced failure for mock repositories.
class MockControls {
  MockControls({
    this.delay = const Duration(milliseconds: 250),
    this.forceError = false,
  });

  Duration delay;
  bool forceError;
}
