import 'package:flutter/material.dart';

class TreatmentsPage extends StatefulWidget {
  const TreatmentsPage({super.key});

  @override
  State<TreatmentsPage> createState() => _TreatmentsPageState();
}

class _TreatmentsPageState extends State<TreatmentsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(final BuildContext context) {
    super.build(context);
    print('TreatmentsPage bui');
    return const Center(child: Text('trats'));
  }
}
