/// Profile models for `API.md` section 10 (endpoints 27–31).
///
/// Hand-written rather than generated: the shapes are small and every field
/// tolerates a missing or mistyped value from the backend.
library;

String _string(Object? value) => value is String ? value : '';

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class ProfileExperience {
  const ProfileExperience({
    required this.id,
    required this.title,
    required this.company,
    required this.startDate,
    this.location = '',
    this.endDate,
    this.isCurrent = false,
    this.description = '',
  });

  final String id;
  final String title;
  final String company;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final String description;

  /// "2022 – Present" or "2019 – 2021".
  String get period {
    final end = isCurrent || endDate == null ? 'Present' : '${endDate!.year}';
    return '${startDate.year} – $end';
  }

  factory ProfileExperience.fromJson(Map<String, dynamic> json) {
    return ProfileExperience(
      id: _string(json['id']),
      title: _string(json['title']),
      company: _string(json['company']),
      location: _string(json['location']),
      startDate: _date(json['start_date']) ?? DateTime(1970),
      endDate: _date(json['end_date']),
      isCurrent: json['is_current'] == true,
      description: _string(json['description']),
    );
  }

  /// Request body for endpoint 29. A current role never sends an end date.
  Map<String, dynamic> toRequest() {
    return {
      'title': title,
      'company': company,
      'location': location,
      'start_date': _isoDate(startDate),
      'end_date': isCurrent || endDate == null ? null : _isoDate(endDate!),
      'is_current': isCurrent,
      'description': description,
    };
  }
}

class ProfileEducation {
  const ProfileEducation({
    required this.id,
    required this.school,
    this.degree = '',
    this.fieldOfStudy = '',
    this.startYear,
    this.endYear,
  });

  final String id;
  final String school;
  final String degree;
  final String fieldOfStudy;
  final int? startYear;
  final int? endYear;

  /// "2019 – 2021", a single year, or empty when no year is known.
  String get period {
    if (startYear != null && endYear != null) return '$startYear – $endYear';
    final only = startYear ?? endYear;
    return only == null ? '' : '$only';
  }

  /// "M.S., Computer Science" from whichever parts are filled in.
  String get credential =>
      [degree, fieldOfStudy].where((part) => part.isNotEmpty).join(', ');

  factory ProfileEducation.fromJson(Map<String, dynamic> json) {
    return ProfileEducation(
      id: _string(json['id']),
      school: _string(json['school']),
      degree: _string(json['degree']),
      fieldOfStudy: _string(json['field_of_study']),
      startYear: _int(json['start_year']),
      endYear: _int(json['end_year']),
    );
  }

  /// Request body for endpoint 30.
  Map<String, dynamic> toRequest() {
    return {
      'school': school,
      'degree': degree,
      'field_of_study': fieldOfStudy,
      'start_year': startYear,
      'end_year': endYear,
    };
  }
}

/// The editable text fields of a profile (endpoint 28).
class ProfileDetails {
  const ProfileDetails({
    required this.name,
    this.headline = '',
    this.bio = '',
    this.location = '',
    this.website = '',
    this.githubHandle = '',
    this.linkedinUrl = '',
  });

  final String name;
  final String headline;
  final String bio;
  final String location;
  final String website;
  final String githubHandle;
  final String linkedinUrl;

  Map<String, dynamic> toRequest() {
    return {
      'name': name,
      'headline': headline,
      'bio': bio,
      'location': location,
      'website': website,
      'github_handle': githubHandle,
      'linkedin_url': linkedinUrl,
    };
  }
}

class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.email,
    this.headline = '',
    this.bio = '',
    this.location = '',
    this.website = '',
    this.githubHandle = '',
    this.linkedinUrl = '',
    this.skills = const [],
    this.avatarUrl,
    this.coverUrl,
    this.experiences = const [],
    this.educations = const [],
    this.rewriteTone = 'professional',
  });

  /// Tones the AI can rewrite named group messages in (API 44), in the
  /// order the profile screen cycles through them.
  static const rewriteTones = [
    'professional',
    'direct',
    'socratic',
    'empathetic',
  ];

  final String id;
  final String name;

  /// Private: how the AI should phrase this user's named group messages.
  final String rewriteTone;

  /// Only present on the signed-in user's own profile.
  final String? email;
  final String headline;
  final String bio;
  final String location;
  final String website;
  final String githubHandle;
  final String linkedinUrl;
  final List<String> skills;
  final String? avatarUrl;
  final String? coverUrl;
  final List<ProfileExperience> experiences;
  final List<ProfileEducation> educations;

  ProfileDetails get details => ProfileDetails(
    name: name,
    headline: headline,
    bio: bio,
    location: location,
    website: website,
    githubHandle: githubHandle,
    linkedinUrl: linkedinUrl,
  );

  factory Profile.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : const <String, dynamic>{};
    final rawSkills = user['skills'];
    return Profile(
      id: _string(user['id']),
      name: _string(user['name']),
      email: _nullableString(user['email']),
      headline: _string(user['headline']),
      bio: _string(user['bio']),
      location: _string(user['location']),
      website: _string(user['website']),
      githubHandle: _string(user['github_handle']),
      linkedinUrl: _string(user['linkedin_url']),
      skills: rawSkills is List
          ? [
              for (final skill in rawSkills)
                if (skill is String) skill,
            ]
          : const [],
      avatarUrl: _nullableString(user['avatar_url']),
      coverUrl: _nullableString(user['cover_url']),
      experiences: _list(json['experiences'], ProfileExperience.fromJson),
      educations: _list(json['educations'], ProfileEducation.fromJson),
      rewriteTone: rewriteTones.contains(user['rewrite_tone'])
          ? user['rewrite_tone'] as String
          : 'professional',
    );
  }

  Profile copyWith({
    ProfileDetails? details,
    List<String>? skills,
    String? Function()? avatarUrl,
    String? Function()? coverUrl,
    List<ProfileExperience>? experiences,
    List<ProfileEducation>? educations,
    String? rewriteTone,
  }) {
    final next = details ?? this.details;
    return Profile(
      id: id,
      email: email,
      name: next.name,
      headline: next.headline,
      bio: next.bio,
      location: next.location,
      website: next.website,
      githubHandle: next.githubHandle,
      linkedinUrl: next.linkedinUrl,
      skills: skills ?? this.skills,
      avatarUrl: avatarUrl == null ? this.avatarUrl : avatarUrl(),
      coverUrl: coverUrl == null ? this.coverUrl : coverUrl(),
      experiences: experiences ?? this.experiences,
      educations: educations ?? this.educations,
      rewriteTone: rewriteTone ?? this.rewriteTone,
    );
  }
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) decode) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) decode(Map<String, dynamic>.from(item)),
  ];
}

enum ProfileImageKind { avatar, cover }
