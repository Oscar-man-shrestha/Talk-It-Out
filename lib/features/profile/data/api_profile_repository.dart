import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/profile/data/profile.dart';
import 'package:talk_it_out/features/profile/data/profile_repository.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._dio);

  final Dio _dio;

  @override
  Future<Profile> getMyProfile() {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.myProfile);
      return Profile.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<Profile> updateDetails(ProfileDetails details) {
    return _put(details.toRequest());
  }

  @override
  Future<Profile> updateSkills(List<String> skills) {
    return _put({'skills': skills});
  }

  @override
  Future<Profile> updateRewriteTone(String tone) {
    return _put({'rewrite_tone': tone});
  }

  Future<Profile> _put(Map<String, dynamic> body) {
    return guardApi(() async {
      final response = await _dio.put(Endpoints.myProfile, data: body);
      return Profile.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<ProfileExperience> addExperience(ProfileExperience draft) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.myExperiences,
        data: draft.toRequest(),
      );
      return ProfileExperience.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<ProfileExperience> updateExperience(ProfileExperience experience) {
    return guardApi(() async {
      final response = await _dio.put(
        Endpoints.myExperience(experience.id),
        data: experience.toRequest(),
      );
      return ProfileExperience.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<void> deleteExperience(String experienceId) {
    return guardApi(() async {
      await _dio.delete(Endpoints.myExperience(experienceId));
    });
  }

  @override
  Future<ProfileEducation> addEducation(ProfileEducation draft) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.myEducations,
        data: draft.toRequest(),
      );
      return ProfileEducation.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<ProfileEducation> updateEducation(ProfileEducation education) {
    return guardApi(() async {
      final response = await _dio.put(
        Endpoints.myEducation(education.id),
        data: education.toRequest(),
      );
      return ProfileEducation.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<void> deleteEducation(String educationId) {
    return guardApi(() async {
      await _dio.delete(Endpoints.myEducation(educationId));
    });
  }

  @override
  Future<String> uploadImage(
    ProfileImageKind kind, {
    required Uint8List bytes,
    required String filename,
  }) {
    return guardApi(() async {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post(_imagePath(kind), data: form);
      final url = asJsonMap(response.data)['url'];
      if (url is String && url.isNotEmpty) return url;
      throw const RepositoryException(
        code: 'unknown',
        message: AppStrings.errorGeneric,
      );
    });
  }

  @override
  Future<void> removeImage(ProfileImageKind kind) {
    return guardApi(() async {
      await _dio.delete(_imagePath(kind));
    });
  }

  static String _imagePath(ProfileImageKind kind) {
    return kind == ProfileImageKind.avatar
        ? Endpoints.myAvatar
        : Endpoints.myCover;
  }
}
