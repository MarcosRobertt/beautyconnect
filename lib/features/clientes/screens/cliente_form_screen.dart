import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';

/// Tela Novo/Editar Cliente.
/// Regras (conforme documento técnico): Nome obrigatório, Telefone
/// obrigatório, Aniversário opcional.
class ClienteFormScreen extends ConsumerStatefulWidget {
  const ClienteFormScreen({super.key, this.clienteId});

  final String? clienteId;

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _observacoesController = TextEditingController();
  DateTime? _aniversario;
  Cliente? _clienteOriginal;
  bool _carregando = true;

  bool get _editando => widget.clienteId != null;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (_editando) {
      final cliente = await ref.read(clienteControllerProvider.notifier).buscar(widget.clienteId!);
      if (cliente != null) {
        _clienteOriginal = cliente;
        _nomeController.text = cliente.nome;
        _telefoneController.text = cliente.telefone;
        _observacoesController.text = cliente.observacoes;
        _aniversario = cliente.aniversario;
      }
    }
    setState(() => _carregando = false);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final cliente = _editando
        ? _clienteOriginal!.copyWith(
            nome: _nomeController.text.trim(),
            telefone: _telefoneController.text.trim(),
            aniversario: _aniversario,
            observacoes: _observacoesController.text.trim(),
          )
        : Cliente(
            id: const Uuid().v4(),
            nome: _nomeController.text.trim(),
            telefone: _telefoneController.text.trim(),
            aniversario: _aniversario,
            observacoes: _observacoesController.text.trim(),
            createdAt: DateTime.now(),
          );

    if (_editando) {
      await ref.read(clienteControllerProvider.notifier).editar(cliente);
    } else {
      await ref.read(clienteControllerProvider.notifier).salvar(cliente);
    }

    if (mounted) context.pop();
  }

  Future<void> _selecionarAniversario() async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _aniversario ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selecionada != null) setState(() => _aniversario = selecionada);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar Cliente' : 'Novo Cliente')),
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
                  TextFormField(
                    controller: _telefoneController,
                    decoration: const InputDecoration(labelText: 'WhatsApp *'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'WhatsApp é obrigatório.' : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _selecionarAniversario,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Data de nascimento (opcional)'),
                      child: Text(_aniversario == null ? 'Selecionar data' : DateFormat('dd/MM/yyyy').format(_aniversario!)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observacoesController,
                    decoration: const InputDecoration(labelText: 'Observações'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancelar')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(onPressed: _salvar, child: const Text('Salvar')),
                      ),
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
