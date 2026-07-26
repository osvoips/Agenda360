import 'package:flutter/material.dart';

/// Padrão repetido em toda tela que busca dados na API: mostra um spinner
/// enquanto carrega, uma mensagem de erro com "Tentar novamente" se falhar,
/// e o conteúdo via [builder] quando os dados chegam.
class FutureLoader<T> extends StatefulWidget {
  const FutureLoader({super.key, required this.future, required this.builder});

  final Future<T> Function() future;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<FutureLoader<T>> createState() => _FutureLoaderState<T>();
}

class _FutureLoaderState<T> extends State<FutureLoader<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.future();
  }

  void _retry() {
    setState(() {
      _future = widget.future();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _retry, child: const Text('Tentar novamente')),
                ],
              ),
            ),
          );
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}
