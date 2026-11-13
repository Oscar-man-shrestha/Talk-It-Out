import 'dart:typed_data';

import 'package:talk_it_out/features/profile/data/profile.dart';

/// The signed-in user's own profile (`API.md` section 10).
abstract class ProfileRepository {
  Future<Profile> getMyProfile();

  Future<Profile> updateDetails(ProfileDetails details);

  Future<Profile> updateSkills(List<String> skills);

  /// [draft.id] is ignored; the server assigns one.
  Future<ProfileExperience> addExperience(ProfileExperience draft);

  Future<ProfileExperience> updateExperience(ProfileExperience experience);

  Future<void> deleteExperience(String experienceId);

  /// [draft.id] is ignored; the server assigns one.
  Future<ProfileEducation> addEducation(ProfileEducation draft);

  Future<ProfileEducation> updateEducation(ProfileEducation education);

  Future<void> deleteEducation(String educationId);

  /// Uploads a PNG, JPEG, or WebP of at most 2 MB and returns its URL.
  Future<String> uploadImage(
    ProfileImageKind kind, {
    required Uint8List bytes,
    required String filename,
  });

  Future<void> removeImage(ProfileImageKind kind);
}
