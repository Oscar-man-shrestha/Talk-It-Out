/// Human-readable failure from a repository. Screens should show [message].
class RepositoryException implements Exception {
  const RepositoryException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}
