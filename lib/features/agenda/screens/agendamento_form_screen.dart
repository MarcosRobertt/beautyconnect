import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../../clientes/models/cliente.dart';
import '../../servicos/controllers/servico_controller.dart';
import '../../servicos/models/servico.dart';
import '../controllers/agendamento_controller.dart';
import '../models/agendamento.dart';

/// Tela Novo/Editar Agendamento.
///
/// MUDANÇA (MVP validação): o serviço agora é selecionado do catálogo de
/// Serviços (em vez de texto livre), preenchendo automaticamente valor e
/// duração (hora de fim). O valor pode ainda ser ajustado manualmente no
/// momento do agendamento (ex.: desconto), mas nome e duração vêm do
/// catálogo. Regra existente preservada: não permitir horário duplicado.
class AgendamentoFormScreen extends ConsumerStatefulWidget {
  const AgendamentoFormScreen({super.key, this.agendamentoId, this.dataInicialIso, this.horaInicialStr});

  final String? agendamentoId;
  final String? dataInicialIso;
  final String? horaInicialStr;

  @override
  ConsumerState<AgendamentoFormScreen> createState() => _AgendamentoFormScreenState();
}

class _AgendamentoFormScreenState extends ConsumerState<AgendamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController(text: '0');
  final _observacaoController = TextEditingController();
  final _buscaClienteController = TextEditingController();

  String? _clienteId;
  String? _servicoId;
  String _servicoNomeOriginal = ''; // preservado se o serviço original foi excluído do catálogo
  DateTime _data = DateTime.now();
  TimeOfDay _horaInicio = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaFim = const TimeOfDay(hour: 10, minute: 0);
  Agendamento? _original;
  bool _carregando = true;
  String? _erro;

  bool get _editando => widget.agendamentoId != null;

  @override
  void initState() {
    super.initState();
    if (widget.dataInicialIso != null) {
      _data = DateTime.tryParse(widget.dataInicialIso!) ?? DateTime.now();
    }
    _carregar();
  }

  Future<void> _carregar() async {
    if (_editando) {
      final todos = await ref.read(agendamentoControllerProvider.notifier).todos();
      Agendamento? ag;
      for (final a in todos) {
        if (a.id == widget.agendamentoId) {
          ag = a;
          break;
        }
      }
      if (ag != null) {
        _original = ag;
        _clienteId = ag.clienteId;
        _servicoId = ag.servicoId;
        _servicoNomeOriginal = ag.servico;
        _data = ag.data;
        _horaInicio = _parseHora(ag.horaInicio);
        _horaFim = _parseHora(ag.horaFim);
        _valorController.text = ag.valor.toString();
        _observacaoController.text = ag.observacao;
      }
    }
    setState(() => _carregando = false);
  }

  TimeOfDay _parseHora(String hhmm) {
    final partes = hhmm.split(':');
    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  String _formatarHora(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  TimeOfDay _somarMinutos(TimeOfDay hora, int minutos) {
    final total = (hora.hour * 60 + hora.minute + minutos) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  bool get _horaFimDepoisDoInicio =>
      (_horaFim.hour * 60 + _horaFim.minute) > (_horaInicio.hour * 60 + _horaInicio.minute);

  void _selecionarServico(Servico servico) {
    setState(() {
      _servicoId = servico.id;
      _valorController.text = servico.valor.toString();
      _horaFim = _somarMinutos(_horaInicio, servico.duracaoMin);
    });
  }

  Future<void> _selecionarData() async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selecionada != null) setState(() => _data = selecionada);
  }

  Future<void> _selecionarHora({required bool inicio}) async {
    final selecionada = await showTimePicker(context: context, initialTime: inicio ? _horaInicio : _horaFim);
    if (selecionada != null) {
      setState(() => inicio ? _horaInicio = selecionada : _horaFim = selecionada);
    }
  }

  /// Calcula a duração em minutos entre horaInicio e horaFim
  int _calcularDuracaoEmMinutos(TimeOfDay inicio, TimeOfDay fim) {
    final minInicio = inicio.hour * 60 + inicio.minute;
    final minFim = fim.hour * 60 + fim.minute;
    return minFim - minInicio;
  }

  /// Mostra alerta quando a duração selecionada for diferente da duração do serviço
  Future<bool> _mostrarAlertaDuracao(
    BuildContext context,
    String nomeServico,
    int duracaoServico,
    int duracaoSelecionada,
  ) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Atenção'),
        content: Text(
          'O serviço "$nomeServico" possui duração prevista de $duracaoServico minutos.\n\n'
          'O horário selecionado ocupa $duracaoSelecionada minutos.\n\n'
          'Deseja continuar mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar e ajustar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    if (_clienteId == null) {
      setState(() => _erro = 'Selecione um cliente.');
      return;
    }
    if (_servicoId == null) {
      setState(() => _erro = 'Selecione um serviço.');
      return;
    }
    if (!_horaFimDepoisDoInicio) {
      setState(() => _erro = 'A hora de fim deve ser depois da hora de início.');
      return;
    }

    final servicos = ref.read(servicoControllerProvider).value ?? [];
    Servico? servicoEscolhido;
    for (final s in servicos) {
      if (s.id == _servicoId) {
        servicoEscolhido = s;
        break;
      }
    }

    // Validar duração
    if (servicoEscolhido != null) {
      final duracaoSelecionada = _calcularDuracaoEmMinutos(_horaInicio, _horaFim);
      final duracaoServico = servicoEscolhido.duracaoMin;
      if (duracaoSelecionada != duracaoServico) {
        final continuar = await _mostrarAlertaDuracao(
          context,
          servicoEscolhido.nome,
          duracaoServico,
          duracaoSelecionada,
        );
        if (!continuar) {
          return;
        }
      }
    }

    final nomeServico = servicoEscolhido?.nome ?? _servicoNomeOriginal;
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;

    final agendamento = _editando
        ? _original!.copyWith(
            clienteId: _clienteId,
            data: _data,
            horaInicio: _formatarHora(_horaInicio),
            horaFim: _formatarHora(_horaFim),
            servico: nomeServico,
            servicoId: _servicoId,
            valor: valor,
            observacao: _observacaoController.text.trim(),
          )
        : Agendamento(
            id: const Uuid().v4(),
            clienteId: _clienteId!,
            data: _data,
            horaInicio: _formatarHora(_horaInicio),
            horaFim: _formatarHora(_horaFim),
            servico: nomeServico,
            servicoId: _servicoId,
            valor: valor,
            status: AgendamentoStatus.agendado,
            observacao: _observacaoController.text.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

    final erro = await ref
        .read(agendamentoControllerProvider.notifier)
        .salvar(agendamento, novo: !_editando);

    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    _buscaClienteController.dispose();
    super.dispose();
  }

  /// Constrói o seletor de cliente com busca interativa.
  /// Permite filtrar por nome ou telefone em tempo real.
  Widget _construirSeletorCliente() {
    final clientesAsync = ref.watch(clienteControllerProvider);

    return clientesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro ao carregar clientes: $e'),
      data: (clientes) {
        if (clientes.isEmpty) {
          return const Text('Cadastre um cliente antes de criar um agendamento.');
        }

        // Filtrar clientes conforme o usuário digita
        final textoBusca = _buscaClienteController.text.trim().toLowerCase();
        final clientesFiltrados = textoBusca.isEmpty
            ? <Cliente>[]
            : clientes
                .where((c) =>
                    c.nome.toLowerCase().contains(textoBusca) || c.telefone.contains(textoBusca))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Campo de busca
            TextField(
              controller: _buscaClienteController,
              decoration: const InputDecoration(
                labelText: 'Cliente',
                hintText: 'Buscar cliente por nome ou telefone...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}), // Atualiza lista conforme digita
            ),
            const SizedBox(height: 8),

            // Mensagem inicial (sem texto digitado)
            if (textoBusca.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Digite o nome ou telefone para buscar uma cliente.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            // Resultados encontrados
            else if (clientesFiltrados.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final cliente = clientesFiltrados[index];
                    final selecionado = _clienteId == cliente.id;

                    return ListTile(
                      leading: selecionado ? const Icon(Icons.check_circle) : null,
                      title: Text(cliente.nome),
                      subtitle: Text(cliente.telefone),
                      selected: selecionado,
                      onTap: () {
                        setState(() {
                          _clienteId = cliente.id;
                          _buscaClienteController.clear();
                        });
                      },
                    );
                  },
                ),
              )
            // Nenhum resultado encontrado
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Center(
                      child: Text(
                        'Nenhuma cliente encontrada.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => context.push(AppRoutes.clienteNovo),
                        icon: const Icon(Icons.add),
                        label: const Text('Cadastrar nova cliente'),
                      ),
                    ),
                  ],
                ),
              ),

            // Exibir cliente selecionado
            if (_clienteId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '✓ Cliente selecionado: ${clientes.firstWhere((c) => c.id == _clienteId).nome}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final clientesAsync = ref.watch(clienteControllerProvider);
    final servicosAsync = ref.watch(servicoControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar Agendamento' : 'Novo Agendamento')),
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
                  _construirSeletorCliente(),
                  const SizedBox(height: 12),
                  servicosAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Erro ao carregar serviços: $e'),
                    data: (servicos) {
                      if (servicos.isEmpty) {
                        return const Text('Cadastre ao menos um serviço antes de criar um agendamento.');
                      }
                      // Se o serviço original foi excluído do catálogo, mostra um aviso mas não bloqueia.
                      final servicoAindaExiste = _servicoId != null && servicos.any((s) => s.id == _servicoId);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: servicoAindaExiste ? _servicoId : null,
                            decoration: const InputDecoration(labelText: 'Serviço'),
                            items: servicos
                                .map((Servico s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(backgroundColor: Color(s.corValor), radius: 6),
                                          const SizedBox(width: 8),
                                          Text('${s.nome} · ${s.duracaoMin}min'),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              final s = servicos.firstWhere((s) => s.id == v);
                              _selecionarServico(s);
                            },
                          ),
                          if (_servicoId != null && !servicoAindaExiste)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Serviço original ("$_servicoNomeOriginal") não existe mais no catálogo. Selecione outro.',
                                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selecionarData,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Data'),
                            child: Text(DateFormat('dd/MM/yyyy').format(_data)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _valorController,
                          decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selecionarHora(inicio: true),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Hora início'),
                            child: Text(_formatarHora(_horaInicio)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selecionarHora(inicio: false),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Hora fim'),
                            child: Text(_formatarHora(_horaFim)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observacaoController,
                    decoration: const InputDecoration(labelText: 'Observação'),
                    maxLines: 3,
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
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

