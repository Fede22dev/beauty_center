import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/counter_bloc.dart';
import '../bloc/counter_event.dart';
import '../bloc/counter_state.dart';

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CounterBloc(),
      child: const CounterView(),
    );
  }
}

class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CounterBloc, CounterState>(
      listener: (context, state) {
        if (state.value == 10) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Hai raggiunto 10!")));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Counter")),
        body: Center(
          child: BlocBuilder<CounterBloc, CounterState>(
            builder: (context, state) {
              return Text(
                "${state.value}",
                style: const TextStyle(fontSize: 48),
              );
            },
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "inc",
              onPressed: () =>
                  context.read<CounterBloc>().add(IncrementCounter()),
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: "dec",
              onPressed: () =>
                  context.read<CounterBloc>().add(DecrementCounter()),
              child: const Icon(Icons.remove),
            ),
          ],
        ),
      ),
    );
  }
}
