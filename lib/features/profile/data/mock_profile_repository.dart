import 'dart:convert';
import 'dart:typed_data';

import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/data/auth_repository.dart';
import 'package:talk_it_out/features/profile/data/profile.dart';
import 'package:talk_it_out/features/profile/data/profile_repository.dart';

/// In-memory profiles, one per mock account. A new account starts empty,
/// exactly like a backend user who never edited a profile.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._controls, this._auth);

  static const maxImageBytes = 2 * 1024 * 1024;

  final MockControls _controls;
  final AuthRepository _auth;
  final Map<String, Profile> _profiles = {};
  var _nextId = 1;

  /// Applies the mock delay and failure switch, then runs an async [body].
  Future<T> _run<T>(Future<T> Function() body) async {
    await runMock(_controls, () {});
    return body();
  }

  Future<Profile> _current() async {
    final user = await _auth.me();
    return _profiles.putIfAbsent(
      user.id,
      () => Profile(id: user.id, name: user.name, email: user.email),
    );
  }

  Future<Profile> _save(Profile Function(Profile current) change) async {
    final next = change(await _current());
    _profiles[next.id] = next;
    return next;
  }

  @override
  Future<Profile> getMyProfile() => _run(_current);

  @override
  Future<Profile> updateDetails(ProfileDetails details) {
    return _run(() async {
      if (details.name.trim().isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.profileNameRequired,
        );
      }
      return _save((current) => current.copyWith(details: details));
    });
  }

  @override
  Future<Profile> updateSkills(List<String> skills) {
    return _run(() => _save((current) => current.copyWith(skills: skills)));
  }

  @override
  Future<ProfileExperience> addExperience(ProfileExperience draft) {
    return _run(() async {
      final created = _withId(draft, 'exp-${_nextId++}');
      await _save(
        (current) =>
            current.copyWith(experiences: [created, ...current.experiences]),
      );
      return created;
    });
  }

  @override
  Future<ProfileExperience> updateExperience(ProfileExperience experience) {
    return _run(() async {
      final current = await _current();
      if (current.experiences.every((item) => item.id != experience.id)) {
        throw _notFound;
      }
      await _save(
        (profile) => profile.copyWith(
          experiences: [
            for (final item in profile.experiences)
              item.id == experience.id ? experience : item,
          ],
        ),
      );
      return experience;
    });
  }

  @override
  Future<void> deleteExperience(String experienceId) {
    return _run(() async {
      await _save(
        (current) => current.copyWith(
          experiences: [
            for (final item in current.experiences)
              if (item.id != experienceId) item,
          ],
        ),
      );
    });
  }

  @override
  Future<ProfileEducation> addEducation(ProfileEducation draft) {
    return _run(() async {
      final created = ProfileEducation(
        id: 'edu-${_nextId++}',
        school: draft.school,
        degree: draft.degree,
        fieldOfStudy: draft.fieldOfStudy,
        startYear: draft.startYear,
        endYear: draft.endYear,
      );
      await _save(
        (current) =>
            current.copyWith(educations: [created, ...current.educations]),
      );
      return created;
    });
  }

  @override
  Future<ProfileEducation> updateEducation(ProfileEducation education) {
    return _run(() async {
      final current = await _current();
      if (current.educations.every((item) => item.id != education.id)) {
        throw _notFound;
      }
      await _save(
        (profile) => profile.copyWith(
          educations: [
            for (final item in profile.educations)
              item.id == education.id ? education : item,
          ],
        ),
      );
      return education;
    });
  }

  @override
  Future<void> deleteEducation(String educationId) {
    return _run(() async {
      await _save(
        (current) => current.copyWith(
          educations: [
            for (final item in current.educations)
              if (item.id != educationId) item,
          ],
        ),
      );
    });
  }

  @override
  Future<String> uploadImage(
    ProfileImageKind kind, {
    required Uint8List bytes,
    required String filename,
  }) {
    return _run(() async {
      if (bytes.length > maxImageBytes) {
        throw const RepositoryException(
          code: 'file_too_large',
          message: AppStrings.imageTooLarge,
        );
      }
      final mime = _sniff(bytes);
      if (mime == null) {
        throw const RepositoryException(
          code: 'unsupported_media_type',
          message: AppStrings.imageUnsupported,
        );
      }
      final url = 'data:$mime;base64,${base64Encode(bytes)}';
      await _save(
        (current) => kind == ProfileImageKind.avatar
            ? current.copyWith(avatarUrl: () => url)
            : current.copyWith(coverUrl: () => url),
      );
      return url;
    });
  }

  @override
  Future<void> removeImage(ProfileImageKind kind) {
    return _run(() async {
      await _save(
        (current) => kind == ProfileImageKind.avatar
            ? current.copyWith(avatarUrl: () => null)
            : current.copyWith(coverUrl: () => null),
      );
    });
  }

  static const _notFound = RepositoryException(
    code: 'not_found',
    message: AppStrings.notFound,
  );

  static ProfileExperience _withId(ProfileExperience draft, String id) {
    return ProfileExperience(
      id: id,
      title: draft.title,
      company: draft.company,
      location: draft.location,
      startDate: draft.startDate,
      endDate: draft.isCurrent ? null : draft.endDate,
      isCurrent: draft.isCurrent,
      description: draft.description,
    );
  }

  /// Same rule as the backend: the type comes from the bytes, not the name.
  static String? _sniff(Uint8List bytes) {
    bool starts(List<int> magic, [int offset = 0]) {
      if (bytes.length < offset + magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[offset + i] != magic[i]) return false;
      }
      return true;
    }

    if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (starts(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
        starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return 'image/webp';
    }
    return null;
  }
}
