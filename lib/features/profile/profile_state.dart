import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const UserProfile({
    required this.name,
    required this.headline,
    required this.bio,
    this.avatarUrl,
    this.coverImageUrl,
    required this.location,
    required this.linkedinUrl,
    required this.githubUrl,
    this.websiteUrl = 'https://talkitout.network',
    this.coverStyle = 0,
    this.saltIndex = 0,
    this.toneIndex = 0,
    this.experiences = const [
      ProfileExperience(
        id: 'exp-1',
        role: 'Lead Systems Architect & Verified Controller',
        company: 'Talk It Out Foundation • Full-time',
        duration: '2024 - Present • 2 yrs',
        location: 'San Francisco, CA • Remote',
        description: 'Architecting zero-identity leakage protocols and asynchronous consensus rooms for enterprise teams.',
      ),
      ProfileExperience(
        id: 'exp-2',
        role: 'Staff Privacy Researcher',
        company: 'Decentralized Trust Lab • Full-time',
        duration: '2021 - 2024 • 3 yrs',
        location: 'Palo Alto, CA',
        description: 'Published research on verifiable tone stacks and blinded Schnorr authentication ratchets.',
      ),
    ],
    this.educations = const [
      ProfileEducation(
        id: 'edu-1',
        school: 'Stanford University',
        degree: 'M.S. in Computer Science',
        duration: '2019 - 2021',
        details:
            'Specialization in Applied Cryptography & Distributed Systems.',
      ),
      ProfileEducation(
        id: 'edu-2',
        school: 'UC Berkeley',
        degree: 'B.S. in Electrical Engineering & Computer Sciences',
        duration: '2015 - 2019',
        details: 'EECS Honors Program, Cryptography Research Group.',
      ),
    ],
    this.skills = const [
      'Zero-Knowledge Proofs',
      'Psychological Safety',
      'Consensus Moderation',
      'LLM Tone Neutralization',
      'Distributed Systems',
      'Differential Privacy',
    ],
  });

  final String name;
  final String headline;
  final String bio;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String location;
  final String linkedinUrl;
  final String githubUrl;
  final String websiteUrl;
  final int coverStyle;
  final int saltIndex;
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
    int? saltIndex,
    int? toneIndex,
    List<ProfileExperience>? experiences,
    List<ProfileEducation>? educations,
    List<String>? skills,
  }) {
    return UserProfile(
      name: name ?? this.name,
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
      saltIndex: saltIndex ?? this.saltIndex,
      toneIndex: toneIndex ?? this.toneIndex,
      experiences: experiences ?? this.experiences,
      educations: educations ?? this.educations,
      skills: skills ?? this.skills,
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    return const UserProfile(
      name: 'Priya Sharma',
      headline: 'Staff Privacy Architect • Zero-Knowledge Systems | Ex-Google',
      bio: 'Researching cryptographically verifiable consensus rooms and decoupled identity shielding for sensitive enterprise discourse.',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
      coverImageUrl: null,
      location: 'San Francisco Bay Area • Remote',
      linkedinUrl: 'linkedin.com/in/priya-sharma-zk',
      githubUrl: 'github.com/priyasharma-zk',
      websiteUrl: 'https://priyasharma.io',
      coverStyle: 0,
      saltIndex: 0,
      toneIndex: 0,
    );
  }

  void updateProfile({
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
  }) {
    state = state.copyWith(
      name: name,
      headline: headline,
      bio: bio,
      avatarUrl: avatarUrl,
      clearAvatar: clearAvatar,
      coverImageUrl: coverImageUrl,
      clearCoverImage: clearCoverImage,
      location: location,
      linkedinUrl: linkedinUrl,
      githubUrl: githubUrl,
      websiteUrl: websiteUrl,
    );
  }

  void setAvatar(String? url) {
    if (url == null || url.isEmpty) {
      state = state.copyWith(clearAvatar: true);
    } else {
      state = state.copyWith(avatarUrl: url);
    }
  }

  void setCoverImage(String? url) {
    if (url == null || url.isEmpty) {
      state = state.copyWith(clearCoverImage: true);
    } else {
      state = state.copyWith(coverImageUrl: url);
    }
  }

  void setCoverStyle(int style) {
    state = state.copyWith(coverStyle: style, clearCoverImage: true);
  }

  void rotateSalt() {
    state = state.copyWith(saltIndex: (state.saltIndex + 1) % 4);
  }

  void cycleTone() {
    state = state.copyWith(toneIndex: (state.toneIndex + 1) % 4);
  }

  // --- Experience Management ---
  void addExperience(ProfileExperience experience) {
    state = state.copyWith(experiences: [experience, ...state.experiences]);
  }

  void updateExperience(ProfileExperience experience) {
    final updated = state.experiences.map((exp) {
      return exp.id == experience.id ? experience : exp;
    }).toList();
    state = state.copyWith(experiences: updated);
  }

  void deleteExperience(String id) {
    state = state.copyWith(
      experiences: state.experiences.where((exp) => exp.id != id).toList(),
    );
  }

  // --- Education Management ---
  void addEducation(ProfileEducation education) {
    state = state.copyWith(educations: [education, ...state.educations]);
  }

  void updateEducation(ProfileEducation education) {
    final updated = state.educations.map((edu) {
      return edu.id == education.id ? education : edu;
    }).toList();
    state = state.copyWith(educations: updated);
  }

  void deleteEducation(String id) {
    state = state.copyWith(
      educations: state.educations.where((edu) => edu.id != id).toList(),
    );
  }

  // --- Skills Management ---
  void addSkill(String skill) {
    final clean = skill.trim();
    if (clean.isEmpty || state.skills.contains(clean)) return;
    state = state.copyWith(skills: [...state.skills, clean]);
  }

  void removeSkill(String skill) {
    state = state.copyWith(
      skills: state.skills.where((s) => s != skill).toList(),
    );
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
