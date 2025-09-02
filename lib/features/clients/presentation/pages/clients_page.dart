import 'package:flutter/material.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true; // Keep this page alive.

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin.
    print('ClientsPage build');
    return ListView.builder(
      key: const PageStorageKey('clients_list'), // Preserve scroll offset.
      controller: _scroll,
      itemCount: 100,
      itemBuilder: (_, i) => ListTile(title: Text('Client #$i')),
    );
  }
}
