import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../../core/constants/app_constants.dart';
import '../../../../../../core/database/app_database.dart';
import '../../../../../../core/tabs/app_tabs.dart';

class ProductListItem extends StatelessWidget {
  const ProductListItem({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.index = 0,
    super.key,
  });

  final ProductData product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int index;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
        child: Container(
          padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: kIsWindows ? 1 : 1.w,
            ),
            borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
                decoration: BoxDecoration(
                  color: AppTabs.products.color.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(kIsWindows ? 12 : 12.r),
                ),
                child: Icon(
                  Symbols.experiment_rounded,
                  color: AppTabs.products.color,
                  size: kIsWindows ? 28 : 28.sp,
                ),
              ),
              SizedBox(width: kIsWindows ? 16 : 8.w),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: kIsWindows ? 20 : 20.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      SizedBox(height: kIsWindows ? 2 : 2.h),
                      Text(
                        product.description!,
                        style: TextStyle(
                          fontSize: kIsWindows ? 14 : 14.sp,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: kIsWindows ? 4 : 4.h),
                    // Price
                    Row(
                      children: [
                        Icon(
                          Symbols.euro_rounded,
                          size: kIsWindows ? 16 : 14.sp,
                          color: colorScheme.primary,
                        ),
                        SizedBox(width: kIsWindows ? 4 : 4.w),
                        Text(
                          '${product.price.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: kIsWindows ? 16 : 14.sp,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: kIsWindows ? 8 : 8.w),
              // Edit button
              IconButton(
                icon: Icon(
                  Symbols.edit_rounded,
                  size: kIsWindows ? 22 : 22.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: onEdit,
                tooltip: 'Modifica',
              ),
              // Delete button
              IconButton(
                icon: Icon(
                  Symbols.delete_outline_rounded,
                  size: kIsWindows ? 22 : 22.sp,
                  color: colorScheme.error,
                ),
                onPressed: onDelete,
                tooltip: 'Elimina',
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: kDefaultAppAnimationsDuration,
          delay: (15 * index).ms,
        )
        .slideX(
          begin: 0.25,
          end: 0,
          duration: kDefaultAppAnimationsDuration,
          delay: (15 * index).ms,
          curve: Curves.easeOutCubic,
        );
  }
}
