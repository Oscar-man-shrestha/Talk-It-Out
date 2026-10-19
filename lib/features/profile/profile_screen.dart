import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/utils/image_picker_helper.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/core/widgets/safe_image.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/profile/profile_state.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Color(0xFF09090B);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kSurfaceSubtle = Color(0xFFFAFAFA);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _salts = [
    '#7b99c8f2...9f2a',
    '#3e41b99a...6d8c',
    '#91a0c842...4aa1',
    '#19fec390...7e0b',
  ];

  static const _tones = [
    'Professional & Diplomatic',
    'Direct & Concise',
    'Socratic & Inquisitive',
    'Empathetic & Supportive',
  ];

  static const _presetAvatars = [
    (
      'Maya Lin',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
    ),
    (
      'Julian V.',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&q=80',
    ),
    (
      'Priya S.',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=256&q=80',
    ),
    (
      'Elena V.',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=256&q=80',
    ),
    (
      'Alex M.',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=256&q=80',
    ),
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
                              'Edit Public Profile (LinkedIn Style)',
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
                            child: const Text(
                              'AM',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          for (final preset in _presetAvatars) ...[
                            const SizedBox(width: 8),
                            _PresetAvatarOption(
                              label: preset.$1,
                              isSelected: selectedAvatar == preset.$2,
                              onTap: () {
                                setModalState(() {
                                  selectedAvatar = preset.$2;
                                  avatarCtrl.text = preset.$2;
                                });
                              },
                              child: ClipOval(
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: SafeImage(imageUrl: preset.$2),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Custom Photo URL
                    _EditProfileTextField(
                      label: 'Or Custom Image / Photo URL',
                      controller: avatarCtrl,
                      hint: 'https://images.unsplash.com/... or photo URL',
                      icon: Icons.link,
                      onChanged: (val) {
                        setModalState(() {
                          selectedAvatar = val.trim().isEmpty
                              ? null
                              : val.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Full Name
                    _EditProfileTextField(
                      label: 'Full Name',
                      controller: nameCtrl,
                      hint: 'Priya Sharma',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),

                    // Headline
                    _EditProfileTextField(
                      label: 'Professional Headline',
                      controller: headlineCtrl,
                      hint: 'Staff Privacy Architect • Zero-Knowledge Systems',
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
                                    ? 'Priya Sharma'
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
                    const SizedBox(height: 12),

                    // Custom URL Input
                    _EditProfileTextField(
                      label: 'Or Custom Image URL',
                      controller: coverUrlCtrl,
                      hint: 'https://images.unsplash.com/... or any image link',
                      icon: Icons.link,
                      onChanged: (val) {
                        setModalState(() {
                          currentCoverUrl = val.trim().isEmpty
                              ? null
                              : val.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

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
                hint: 'Specialization in Applied Cryptography & Distributed Systems',
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
            hintText: 'e.g. Zero-Knowledge Proofs, Flutter, Rust',
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.value;
    final profile = ref.watch(userProfileProvider);
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
                    tooltip: 'Share Public Profile',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Public Profile Link copied!'),
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
                    color: Colors.black,
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
                                        : const Color(0xFFF4F4F5)),
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
                                      'ZK-SHIELDED',
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
                                    '(she/her) • ${user.email ?? 'priya@example.com'}',
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
                                  const Text(
                                    '1,420+ peer connections',
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
                                children: [
                                  _SocialBadge(
                                    icon: Icons.public,
                                    label: profile.linkedinUrl.isNotEmpty
                                        ? profile.linkedinUrl
                                        : 'LinkedIn',
                                    onTap: _openEditProfileModal,
                                  ),
                                  _SocialBadge(
                                    icon: Icons.code,
                                    label: profile.githubUrl.isNotEmpty
                                        ? profile.githubUrl
                                        : 'GitHub',
                                    onTap: _openEditProfileModal,
                                  ),
                                  _SocialBadge(
                                    icon: Icons.language,
                                    label: 'Portfolio',
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

                  // 5. Peer Anonymity Shield Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kSurfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PEER ANONYMITY SHIELD',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: _kTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Ephemeral mask active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _kTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                ref
                                    .read(userProfileProvider.notifier)
                                    .rotateSalt();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kSurface,
                                foregroundColor: _kTextPrimary,
                                elevation: 0.5,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                              icon: const Icon(Icons.sync, size: 14),
                              label: const Text(
                                'Rotate',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _kSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'SALT: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: _kTextTertiary,
                                    ),
                                  ),
                                  Text(
                                    _salts[profile.saltIndex],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _kSurfaceMuted,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '12h left',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _kTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 6. Metrics 2x2 Bento Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.35,
                    children: [
                      const _BentoCard(
                        title: 'GROUPS JOINED',
                        icon: Icons.groups_outlined,
                        value: '14',
                        subtitle: 'active squads',
                      ),
                      const _BentoCard(
                        title: 'CONTRIBUTIONS',
                        icon: Icons.forum_outlined,
                        value: '38',
                        subtitle: '+5 this week',
                      ),
                      Container(
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
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'AI CLARITY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: _kTextSecondary,
                                  ),
                                ),
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: _kTextSecondary,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '94%',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                        color: _kTextPrimary,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Top 5%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _kTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 4,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _kSurfaceMuted,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: 0.94,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _kPrimary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Diplomatic clarity',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _kTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const _BentoCard(
                        title: 'MODERATED',
                        icon: Icons.gavel_outlined,
                        value: '3',
                        subtitle: 'squad spaces',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 7. Cryptographic Privacy Guarantee Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorderSubtle),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: _kTextPrimary,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cryptographic Decoupling Active',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Your true identity is cryptographically separated from group submissions. Only you and designated controllers see designated audit metadata.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: _kTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                          subtitle: _tones[profile.toneIndex],
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
                          subtitle:
                              'Terminates secure session tokens on device',
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: _kTextTertiary,
                          ),
                          onTap: () {
                            ref.read(sessionProvider.notifier).logout();
                          },
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
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;

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
            onChanged: onChanged,
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
          : const Color(0xFFE4E4E7).withValues(alpha: 0.6)
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
