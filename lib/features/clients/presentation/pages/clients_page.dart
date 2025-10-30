import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final log = AppLogger.getLogger(name: 'ClientsPage');

  late final ScrollController _scrollController;
  late final double _scrollbarThickness;
  var _isScrollbarNeeded = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollbarThickness = kIsWindows ? 8.0 : 0.0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    super.build(context);

    if (_scrollbarThickness > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final isNeeded =
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0;
        if (isNeeded != _isScrollbarNeeded && mounted) {
          setState(() => _isScrollbarNeeded = isNeeded);
        }
      });
    }

    log.fine('build');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: kIsWindows ? 10 : 0),
      child: Scrollbar(
        controller: _scrollController,
        thickness: _scrollbarThickness,
        thumbVisibility: kIsWindows,
        interactive: kIsWindows,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: AnimatedPadding(
            duration: kDefaultAppAnimationsDuration,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(
              kIsWindows ? 16 : 8.w,
              0,
              (kIsWindows ? 16 : 8.w) +
                  (_isScrollbarNeeded ? _scrollbarThickness : 0),
              0,
            ),
            child: Column(
              children: [
                SizedBox(height: kIsWindows ? 8 : 8.h),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 100,
                  itemBuilder: (_, final i) =>
                      ListTile(title: Text('Client #$i')),
                ),
                SizedBox(
                  height: kIsWindows ? 0 : kBottomNavigationBarHeight + 28.h,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
