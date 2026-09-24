import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

/// أفاتار قابل للنقر لرفع/تغيير صورة البروفايل. بيرفع الصورة على
/// Firebase Storage تحت profile_photos/{userId}.jpg، وبيحدّث photoURL
/// في مستند المستخدم أوتوماتيك.
class ProfileAvatar extends StatefulWidget {
  final AppUser user;
  final double radius;
  const ProfileAvatar({super.key, required this.user, this.radius = 40});

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool uploading = false;
  String? localPhotoUrl;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
    );
    if (picked == null) return;

    setState(() => uploading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${widget.user.id}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseService.instance.updatePhotoUrl(widget.user.id, url);
      if (mounted) setState(() => localPhotoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر رفع الصورة: $e')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = localPhotoUrl ?? widget.user.photoURL;
    return GestureDetector(
      onTap: uploading ? null : _pickAndUpload,
      child: Stack(
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: AppColors.primary,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(widget.user.name.isNotEmpty ? widget.user.name[0] : '؟',
                    style: TextStyle(color: Colors.white, fontSize: widget.radius * 0.75))
                : null,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
              child: uploading
                  ? const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
