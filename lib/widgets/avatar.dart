import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Round avatar. Uses a photo URL when available, otherwise initials on a
/// color, otherwise the default person or group icon (as in the designs).
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.size = 54,
    this.color,
    this.photoUrl,
    this.isGroup = false,
    this.isOnline = false,
    this.onlineDotSize,
  });

  final String name;
  final double size;
  final Color? color;
  final String? photoUrl;
  final bool isGroup;
  final bool isOnline;
  final double? onlineDotSize;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    Widget circle;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      circle = CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(photoUrl!),
      );
    } else if (color != null) {
      circle = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.18)!, color!],
          ),
        ),
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.34,
          ),
        ),
      );
    } else {
      circle = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentSoft,
        ),
        child: Icon(
          isGroup ? Icons.groups_rounded : Icons.person_rounded,
          color: AppColors.accent,
          size: size * 0.5,
        ),
      );
    }

    if (!isOnline) return circle;
    final dot = onlineDotSize ?? size * 0.24;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: size * 0.02,
            bottom: size * 0.02,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: dot * 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill used for unread counts and nav badges.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.size = 24});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(size),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Rounded search field used at the top of the Chats and Calls lists.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, this.onChanged});

  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.meta, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: AppColors.body, size: 24),
          filled: true,
          fillColor: const Color(0xFFF7F5FB),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFDCD7E6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// Filter chip row (All / Unread / Groups / Archived and the call filters).
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.filledInactive = false,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Calls design shows grey pills for inactive chips; Chats shows plain text.
  final bool filledInactive;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelected(values[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: filledInactive ? 22 : 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: values[i] == selected
                        ? AppColors.accent
                        : (filledInactive
                              ? const Color(0xFFF1EEF6)
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: values[i] == selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: values[i] == selected
                          ? Colors.white
                          : AppColors.body,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
