import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../domain/entities/meal_type.dart';
import '../providers/meal_photo_provider.dart';

/// 拍照组件 - 用于记录饮食
class PhotoCapture extends ConsumerStatefulWidget {
  final MealType mealType;
  final Function(String imagePath)? onPhotoTaken;

  const PhotoCapture({
    super.key,
    required this.mealType,
    this.onPhotoTaken,
  });

  @override
  ConsumerState<PhotoCapture> createState() => _PhotoCaptureState();
}

class _PhotoCaptureState extends ConsumerState<PhotoCapture> {
  String? _imagePath;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '拍摄${getMealTypeName(widget.mealType)}',
          style: const TextStyle(
            fontSize: AppTheme.textSizeNormal,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: _imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    child: Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '点击拍照或选择照片',
                          style: TextStyle(
                            fontSize: AppTheme.textSizeSmall,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 32),
              title: const Text('拍照', style: TextStyle(fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 32),
              title: const Text('从相册选择', style: TextStyle(fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete, size: 32, color: Colors.red),
                title: const Text('删除照片',
                    style: TextStyle(fontSize: 18, color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _imagePath = null);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final notifier = ref.read(mealPhotoProvider.notifier);
    final record = await notifier.takePhoto(widget.mealType);

    if (record != null && mounted) {
      setState(() => _imagePath = record.imagePath);
      widget.onPhotoTaken?.call(record.imagePath);

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('拍照成功！饭后 30 分钟将提醒您吃药'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final notifier = ref.read(mealPhotoProvider.notifier);
    final record = await notifier.pickFromGallery(widget.mealType);

    if (record != null && mounted) {
      setState(() => _imagePath = record.imagePath);
      widget.onPhotoTaken?.call(record.imagePath);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('照片已保存！饭后 30 分钟将提醒您吃药'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

/// 餐型选择器
class MealTypeSelector extends StatelessWidget {
  final MealType selectedType;
  final ValueChanged<MealType> onTypeChange;

  const MealTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: MealType.values.map((type) {
        final isSelected = type == selectedType;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(getMealTypeName(type)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onTypeChange(type);
                }
              },
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: AppTheme.textSizeSmall,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
