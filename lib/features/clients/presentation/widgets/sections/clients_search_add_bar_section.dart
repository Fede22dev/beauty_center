import 'package:beauty_center/core/connectivity/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/providers/supabase_auth_provider.dart';

class SectionSearchAddBar extends ConsumerStatefulWidget {
  const SectionSearchAddBar({
    required this.onSearchChanged,
    required this.onAddClient,
    super.key,
  });

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddClient;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SectionSearchAddBarState();
}

class _SectionSearchAddBarState extends ConsumerState<SectionSearchAddBar> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearchChanged('');
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOffline = ref.watch(isConnectionUnusableProvider);
    final isDisconnectedSup = ref.watch(supabaseAuthProvider).isDisconnected;

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cerca cliente',
                prefixIcon: Icon(
                  Symbols.search_rounded,
                  size: kIsWindows ? 22 : 22.sp,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Symbols.clear_rounded,
                          size: kIsWindows ? 20 : 20.sp,
                        ),
                        onPressed: _clearSearch,
                        tooltip: 'Pulisci ricerca',
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: kIsWindows ? 2 : 2.w,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 16 : 16.w,
                  vertical: kIsWindows ? 16 : 14.h,
                ),
              ),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: kIsWindows ? 16 : 16.sp,
                fontWeight: FontWeight.w400,
              ),
              onSubmitted: (_) => _searchFocusNode.unfocus(),
            ),
          ),
          SizedBox(width: kIsWindows ? 12 : 12.w),
          // Add Client Button
          Material(
            color: (isOffline || isDisconnectedSup)
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
            child: InkWell(
              onTap: (isOffline || isDisconnectedSup)
                  ? null
                  : widget.onAddClient,
              borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
              child: Container(
                padding: EdgeInsets.all(kIsWindows ? 16 : 14.sp),
                child: Icon(
                  Symbols.person_add_rounded,
                  color: (isOffline || isDisconnectedSup)
                      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.5)
                      : colorScheme.onPrimaryContainer,
                  size: kIsWindows ? 24 : 24.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
