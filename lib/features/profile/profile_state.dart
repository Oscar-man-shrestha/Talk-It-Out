import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/utils/image_download.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/profile/data/profile.dart' as api;
import 'package:talk_it_out/features/profile/data/profile_repository.dart';

class ProfileExperience {
  const ProfileExperience({
    required this.id,
    required this.role,
    required this.company,
    required this.duration,
    required this.location,
    required this.description,
  });

  final String id;
  final String role;
  final String company;
  final String duration;
  final String location;
  final String description;

  ProfileExperience copyWith({
    String? id,
    String? role,
    String? company,
    String? duration,
    String? location,
    String? description,
  }) {
    return ProfileExperience(
      id: id ?? this.id,
      role: role ?? this.role,
      company: company ?? this.company,
      duration: duration ?? this.duration,
      location: location ?? this.location,
      description: description ?? this.description,
    );
  }
}

class ProfileEducation {
  const ProfileEducation({
    required this.id,
    required this.school,
    required this.degree,
    required this.duration,
    required this.details,
  });

  final String id;
  final String school;
  final String degree;
  final String duration;
  final String details;

  ProfileEducation copyWith({
    String? id,
    String? school,
    String? degree,
    String? duration,
    String? details,
  }) {
    return ProfileEducation(
      id: id ?? this.id,
      school: school ?? this.school,
      degree: degree ?? this.degree,
      duration: duration ?? this.duration,
      details: details ?? this.details,
    );
  }
}

class UserProfile {
  /// A profile with only a name, shown while the real one loads.
  const UserProfile.empty({this.name = ''})
    : email = null,
      headline = '',
      bio = '',
      avatarUrl = null,
      coverImageUrl = null,
      location = '',
      linkedinUrl = '',
      githubUrl = '',
      websiteUrl = '',
      coverStyle = 0,
      toneIndex = 0,
      experiences = const [],
      educations = const [],
      skills = const [];

  const UserProfile({
    required this.name,
    this.email,
    required this.headline,
    required this.bio,
    this.avatarUrl,
    this.coverImageUrl,
    required this.location,
    required this.linkedinUrl,
    required this.githubUrl,
    this.websiteUrl = '',
    this.coverStyle = 0,
    this.toneIndex = 0,
    this.experiences = const [],
    this.educations = const [],
    this.skills = const [],
  });

  final String name;

  /// Only known for the signed-in user's own profile.
  final String? email;
  final String headline;
  final String bio;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String location;
  final String linkedinUrl;
  final String githubUrl;
  final String websiteUrl;
  final int coverStyle;
  final int toneIndex;
  final List<ProfileExperience> experiences;
  final List<ProfileEducation> educations;
  final List<String> skills;

  UserProfile copyWith({
    String? name,
    String? headline,
    String? bio,
    String? avatarUrl,
    bool clearAvatar = false,
    String? coverImageUrl,
    bool clearCoverImage = false,
    String? location,
    String? linkedinUrl,
    String? githubUrl,
    String? websiteUrl,
    int? coverStyle,
    int? toneIndex,
    List<ProfileExperience>? experiences,
    List<ProfileEducation>? educations,
    List<String>? skills,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email,
      headline: headline ?? this.headline,
      bio: bio ?? this.bio,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      coverImageUrl: clearCoverImage
          ? null
          : (coverImageUrl ?? this.coverImageUrl),
      location: location ?? this.location,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      coverStyle: coverStyle ?? this.coverStyle,
      toneIndex: toneIndex ?? this.toneIndex,
      experiences: experiences ?? this.experiences,
      educations: educations ?? this.educations,
      skills: skills ?? this.skills,
    );
  }
}

/// The signed-in user's profile for the existing profile screen.
///
/// The view model above is filled from the profile repository (`API.md`
/// section 10) and every edit is saved back to it. Changes show immediately;
/// a failed save restores the previous profile and reports the error through
/// [profileSyncErrorProvider]. Cover style and the tone
/// preference are display settings with no server field, so they stay on
/// this device.
class UserProfileNotifier extends Notifier<UserProfile> {
  var _loadToken = 0;

  @override
  UserProfile build() {
    final user = ref.watch(sessionProvider.select((s) => s.value));
    ref.watch(profileRepositoryProvider);
    if (user == null) return const UserProfile.empty();
    final token = ++_loadToken;
    Future.microtask(() => _load(token));
    return UserProfile.empty(name: user.name);
  }

  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  Future<void> _load(int token) async {
    try {
      final loaded = await _repo.getMyProfile();
      if (!ref.mounted || token != _loadToken) return;
      state = _fromApi(loaded, keep: state);
    } catch (error) {
      if (ref.mounted) _report(error);
    }
  }

  /// Reloads from the repository, for pull-to-refresh or after an error.
  Future<void> reload() => _load(++_loadToken);

  void _report(Object error) {
    ref.read(profileSyncErrorProvider.notifier).report(error);
  }

  /// Applies [next] now and runs [save]. Restores the old state on failure.
  Future<void> _optimistic(
    UserProfile next,
    Future<void> Function() save,
  ) async {
    final before = state;
    state = next;
    try {
      await save();
    } catch (error) {
      if (!ref.mounted) return;
      state = before;
      _report(error);
    }
  }

  Future<void> updateProfile({
    String? name,
    String? headline,
    String? bio,
    String? avatarUrl,
    bool clearAvatar = false,
    String? coverImageUrl,
    bool clearCoverImage = false,
    String? location,
    String? linkedinUrl,
    String? githubUrl,
    String? websiteUrl,
  }) async {
    final cleanName = name?.trim();
    final next = state.copyWith(
      name: cleanName == null || cleanName.isEmpty ? null : cleanName,
      headline: headline,
      bio: bio,
      location: location,
      linkedinUrl: linkedinUrl,
      githubUrl: githubUrl,
      websiteUrl: websiteUrl,
    );
    await _optimistic(next, () async {
      final saved = await _repo.updateDetails(
        api.ProfileDetails(
          name: next.name,
          headline: next.headline,
          bio: next.bio,
          location: next.location,
          website: next.websiteUrl,
          githubHandle: githubHandleFrom(next.githubUrl),
          linkedinUrl: next.linkedinUrl,
        ),
      );
      if (!ref.mounted) return;
      state = _fromApi(saved, keep: state);
      ref.read(sessionProvider.notifier).renamed(saved.name);
    });
    if (clearAvatar) {
      await setAvatar(null);
    } else if (avatarUrl != null && avatarUrl != state.avatarUrl) {
      await setAvatar(avatarUrl);
    }
    if (clearCoverImage) {
      await setCoverImage(null);
    } else if (coverImageUrl != null && coverImageUrl != state.coverImageUrl) {
      await setCoverImage(coverImageUrl);
    }
  }

  Future<void> setAvatar(String? url) =>
      _setImage(api.ProfileImageKind.avatar, url);

  Future<void> setCoverImage(String? url) =>
      _setImage(api.ProfileImageKind.cover, url);

  /// Uploads a picked file (data URL) or a preset picture (downloaded first).
  /// An empty value removes the image.
  Future<void> _setImage(api.ProfileImageKind kind, String? url) {
    final isAvatar = kind == api.ProfileImageKind.avatar;
    UserProfile withUrl(String? value) => isAvatar
        ? state.copyWith(avatarUrl: value, clearAvatar: value == null)
        : state.copyWith(coverImageUrl: value, clearCoverImage: value == null);

    final value = url == null || url.trim().isEmpty ? null : url.trim();
    if (value == null) {
      return _optimistic(withUrl(null), () => _repo.removeImage(kind));
    }
    return _optimistic(withUrl(value), () async {
      // A picked file arrives as a data URL; a preset is downloaded first.
      final bytes =
          _decodeDataUrl(value) ??
          (value.startsWith('http') ? await downloadPresetImage(value) : null);
      if (bytes == null) {
        throw const RepositoryException(
          code: 'unsupported_media_type',
          message: AppStrings.imageUnsupported,
        );
      }
      final stored = await _repo.uploadImage(
        kind,
        bytes: bytes,
        filename: kind.name,
      );
      if (ref.mounted) state = withUrl(stored);
    });
  }

  void setCoverStyle(int style) {
    state = state.copyWith(coverStyle: style);
    if (state.coverImageUrl != null) setCoverImage(null);
  }

  /// Moves to the next rewrite tone and saves it (API 44). The AI uses it
  /// for named group messages only; anonymous ones keep the default.
  Future<void> cycleTone() {
    final tones = api.Profile.rewriteTones;
    final next = state.copyWith(
      toneIndex: (state.toneIndex + 1) % tones.length,
    );
    return _optimistic(next, () async {
      final saved = await _repo.updateRewriteTone(tones[next.toneIndex]);
      if (!ref.mounted) return;
      state = _fromApi(saved, keep: state);
    });
  }

  // --- Experience ---
  Future<void> addExperience(ProfileExperience experience) {
    final draft = experienceToApi(experience);
    if (draft == null) return _invalidDates();
    return _optimistic(
      state.copyWith(experiences: [experience, ...state.experiences]),
      () async {
        final saved = await _repo.addExperience(draft);
        if (!ref.mounted) return;
        _replaceExperience(experience.id, experienceFromApi(saved));
      },
    );
  }

  Future<void> updateExperience(ProfileExperience experience) {
    final draft = experienceToApi(experience);
    if (draft == null) return _invalidDates();
    return _optimistic(
      state.copyWith(
        experiences: [
          for (final item in state.experiences)
            item.id == experience.id ? experience : item,
        ],
      ),
      () async {
        final saved = await _repo.updateExperience(draft);
        if (ref.mounted) {
          _replaceExperience(experience.id, experienceFromApi(saved));
        }
      },
    );
  }

  void _replaceExperience(String id, ProfileExperience saved) {
    state = state.copyWith(
      experiences: [
        for (final item in state.experiences) item.id == id ? saved : item,
      ],
    );
  }

  Future<void> deleteExperience(String id) {
    return _optimistic(
      state.copyWith(
        experiences: state.experiences.where((exp) => exp.id != id).toList(),
      ),
      () => _repo.deleteExperience(id),
    );
  }

  // --- Education ---
  Future<void> addEducation(ProfileEducation education) {
    final draft = educationToApi(education);
    if (draft == null) return _invalidDates();
    return _optimistic(
      state.copyWith(educations: [education, ...state.educations]),
      () async {
        final saved = await _repo.addEducation(draft);
        if (!ref.mounted) return;
        _replaceEducation(education.id, educationFromApi(saved));
      },
    );
  }

  Future<void> updateEducation(ProfileEducation education) {
    final draft = educationToApi(education);
    if (draft == null) return _invalidDates();
    return _optimistic(
      state.copyWith(
        educations: [
          for (final item in state.educations)
            item.id == education.id ? education : item,
        ],
      ),
      () async {
        final saved = await _repo.updateEducation(draft);
        if (ref.mounted) {
          _replaceEducation(education.id, educationFromApi(saved));
        }
      },
    );
  }

  void _replaceEducation(String id, ProfileEducation saved) {
    state = state.copyWith(
      educations: [
        for (final item in state.educations) item.id == id ? saved : item,
      ],
    );
  }

  Future<void> deleteEducation(String id) {
    return _optimistic(
      state.copyWith(
        educations: state.educations.where((edu) => edu.id != id).toList(),
      ),
      () => _repo.deleteEducation(id),
    );
  }

  Future<void> _invalidDates() {
    _report(
      const RepositoryException(
        code: 'validation',
        message: AppStrings.profileDatesInvalid,
      ),
    );
    return Future.value();
  }

  // --- Skills ---
  Future<void> addSkill(String skill) {
    final clean = skill.trim();
    final exists = state.skills.any(
      (item) => item.toLowerCase() == clean.toLowerCase(),
    );
    if (clean.isEmpty || exists) return Future.value();
    return _saveSkills([...state.skills, clean]);
  }

  Future<void> removeSkill(String skill) {
    return _saveSkills(state.skills.where((s) => s != skill).toList());
  }

  Future<void> _saveSkills(List<String> skills) {
    return _optimistic(
      state.copyWith(skills: skills),
      () => _repo.updateSkills(skills),
    );
  }

  static Uint8List? _decodeDataUrl(String value) {
    final comma = value.indexOf(',');
    if (!value.startsWith('data:') || comma < 0) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);

/// The latest profile save or load failure, for the screen to show once.
class ProfileSyncErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void report(Object error) {
    state = error is RepositoryException
        ? error.message
        : AppStrings.errorGeneric;
  }

  void clear() => state = null;
}

final profileSyncErrorProvider =
    NotifierProvider<ProfileSyncErrorNotifier, String?>(
      ProfileSyncErrorNotifier.new,
    );

// --- Mapping between the screen's view model and the API model ---

UserProfile _fromApi(api.Profile profile, {required UserProfile keep}) {
  return UserProfile(
    name: profile.name,
    email: profile.email,
    headline: profile.headline,
    bio: profile.bio,
    location: profile.location,
    avatarUrl: profile.avatarUrl,
    coverImageUrl: profile.coverUrl,
    linkedinUrl: profile.linkedinUrl,
    githubUrl: profile.githubHandle.isEmpty
        ? ''
        : 'github.com/${profile.githubHandle}',
    websiteUrl: profile.website,
    coverStyle: keep.coverStyle,
    toneIndex: api.Profile.rewriteTones
        .indexOf(profile.rewriteTone)
        .clamp(0, api.Profile.rewriteTones.length - 1),
    experiences: profile.experiences.map(experienceFromApi).toList(),
    educations: profile.educations.map(educationFromApi).toList(),
    skills: profile.skills,
  );
}

/// "github.com/priya" or "https://github.com/priya/" → "priya".
String githubHandleFrom(String value) {
  var handle = value.trim();
  handle = handle.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
  handle = handle.replaceFirst(
    RegExp(r'^(www\.)?github\.com/', caseSensitive: false),
    '',
  );
  return handle.split('/').first.replaceFirst('@', '');
}

final _year = RegExp(r'(19|20)\d{2}');

/// Reads "2021 - Present" or "2019 - 2021" into start year, end year and
/// whether it is ongoing. Returns null when no start year is present.
({int start, int? end, bool current})? parseYearRange(String text) {
  final years = _year.allMatches(text).map((m) => int.parse(m[0]!)).toList();
  if (years.isEmpty) return null;
  final current = RegExp(
    r'present|now|current',
    caseSensitive: false,
  ).hasMatch(text);
  final end = current || years.length < 2 ? null : years[1];
  if (end != null && end < years.first) return null;
  return (start: years.first, end: end, current: current);
}

String _rangeText(int? start, int? end, {bool current = false}) {
  if (start == null) return end == null ? '' : '$end';
  if (current) return '$start - Present';
  return end == null || end == start ? '$start' : '$start - $end';
}

ProfileExperience experienceFromApi(api.ProfileExperience item) {
  return ProfileExperience(
    id: item.id,
    role: item.title,
    company: item.company,
    duration: _rangeText(
      item.startDate.year,
      item.endDate?.year,
      current: item.isCurrent,
    ),
    location: item.location,
    description: item.description,
  );
}

/// Null when the dates cannot be read; the backend requires a start date.
api.ProfileExperience? experienceToApi(ProfileExperience item) {
  final range = parseYearRange(item.duration);
  if (range == null) return null;
  return api.ProfileExperience(
    id: item.id,
    title: item.role,
    company: item.company,
    location: item.location,
    startDate: DateTime(range.start),
    endDate: range.end == null ? null : DateTime(range.end!, 12, 31),
    isCurrent: range.current || range.end == null,
    description: item.description,
  );
}

ProfileEducation educationFromApi(api.ProfileEducation item) {
  return ProfileEducation(
    id: item.id,
    school: item.school,
    degree: item.degree,
    duration: _rangeText(item.startYear, item.endYear),
    details: item.fieldOfStudy,
  );
}

/// Education years are optional, but text that is not a year range is
/// rejected rather than silently dropped.
api.ProfileEducation? educationToApi(ProfileEducation item) {
  final text = item.duration.trim();
  final range = text.isEmpty ? null : parseYearRange(text);
  if (text.isNotEmpty && range == null) return null;
  return api.ProfileEducation(
    id: item.id,
    school: item.school,
    degree: item.degree,
    fieldOfStudy: item.details,
    startYear: range?.start,
    endYear: range?.end,
  );
}
