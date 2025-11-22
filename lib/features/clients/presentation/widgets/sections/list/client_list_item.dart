import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../../../../core/constants/app_constants.dart';
import '../../../../../../core/database/app_database.dart';
import '../../../../../../core/widgets/contact_actions_dialogs.dart';

class ClientListItem extends StatelessWidget {
  const ClientListItem({
    required this.client,
    required this.onTap,
    this.index = 1,
    super.key,
  });

  final Client client;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      // Importante se usato in liste custom
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child:
          InkWell(
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
                      // Avatar
                      CircleAvatar(
                        radius: kIsWindows ? 28 : 26.sp,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          '${client.firstName[0]}${client.lastName[0]}',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: kIsWindows ? 24 : 22.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: kIsWindows ? 16 : 8.w),
                      // Client Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            Text(
                              '${client.firstName} ${client.lastName}',
                              style: TextStyle(
                                fontSize: kIsWindows ? 20 : 20.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: kIsWindows ? 4 : 4.h),
                            // Phone
                            InkWell(
                              onTap: () => ContactActions.showPhoneActionDialog(
                                context,
                                client.phoneNumber,
                              ),
                              borderRadius: BorderRadius.circular(
                                kIsWindows ? 4 : 4.r,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: kIsWindows ? 2 : 2.h,
                                  horizontal: kIsWindows ? 2 : 2.w,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Symbols.phone_rounded,
                                      size: kIsWindows ? 16 : 14.sp,
                                      color: colorScheme.primary,
                                    ),
                                    SizedBox(width: kIsWindows ? 6 : 6.w),
                                    Flexible(
                                      child: Text(
                                        client.phoneNumber,
                                        style: TextStyle(
                                          fontSize: kIsWindows ? 16 : 14.sp,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Email
                            if (client.email != null) ...[
                              SizedBox(height: kIsWindows ? 2 : 2.h),
                              InkWell(
                                onTap: () => ContactActions.openEmail(
                                  context,
                                  client.email!,
                                ),
                                borderRadius: BorderRadius.circular(
                                  kIsWindows ? 4 : 4.r,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: kIsWindows ? 2 : 2.h,
                                    horizontal: kIsWindows ? 2 : 2.w,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Symbols.email_rounded,
                                        size: kIsWindows ? 16 : 14.sp,
                                        color: colorScheme.primary,
                                      ),
                                      SizedBox(width: kIsWindows ? 6 : 6.w),
                                      Flexible(
                                        child: Text(
                                          client.email!,
                                          style: TextStyle(
                                            fontSize: kIsWindows ? 16 : 14.sp,
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                      SizedBox(width: kIsWindows ? 16 : 16.w),
                      Icon(
                        Symbols.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: kIsWindows ? 24 : 24.sp,
                        weight: 600,
                      ),
                    ],
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
              ),
    );
  }
}
