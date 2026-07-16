import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../controllers/servico_controller.dart';
import '../models/servico.dart';

/// Paleta fixa e pequena de cores para identificar serviços na Agenda.
/// Simples de propósito — o objetivo é dar identidade visual rápida, não um
/// seletor de cor completo.
const _paletaCores = <Color>[
  Color(0xFF8C2F5C), // berry (cor primária do app)
  Color(0xFF3A5FCD), // azul
  Color(0xFF2E7D4F), // verde
  Color(0xFF8A5A00), // âmbar
  Color(0xFFBA1A4A), // vermelho
  Color(0xFF6D5FD1), // roxo
  Color(0xFF00838F), // teal
  Color(0xFFB8574F), // terracota
];

class ServicoFormScreen extends ConsumerStatefulWidget {
  const ServicoFormScreen({super.key, this.servicoId});

  final String? servicoId;

  @override
  ConsumerState<ServicoFormScreen> createState() => _ServicoFormScreenState();
}

class _ServicoFormScreenState extends ConsumerState<ServicoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _duracaoController = TextEditingController(text: '30');
  final _valorController = TextEditingController(text: '0');
  Color _corSelecionada = _paletaCores.first;
  Servico? _original;
  bool _carregando = true;

  bool get _editando => widget.servicoId != null;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (_editando) {
      final servico = await ref.read(servicoControllerProvider.notifier).buscar(widget.servicoId!);
      if (servico != null) {
        _original = servico;
        _nomeController.text = servico.nome;
        _duracaoController.text = servico.duracaoMin.toString();
        _valorController.text = servico.valor.toString();
        _corSelecionada = Color(servico.corValor);
      }
    }
    setState(() => _carregando = false);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _duracaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final duracao = int.tryParse(_duracaoController.text) ?? 30;
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;

    final servico = _editando
        ? _original!.copyWith(
            nome: _nomeController.text.trim(),
            duracaoMin: duracao,
            valor: valor,
            corValor: _corSelecionada.value,
          )
        : Servico(
            id: const Uuid().v4(),
            nome: _nomeController.text.trim(),
            duracaoMin: duracao,
            valor: valor,
            corValor: _corSelecionada.value,
            createdAt: DateTime.now(),
          );

    if (_editando) {
      await ref.read(servicoControllerProvider.notifier).editar(servico);
    } else {
      await ref.read(servicoControllerProvider.notifier).salvar(servico);
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar Serviço' : 'Novo Serviço')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome é obrigatório.' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _duracaoController,
                          decoration: const InputDecoration(labelText: 'Duração (min) *'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return (n == null || n <= 0) ? 'Informe uma duração válida.' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _valorController,
                          decoration: const InputDecoration(labelText: 'Valor (R\$) *'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Cor na Agenda', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _paletaCores.map((cor) {
                      final selecionada = cor.value == _corSelecionada.value;
                      return InkWell(
                        onTap: () => setState(() => _corSelecionada = cor),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cor,
                            shape: BoxShape.circle,
                            border: selecionada ? Border.all(color: Colors.black87, width: 2) : null,
                          ),
                          child: selecionada ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton(onPressed: _salvar, child: const Text('Salvar'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
