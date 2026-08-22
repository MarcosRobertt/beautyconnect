import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../controllers/servico_controller.dart';
import '../models/servico.dart';

class ServicoFormScreen extends ConsumerStatefulWidget {
  const ServicoFormScreen({super.key, this.servicoId});

  final String? servicoId;

  @override
  ConsumerState<ServicoFormScreen> createState() => _ServicoFormScreenState();
}

class _ServicoFormScreenState extends ConsumerState<ServicoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _duracaoController = TextEditingController(text: '30');

  // Cores originais + 8 Novas Cores
  static const List<Color> coresDisponiveis = [
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFF795548),
    Color(0xFF607D8B),
    // 8 Novas Cores
    Color(0xFFFF80AB),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
    Color(0xFF81C784),
    Color(0xFFFFD54F),
    Color(0xFFFF8A65),
    Color(0xFFA1887F),
    Color(0xFF37474F),
  ];

  Color _corSelecionada = coresDisponiveis.first;
  bool _carregando = true;
  Servico? _servicoOriginal;

  bool get _editando => widget.servicoId != null;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (_editando) {
      final servicosAsync = ref.read(servicoControllerProvider);
      final servicos = servicosAsync.value ?? [];
      for (final s in servicos) {
        if (s.id == widget.servicoId) {
          _servicoOriginal = s;
          _nomeController.text = s.nome;
          _valorController.text = s.valor.toString();
          _duracaoController.text = s.duracaoMin.toString();
          _corSelecionada = Color(s.corValor);
          break;
        }
      }
    }
    setState(() => _carregando = false);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    _duracaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final nome = _nomeController.text.trim();
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;
    final duracao = int.tryParse(_duracaoController.text) ?? 30;

    final novoServico = _editando
        ? _servicoOriginal!.copyWith(
            nome: nome,
            valor: valor,
            duracaoMin: duracao,
            corValor: _corSelecionada.value,
          )
        : Servico(
            id: const Uuid().v4(),
            nome: nome,
            valor: valor,
            duracaoMin: duracao,
            corValor: _corSelecionada.value,
            createdAt: DateTime.now(),
          );

    final erro = await ref
        .read(servicoControllerProvider.notifier)
        .salvar(novoServico);

    if (mounted) {
      if (erro != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro.toString()), backgroundColor: Colors.red),
        );
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Serviço' : 'Novo Serviço'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do serviço'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valorController,
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o valor.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _duracaoController,
                decoration: const InputDecoration(labelText: 'Duração padrão (minutos)'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe a duração.' : null,
              ),
              const SizedBox(height: 20),
              const Text('Cor de identificação na agenda:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: coresDisponiveis.map((cor) {
                  final selecionada = _corSelecionada.value == cor.value;
                  return GestureDetector(
                    onTap: () => setState(() => _corSelecionada = cor),
                    child: CircleAvatar(
                      backgroundColor: cor,
                      radius: 18,
                      child: selecionada
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _salvar,
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
