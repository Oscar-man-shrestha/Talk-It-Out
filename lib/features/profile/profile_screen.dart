import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/utils/image_picker_helper.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/core/widgets/safe_image.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/feed_providers.dart';
import 'package:talk_it_out/features/feed/saved_posts.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/profile/profile_state.dart';
import 'package:talk_it_out/core/ui/brand.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Brand.accent;
const _kSurface = Brand.card;
const _kSurfaceMuted = Brand.muted;
const _kSurfaceSubtle = Brand.canvas;
const _kBorderSubtle = Brand.border;
const _kTextPrimary = Brand.ink;
const _kTextSecondary = Brand.inkSoft;
const _kTextTertiary = Brand.inkFaint;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _tones = [
    'Professional & Diplomatic',
    'Direct & Concise',
    'Socratic & Inquisitive',
    'Empathetic & Supportive',
  ];

  static const _presetCovers = [
    (
      'Cyber Matrix ZK',
      'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1200&q=80',
    ),
    (
      'Minimal Dark Fluid',
      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1200&q=80',
    ),
    (
      'Deep Mountains',
      'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=80',
    ),
    (
      'Network Satellite',
      'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1200&q=80',
    ),
    (
      'Sunset Glow',
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.linkCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openEditProfileModal() {
    final profile = ref.read(userProfileProvider);
    final nameCtrl = TextEditingController(text: profile.name);
    final headlineCtrl = TextEditingController(text: profile.headline);
    final bioCtrl = TextEditingController(text: profile.bio);
    final locationCtrl = TextEditingController(text: profile.location);
    final avatarCtrl = TextEditingController(text: profile.avatarUrl ?? '');
    final linkedinCtrl = TextEditingController(text: profile.linkedinUrl);
    final githubCtrl = TextEditingController(text: profile.githubUrl);
    final websiteCtrl = TextEditingController(text: profile.websiteUrl);
    String? selectedAvatar = profile.avatarUrl;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 20,
                              color: _kTextPrimary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Edit Public Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: _kTextSecondary,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Profile Photo Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profile Picture / Avatar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final dataUrl = await pickImageFile();
                            if (dataUrl != null) {
                              setModalState(() {
                                selectedAvatar = dataUrl;
                                avatarCtrl.text = dataUrl;
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 15,
                          ),
                          label: const Text(
                            'Upload Image',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _kTextPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedAvatar != null) ...[
                      Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: SafeImage(imageUrl: selectedAvatar),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Custom photo selected and ready to apply.',
                              style: TextStyle(
                                fontSize: 11,
                                color: _kTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PresetAvatarOption(
                            label: 'Initial',
                            isSelected: selectedAvatar == null,
                            onTap: () {
                              setModalState(() {
                                selectedAvatar = null;
                                avatarCtrl.clear();
                              });
                            },
                            child: Text(
                              _initialsOf(nameCtrl.text),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Full Name
                    _EditProfileTextField(
                      label: 'Full Name',
                      controller: nameCtrl,
                      hint: 'Your full name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),

                    // Headline
                    _EditProfileTextField(
                      label: 'Professional Headline',
                      controller: headlineCtrl,
                      hint: 'e.g. Product designer',
                      icon: Icons.subtitles_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // Location
                    _EditProfileTextField(
                      label: 'Location',
                      controller: locationCtrl,
                      hint: 'San Francisco Bay Area • Remote',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),

                    // Bio Summary
                    _EditProfileTextField(
                      label: 'About / Summary',
                      controller: bioCtrl,
                      hint: 'Tell peers about your background and research interests...',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),

                    // Social Links
                    _EditProfileTextField(
                      label: 'LinkedIn Profile URL',
                      controller: linkedinCtrl,
                      hint: 'linkedin.com/in/username',
                      icon: Icons.public,
                    ),
                    const SizedBox(height: 12),
                    _EditProfileTextField(
                      label: 'GitHub URL',
                      controller: githubCtrl,
                      hint: 'github.com/username',
                      icon: Icons.code,
                    ),
                    const SizedBox(height: 12),
                    _EditProfileTextField(
                      label: 'Website / Portfolio',
                      controller: websiteCtrl,
                      hint: 'https://yourportfolio.io',
                      icon: Icons.language,
                    ),
                    const SizedBox(height: 18),

                    // Save Action
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(userProfileProvider.notifier)
                              .updateProfile(
                                name: nameCtrl.text.trim().isEmpty
                                    ? profile.name
                                    : nameCtrl.text.trim(),
                                headline: headlineCtrl.text.trim(),
                                bio: bioCtrl.text.trim(),
                                location: locationCtrl.text.trim(),
                                avatarUrl: avatarCtrl.text.trim(),
                                clearAvatar: avatarCtrl.text.trim().isEmpty,
                                linkedinUrl: linkedinCtrl.text.trim(),
                                githubUrl: githubCtrl.text.trim(),
                                websiteUrl: websiteCtrl.text.trim(),
                              );
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully.'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCoverPhotoModal() {
    final profile = ref.read(userProfileProvider);
    final coverUrlCtrl = TextEditingController(
      text: profile.coverImageUrl ?? '',
    );
    String? currentCoverUrl = profile.coverImageUrl;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.image, size: 20, color: _kTextPrimary),
                            SizedBox(width: 8),
                            Text(
                              'Customize Cover Photo / Banner',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Real File Upload Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final dataUrl = await pickImageFile();
                          if (dataUrl != null) {
                            setModalState(() {
                              currentCoverUrl = dataUrl;
                              coverUrlCtrl.text = dataUrl;
                            });
                          }
                        },
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: const Text(
                          'Upload Cover File from Computer / Phone',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kTextPrimary,
                          side: const BorderSide(
                            color: _kBorderSubtle,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Live Preview Box
                    if (currentCoverUrl != null) ...[
                      const Text(
                        'Live Preview',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SafeImage(
                          imageUrl: currentCoverUrl,
                          height: 90,
                          width: double.infinity,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Presets Gallery
                    const Text(
                      'Or Select from Curated Wallpapers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final preset in _presetCovers) ...[
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  currentCoverUrl = preset.$2;
                                  coverUrlCtrl.text = preset.$2;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 110,
                                height: 65,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: currentCoverUrl == preset.$2
                                        ? _kPrimary
                                        : _kBorderSubtle,
                                    width: currentCoverUrl == preset.$2 ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    SafeImage(
                                      imageUrl: preset.$2,
                                      fit: BoxFit.cover,
                                    ),
                                    Container(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      alignment: Alignment.bottomLeft,
                                      child: Text(
                                        preset.$1,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Algorithmic Styles Option
                    const Text(
                      'Algorithmic Generative Styles',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final style in [
                          (0, 'CAD Blueprint'),
                          (1, 'Deep Mesh'),
                          (2, 'Onyx Slate'),
                        ]) ...[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  side: BorderSide(
                                    color:
                                        (currentCoverUrl == null &&
                                            profile.coverStyle == style.$1)
                                        ? _kPrimary
                                        : _kBorderSubtle,
                                  ),
                                ),
                                onPressed: () {
                                  ref
                                      .read(userProfileProvider.notifier)
                                      .setCoverStyle(style.$1);
                                  Navigator.of(ctx).pop();
                                },
                                child: Text(
                                  style.$2,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _kTextPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(userProfileProvider.notifier)
                              .setCoverImage(coverUrlCtrl.text.trim());
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cover image updated.'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Text(
                          'Save Cover Image',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openExperienceDialog([ProfileExperience? exp]) {
    final roleCtrl = TextEditingController(text: exp?.role ?? '');
    final companyCtrl = TextEditingController(text: exp?.company ?? '');
    final durationCtrl = TextEditingController(text: exp?.duration ?? '');
    final locationCtrl = TextEditingController(text: exp?.location ?? '');
    final descCtrl = TextEditingController(text: exp?.description ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    exp == null ? 'Add Experience' : 'Edit Experience',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _EditProfileTextField(
                label: 'Title / Role',
                controller: roleCtrl,
                hint: 'e.g. Senior Privacy Engineer',
                icon: Icons.work_outline,
              ),
              const SizedBox(height: 12),
              _EditProfileTextField(
                label: 'Company / Organization',
                controller: companyCtrl,
                hint: 'e.g. Talk It Out Foundation / Google',
                icon: Icons.business_outlined,
              ),
              const SizedBox(height: 12),
              _EditProfileTextField(
                label: 'Dates / Duration',
                controller: durationCtrl,
                hint: 'e.g. 2024 - Present • 2 yrs',
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 12),
              _EditProfileTextField(
                label: 'Location',
                controller: locationCtrl,
                hint: 'e.g. San Francisco, CA • Remote',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              _EditProfileTextField(
                label: 'Description & Highlights',
                controller: descCtrl,
                hint: 'Architecting zero-identity leakage protocols...',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final role = roleCtrl.text.trim();
                    final company = companyCtrl.text.trim();
                    if (role.isEmpty || company.isEmpty) return;

                    final updatedExp = ProfileExperience(
                      id:
                          exp?.id ??
                          'exp-${DateTime.now().millisecondsSinceEpoch}',
                      role: role,
                      company: company,
                      duration: durationCtrl.text.trim().isEmpty
                          ? '2024 - Present'
                          : durationCtrl.text.trim(),
                      location: locationCtrl.text.trim().isEmpty
                          ? 'Remote'
                          : locationCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                    );

                    if (exp == null) {
                      ref
                          .read(userProfileProvider.notifier)
                          .addExperience(updatedExp);
                    } else {
                      ref
                          .read(userProfileProvider.notifier)
                          .updateExperience(updatedExp);
                    }
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          exp == null
                              ? 'Experience added.'
                              : 'Experience updated.',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Text(
                    exp == null ? 'Add Experience' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEducationDialog([ProfileEducation? edu]) {
    final schoolCtrl = TextEditingController(text: edu?.school ?? '');
    final degreeCtrl = TextEditingController(text: edu?.degree ?? '');
    final durationCtrl = TextEditingController(text: edu?.duration ?? '');
    final detailsCtrl = TextEditingController(text: edu?.details ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    edu == null ? 'Add Education' : 'Edit Education',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _EditProfileTextField(
                label: 'School / University',
                controller: schoolCtrl,
                hint: 'e.g. Stanford University',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 12),
              _EditProfileTextField(
                label: 'Degree & Field',
                controller: degreeCtrl,
                hint: 'e.g. M.S. in Computer Science',
                icon: Icons.workspace_premium_outlined,
              ),
              const SizedBox(height: 12),
              _EditProfileTextField(
                label: 'Dates / Duration',
                controller: durationCtrl,
                hint: 'e.g. 2019 - 2021',
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 12),
              _EditProfileTextField(
                label: 'Details & Focus',
                controller: detailsCtrl,
                hint: 'e.g. Focus on machine learning',
                icon: Icons.menu_book_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final school = schoolCtrl.text.trim();
                    final degree = degreeCtrl.text.trim();
                    if (school.isEmpty || degree.isEmpty) return;

                    final updatedEdu = ProfileEducation(
                      id:
                          edu?.id ??
                          'edu-${DateTime.now().millisecondsSinceEpoch}',
                      school: school,
                      degree: degree,
                      duration: durationCtrl.text.trim().isEmpty
                          ? '2020 - 2024'
                          : durationCtrl.text.trim(),
                      details: detailsCtrl.text.trim(),
                    );

                    if (edu == null) {
                      ref
                          .read(userProfileProvider.notifier)
                          .addEducation(updatedEdu);
                    } else {
                      ref
                          .read(userProfileProvider.notifier)
                          .updateEducation(updatedEdu);
                    }
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          edu == null
                              ? 'Education added.'
                              : 'Education updated.',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Text(
                    edu == null ? 'Add Education' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddSkillDialog() {
    final skillCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Skill or Competency'),
        content: TextField(
          controller: skillCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Flutter, Research, Design',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: () {
              final skill = skillCtrl.text.trim();
              if (skill.isNotEmpty) {
                ref.read(userProfileProvider.notifier).addSkill(skill);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add Skill'),
          ),
        ],
      ),
    );
  }

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.passwordChanged)));
    }
  }

  Future<void> _confirmLogoutAll() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const _LogoutAllDialog(),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const _DeleteAccountDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.value;
    final profile = ref.watch(userProfileProvider);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final moderated = groups
        .where((group) => group.myRole == GroupRole.controller)
        .length;
    final myPosts = (ref.watch(feedProvider).value ?? const <Post>[])
        .where((post) => post.author.id == user?.id)
        .length;
    ref.listen<String?>(profileSyncErrorProvider, (_, message) {
      if (message == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      ref.read(profileSyncErrorProvider.notifier).clear();
    });
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 20.0);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            border: Border(bottom: BorderSide(color: _kBorderSubtle)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? hPad : (isMobile ? 12.0 : 16.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.chat_bubble,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'TALK IT OUT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: _kTextPrimary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('•', style: TextStyle(color: _kTextTertiary)),
                          SizedBox(width: 4),
                          Text(
                            'PROFILE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    tooltip: 'Copy profile summary',
                    onPressed: () async {
                      final summary = [
                        profile.name,
                        if (profile.headline.isNotEmpty) profile.headline,
                        if (profile.location.isNotEmpty) profile.location,
                        'on Talk It Out',
                      ].join(' · ');
                      await Clipboard.setData(ClipboardData(text: summary));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile summary copied.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Profile Details',
                    onPressed: _openEditProfileModal,
                  ),
                  Material(
                    color: Brand.accent,
                    shape: const CircleBorder(),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: ClipOval(
                        child: profile.avatarUrl != null
                            ? Image.network(
                                profile.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AsyncBody(
        status: asyncStatus(session, isEmpty: user == null),
        errorMessage: errorText(session.error),
        onRetry: () => ref.invalidate(sessionProvider),
        empty: const Center(child: Text(AppStrings.profileTitle)),
        child: user == null
            ? const SizedBox.shrink()
            : ListView(
                padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 48),
                children: [
                  // 1. LinkedIn-Style Profile Identity Card with Customizable Cover
                  Container(
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorderSubtle),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Banner (Custom Image or Generative Pattern)
                        Stack(
                          children: [
                            Container(
                              height: 120,
                              width: double.infinity,
                              color: profile.coverStyle == 1
                                  ? const Color(0xFF18181B)
                                  : (profile.coverStyle == 2
                                        ? const Color(0xFF27272A)
                                        : Brand.muted),
                              child: profile.coverImageUrl != null
                                  ? SafeImage(
                                      imageUrl: profile.coverImageUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : CustomPaint(
                                      painter: _GridPatternPainter(
                                        isDark: profile.coverStyle != 0,
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      final dataUrl = await pickImageFile();
                                      if (dataUrl != null) {
                                        ref
                                            .read(userProfileProvider.notifier)
                                            .setCoverImage(dataUrl);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _kSurface.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _kBorderSubtle,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.upload_file_outlined,
                                            size: 13,
                                            color: _kTextPrimary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Upload Cover',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _kTextPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _openCoverPhotoModal,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _kSurface.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _kBorderSubtle,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.tune_outlined,
                                            size: 13,
                                            color: _kTextPrimary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Options',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _kTextPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Avatar and Identity Info
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar overlapping cover + Edit Button
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, -36),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: _kPrimary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x1F000000),
                                                blurRadius: 8,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          clipBehavior: Clip.antiAlias,
                                          child: profile.avatarUrl != null
                                              ? SafeImage(
                                                  imageUrl: profile.avatarUrl,
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                  fallbackColor: _kPrimary,
                                                )
                                              : Text(
                                                  _userInitials(profile.name),
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                        // Edit Camera Badge
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: _openEditProfileModal,
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: _kSurface,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: _kBorderSubtle,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x15000000),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.camera_alt,
                                                size: 14,
                                                color: _kTextPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Edit Profile Button
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: OutlinedButton.icon(
                                      onPressed: _openEditProfileModal,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: _kBorderSubtle,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        minimumSize: const Size(0, 32),
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 13,
                                        color: _kTextPrimary,
                                      ),
                                      label: const Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _kTextPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Name & Verification Badge
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                        color: _kTextPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified,
                                    size: 17,
                                    color: _kPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kSurfaceMuted,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'MEMBER',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                        color: _kTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),

                              // Email
                              Row(
                                children: [
                                  Text(
                                    profile.email ?? user.email ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Professional Headline
                              Text(
                                profile.headline,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: _kTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Location & Network stats
                              Row(
                                children: [
                                  if (profile.location.isNotEmpty) ...[
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: _kTextTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile.location,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _kTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '•',
                                      style: TextStyle(color: _kTextTertiary),
                                    ),
                                    const SizedBox(width: 8),
                                  ] else ...[
                                    const Icon(
                                      Icons.diversity_3_outlined,
                                      size: 14,
                                      color: _kTextTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    groups.length == 1
                                        ? '1 group'
                                        : '${groups.length} groups',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Social Badges
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                // Only links that are set; tapping copies one.
                                children: [
                                  for (final (icon, name, url) in [
                                    (
                                      Icons.public,
                                      'LinkedIn',
                                      profile.linkedinUrl,
                                    ),
                                    (Icons.code, 'GitHub', profile.githubUrl),
                                    (
                                      Icons.language,
                                      'Portfolio',
                                      profile.websiteUrl,
                                    ),
                                  ])
                                    if (url.trim().isNotEmpty)
                                      _SocialBadge(
                                        icon: icon,
                                        label: name,
                                        onTap: () => _copyLink(url.trim()),
                                      ),
                                  if (profile.linkedinUrl.trim().isEmpty &&
                                      profile.githubUrl.trim().isEmpty &&
                                      profile.websiteUrl.trim().isEmpty)
                                    _SocialBadge(
                                      icon: Icons.add_link,
                                      label: 'Add links',
                                      onTap: _openEditProfileModal,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. LinkedIn-Style "About" Section with Dynamic Skills
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'About',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: _kTextSecondary,
                              ),
                              onPressed: _openEditProfileModal,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (profile.bio.trim().isEmpty)
                          InkWell(
                            key: const ValueKey('about-empty'),
                            onTap: _openEditProfileModal,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Brand.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Brand.accentBorder),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.edit_note,
                                    size: 18,
                                    color: Brand.accentInk,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppStrings.aboutEmpty,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: Brand.accentInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Text(
                            profile.bio,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: _kTextSecondary,
                            ),
                          ),
                        const SizedBox(height: 14),

                        // Skills & Endorsements with Add/Remove
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Top Skills & Competencies',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary,
                              ),
                            ),
                            InkWell(
                              onTap: _openAddSkillDialog,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 14, color: _kPrimary),
                                    SizedBox(width: 2),
                                    Text(
                                      'Add Skill',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _kPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final skill in profile.skills)
                              _SkillChip(
                                label: skill,
                                onRemove: () {
                                  ref
                                      .read(userProfileProvider.notifier)
                                      .removeSkill(skill);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. LinkedIn-Style "Experience" Section with Add/Edit/Delete
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Experience',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary,
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                side: const BorderSide(color: _kBorderSubtle),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(0, 30),
                              ),
                              onPressed: () => _openExperienceDialog(),
                              icon: const Icon(
                                Icons.add,
                                size: 14,
                                color: _kTextPrimary,
                              ),
                              label: const Text(
                                'Add Experience',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (profile.experiences.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No experiences added yet. Tap "+ Add Experience" above.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _kTextTertiary,
                              ),
                            ),
                          ),
                        for (
                          int i = 0;
                          i < profile.experiences.length;
                          i++
                        ) ...[
                          if (i > 0)
                            const Divider(height: 24, color: _kBorderSubtle),
                          _ExperienceItem(
                            experience: profile.experiences[i],
                            onEdit: () =>
                                _openExperienceDialog(profile.experiences[i]),
                            onDelete: () {
                              ref
                                  .read(userProfileProvider.notifier)
                                  .deleteExperience(profile.experiences[i].id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Experience removed.'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. LinkedIn-Style "Education" Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Education',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary,
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                side: const BorderSide(color: _kBorderSubtle),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(0, 30),
                              ),
                              onPressed: () => _openEducationDialog(),
                              icon: const Icon(
                                Icons.add,
                                size: 14,
                                color: _kTextPrimary,
                              ),
                              label: const Text(
                                'Add Education',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (profile.educations.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No education history added yet. Tap "+ Add Education" above.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _kTextTertiary,
                              ),
                            ),
                          ),
                        for (int i = 0; i < profile.educations.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 24, color: _kBorderSubtle),
                          _EducationItem(
                            education: profile.educations[i],
                            onEdit: () =>
                                _openEducationDialog(profile.educations[i]),
                            onDelete: () {
                              ref
                                  .read(userProfileProvider.notifier)
                                  .deleteEducation(profile.educations[i].id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Education removed.'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5. Anonymity: what others see when you send anonymously.
                  // There is no pseudonym or ID: anonymous messages carry no
                  // sender at all (only the controller sees who sent them).
                  Container(
                    key: const ValueKey('anonymity-card'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kSurfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _kPrimary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.fingerprint,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.anonymityCardTitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    AppStrings.anonymityCardSubtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _WhoSeesRow(
                          who: AppStrings.anonymityMembersSee,
                          what: AppStrings.anonymousUser,
                          tag: AppStrings.anonymityNoId,
                        ),
                        const SizedBox(height: 6),
                        _WhoSeesRow(
                          who: AppStrings.anonymityControllerSees,
                          what: profile.name,
                          tag: AppStrings.anonymityReviews,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          AppStrings.anonymityCardNote,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 6. Metrics 2x2 Bento Grid
                  GridView.count(
                    // One row of four on wide screens, 2 x 2 on phones.
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 640
                        ? 4
                        : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: MediaQuery.sizeOf(context).width >= 640
                        ? 1.25
                        : 1.35,
                    children: [
                      _BentoCard(
                        title: 'GROUPS JOINED',
                        icon: Icons.groups_outlined,
                        value: '${groups.length}',
                        subtitle: 'groups you are in',
                      ),
                      _BentoCard(
                        title: 'CONTRIBUTIONS',
                        icon: Icons.forum_outlined,
                        value: '$myPosts',
                        subtitle: 'questions asked',
                      ),
                      _BentoCard(
                        title: 'SAVED',
                        icon: Icons.bookmark_outline,
                        value: '${ref.watch(savedPostsProvider).length}',
                        subtitle: 'saved questions',
                      ),
                      _BentoCard(
                        title: 'MODERATED',
                        icon: Icons.gavel_outlined,
                        value: '$moderated',
                        subtitle: 'groups you lead',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 8. Account & Security Settings Card
                  Container(
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
                          child: Text(
                            'ACCOUNT & PLATFORM PREFERENCES',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: _kTextTertiary,
                            ),
                          ),
                        ),
                        _PreferenceTile(
                          icon: Icons.shield_outlined,
                          title: 'Default Tone Target',
                          subtitle:
                              '${_tones[profile.toneIndex]} · named messages only',
                          trailing: const Icon(
                            Icons.tune,
                            size: 16,
                            color: _kTextSecondary,
                          ),
                          onTap: () {
                            ref.read(userProfileProvider.notifier).cycleTone();
                          },
                        ),
                        const Divider(height: 1, color: _kBorderSubtle),
                        _PreferenceTile(
                          icon: Icons.logout,
                          title: AppStrings.logout,
                          subtitle: 'Signs you out on this device',
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: _kTextTertiary,
                          ),
                          onTap: () {
                            ref.read(sessionProvider.notifier).logout();
                          },
                        ),
                        const Divider(height: 1, color: _kBorderSubtle),
                        _PreferenceTile(
                          icon: Icons.password,
                          title: AppStrings.changePassword,
                          subtitle: AppStrings.changePasswordSubtitle,
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: _kTextTertiary,
                          ),
                          onTap: _openChangePassword,
                        ),
                        const Divider(height: 1, color: _kBorderSubtle),
                        _PreferenceTile(
                          icon: Icons.devices_other,
                          title: AppStrings.logoutAll,
                          subtitle: AppStrings.logoutAllSubtitle,
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: _kTextTertiary,
                          ),
                          onTap: _confirmLogoutAll,
                        ),
                        const Divider(height: 1, color: _kBorderSubtle),
                        _PreferenceTile(
                          icon: Icons.delete_outline,
                          title: AppStrings.deleteAccount,
                          subtitle: AppStrings.deleteAccountSubtitle,
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: _kTextTertiary,
                          ),
                          onTap: _confirmDeleteAccount,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Helper Components ────────────────────────────────────────────────────────

class _PresetAvatarOption extends StatelessWidget {
  const _PresetAvatarOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPrimary,
              border: Border.all(
                color: isSelected ? _kPrimary : _kBorderSubtle,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: child,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? _kTextPrimary : _kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the anonymity card: who sees what.
class _WhoSeesRow extends StatelessWidget {
  const _WhoSeesRow({required this.who, required this.what, required this.tag});

  final String who;
  final String what;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$who ',
            style: const TextStyle(fontSize: 11, color: _kTextTertiary),
          ),
          Expanded(
            child: Text(
              what,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kSurfaceMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag,
              style: const TextStyle(fontSize: 10, color: _kTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialBadge extends StatelessWidget {
  const _SocialBadge({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kSurfaceMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kBorderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: _kTextSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _kTextPrimary,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 13, color: _kTextSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExperienceItem extends StatelessWidget {
  const _ExperienceItem({
    required this.experience,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfileExperience experience;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _kSurfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorderSubtle),
          ),
          child: const Icon(Icons.work_outline, size: 18, color: _kPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      experience.role,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: _kTextSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                experience.company,
                style: const TextStyle(fontSize: 12, color: _kTextSecondary),
              ),
              const SizedBox(height: 1),
              Text(
                '${experience.duration} • ${experience.location}',
                style: const TextStyle(fontSize: 11, color: _kTextTertiary),
              ),
              if (experience.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  experience.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EducationItem extends StatelessWidget {
  const _EducationItem({
    required this.education,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfileEducation education;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _kSurfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorderSubtle),
          ),
          child: const Icon(Icons.school_outlined, size: 18, color: _kPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      education.school,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: _kTextSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${education.degree} (${education.duration})',
                style: const TextStyle(fontSize: 12, color: _kTextSecondary),
              ),
              if (education.details.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  education.details,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EditProfileTextField extends StatelessWidget {
  const _EditProfileTextField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: _kSurfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorderSubtle),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 13, color: _kTextPrimary),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 16, color: _kTextTertiary),
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: _kTextTertiary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  const _GridPatternPainter({this.isDark = false});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Brand.border.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final IconData icon;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: _kTextSecondary,
                ),
              ),
              Icon(icon, size: 16, color: _kTextSecondary),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: _kTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: _kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _kTextSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

String _userInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'AM';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Asks for the password, then deletes the account. Stays open with the
/// error when the server refuses, so a typo never signs the user out.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = AppStrings.missingCredentials);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .deleteAccount(password: _password.text);
      if (mounted) Navigator.of(context).pop();
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        AppStrings.deleteAccount,
        style: TextStyle(fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.deleteAccountBody,
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            enabled: !_busy,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: AppStrings.passwordLabel,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _delete(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _delete,
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(AppStrings.deleteAccount),
        ),
      ],
    );
  }
}

/// Current password plus the new one twice. Stays open on errors.
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_current.text.isEmpty) {
      setState(() => _error = AppStrings.missingCredentials);
      return;
    }
    if (_next.text.length < 8) {
      setState(() => _error = AppStrings.passwordTooShort);
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = AppStrings.passwordsDontMatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, List<String> hints) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: true,
        enabled: !_busy,
        autofillHints: hints,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        AppStrings.changePassword,
        style: TextStyle(fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_current, AppStrings.currentPasswordLabel, const [
            AutofillHints.password,
          ]),
          _field(_next, AppStrings.resetNewPasswordLabel, const [
            AutofillHints.newPassword,
          ]),
          _field(_confirm, AppStrings.confirmNewPasswordLabel, const [
            AutofillHints.newPassword,
          ]),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12.5),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: Brand.accent),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(AppStrings.changePassword),
        ),
      ],
    );
  }
}

/// Confirms ending every session; signs out here on success.
class _LogoutAllDialog extends ConsumerStatefulWidget {
  const _LogoutAllDialog();

  @override
  ConsumerState<_LogoutAllDialog> createState() => _LogoutAllDialogState();
}

class _LogoutAllDialogState extends ConsumerState<_LogoutAllDialog> {
  var _busy = false;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).logoutAll();
      if (mounted) Navigator.of(context).pop();
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.logoutAll, style: TextStyle(fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.logoutAllBody,
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12.5),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _go,
          style: FilledButton.styleFrom(backgroundColor: Brand.accent),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(AppStrings.logoutAll),
        ),
      ],
    );
  }
}
