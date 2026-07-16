import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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
    super.dispose();
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
                  clientesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Erro ao carregar clientes: $e'),
                    data: (clientes) {
                      if (clientes.isEmpty) {
                        return const Text('Cadastre um cliente antes de criar um agendamento.');
                      }
                      return DropdownButtonFormField<String>(
                        value: _clienteId,
                        decoration: const InputDecoration(labelText: 'Cliente'),
                        items: clientes
                            .map((Cliente c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))
                            .toList(),
                        onChanged: (v) => setState(() => _clienteId = v),
                      );
                    },
                  ),
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
