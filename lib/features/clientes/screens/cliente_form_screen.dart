import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';

/// Tela Novo/Editar Cliente.
/// Regras: Nome obrigatório, Telefone obrigatório, Aniversário e Profissão opcionais.
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
  final _profissaoController = TextEditingController(); 
  final _observacoesController = TextEditingController();
  
  DateTime? _aniversario;
  Cliente? _clienteOriginal;
  bool _carregando = true;
  String? _erro; // Guarda a mensagem de erro da validação de telefone

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
        _profissaoController.text = cliente.profissao ?? ''; 
      }
    }
    setState(() => _carregando = false);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _profissaoController.dispose(); 
    _observacoesController.dispose();
    super.dispose();
  }

  // --- FUNÇÕES DE HIGIENIZAÇÃO DE DADOS ---
  String _sanitizarTelefone(String fone) {
    String digitos = fone.replaceAll(RegExp(r'\D'), '');
    if (digitos.startsWith('55') && digitos.length > 11) {
      digitos = digitos.substring(2);
    }
    return digitos;
  }

  String _sanitizarNome(String texto) {
    const comAcento = 'ÁÀÃÂÄÉÈẼÊËÍÌĨÎÏÓÒÕÔÖÚÙŨÛÜÇÑáàãâäéèẽêëíìĩîïóòõôöúùũûüçñ';
    const semAcento = 'AAAAAEEEEEIIIIIOOOOOUUUUUCNaaaaaeeeeeiiiiiooooouuuuucn';
    String str = texto.toLowerCase().trim();
    for (int i = 0; i < comAcento.length; i++) {
      str = str.replaceAll(comAcento[i], semAcento[i]);
    }
    return str.replaceAll(RegExp(r'\s+'), ' '); // Remove espaços duplos
  }

  Future<bool> _mostrarAlertaNomeParecido(String nomeExistente) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Atenção: Nome Parecido'),
        content: Text(
          'Já existe uma cliente cadastrada com o nome:\n"$nomeExistente"\n\n'
          'Deseja salvar este novo cadastro mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar e Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar mesmo assim'),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;

    // --- VALIDAÇÕES DE DUPLICIDADE ---
    final clientesCadastrados = ref.read(clienteControllerProvider).value ?? [];
    final telefoneInput = _sanitizarTelefone(_telefoneController.text);
    final nomeInput = _sanitizarNome(_nomeController.text);

    bool telefoneDuplicado = false;
    bool nomeDuplicado = false;
    String nomeConflito = '';

    for (final c in clientesCadastrados) {
      // Se for edição, ignora a própria cliente na checagem
      if (_editando && c.id == widget.clienteId) continue;

      if (_sanitizarTelefone(c.telefone) == telefoneInput) {
        telefoneDuplicado = true;
        break; 
      }
      if (_sanitizarNome(c.nome) == nomeInput) {
        nomeDuplicado = true;
        nomeConflito = c.nome;
      }
    }

    if (telefoneDuplicado) {
      setState(() => _erro = 'Este número de WhatsApp já está cadastrado em outra cliente.');
      return; // Trava rígida
    }

    if (nomeDuplicado) {
      final continuar = await _mostrarAlertaNomeParecido(nomeConflito);
      if (!continuar) return; // Se a pessoa não confirmar, cancela o salvamento
    }
    // ---------------------------------

    final cliente = _editando
        ? _clienteOriginal!.copyWith(
            nome: _nomeController.text.trim(),
            telefone: _telefoneController.text.trim(),
            profissao: _profissaoController.text.trim(),
            aniversario: _aniversario,
            observacoes: _observacoesController.text.trim(),
          )
        : Cliente(
            id: const Uuid().v4(),
            nome: _nomeController.text.trim(),
            telefone: _telefoneController.text.trim(),
            profissao: _profissaoController.text.trim(),
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

  void _confirmarExclusao() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Cliente?'),
        content: const Text(
          'Tem certeza que deseja excluir esta cliente?\n\n'
          'Caso ela possua agendamentos passados, as métricas financeiras (Dashboard) '
          'serão mantidas intactas, mas perderão a referência do nome dela.\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              // NOTA: Se o seu controller de clientes usar a palavra "remover" ou "deletar"
              // em vez de "excluir", basta alterar a chamada abaixo.
              await ref.read(clienteControllerProvider.notifier).excluir(widget.clienteId!);
              if (mounted) context.pop();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Cliente' : 'Novo Cliente'),
        actions: [
          if (_editando)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              tooltip: 'Excluir Cliente',
              onPressed: _confirmarExclusao,
            ),
        ],
      ),
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
                    textCapitalization: TextCapitalization.words,
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
                  
                  TextFormField(
                    controller: _profissaoController,
                    decoration: const InputDecoration(labelText: 'Profissão (opcional)'),
                    textCapitalization: TextCapitalization.words,
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
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                  ),
                  
                  // CAIXA DE ERRO SE O TELEFONE ESTIVER DUPLICADO
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
                    ),
                  ],

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
