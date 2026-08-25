import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/agendamento_controller.dart';
import '../models/agendamento.dart';
import '../widgets/timeline_day_view.dart';
import '../widgets/timeline_week_view.dart';
import '../widgets/calendar_month_view.dart';

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  String _rotulo(AgendaState estado) {
    switch (estado.visao) {
      case VisaoAgenda.dia:
        return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(estado.dataReferencia);
      case VisaoAgenda.semana:
        final inicio = estado.dataReferencia.subtract(Duration(days: estado.dataReferencia.weekday % 7));
        return 'Semana de ${DateFormat('dd/MM').format(inicio)}';
      case VisaoAgenda.mes:
        return DateFormat("MMMM 'de' yyyy", 'pt_BR').format(estado.dataReferencia);
    }
  }

  // NOVO MODAL INTELIGENTE DE CANCELAMENTO / REAGENDAMENTO
  void _abrirModalCancelamento(BuildContext context, WidgetRef ref, Agendamento agendamento) {
    final motivoController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar ou Reagendar?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Você pode excluir este agendamento ou reagendá-lo para outra data.'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ex: Cliente teve imprevisto',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fecha o modal
              context.push('${AppRoutes.agenda}/editar/${agendamento.id}'); // Vai para edição
            },
            child: const Text('Reagendar', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              final motivo = motivoController.text.trim();
              
              if (motivo.isNotEmpty) {
                // Se digitou motivo, adiciona na observação e muda o status para cancelado
                final novaObs = agendamento.observacao.isEmpty
                    ? '[Cancelado: $motivo]'
                    : '${agendamento.observacao} | [Cancelado: $motivo]';
                
                final atualizado = agendamento.copyWith(
                  status: AgendamentoStatus.cancelado,
                  observacao: novaObs,
                );
                ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
              } else {
                // Se não digitou nada, apenas cancela padrão
                ref.read(agendamentoControllerProvider.notifier).cancelar(agendamento.id);
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _abrirModalComanda(
    BuildContext context,
    WidgetRef ref,
    Agendamento agendamento,
    String nomeCliente,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ModalFecharComanda(
        agendamento: agendamento,
        nomeCliente: nomeCliente,
        onConfirmar: (forma, valorFinal, houveAtraso) {
          final obsAtual = agendamento.observacao;
          final novaObs = houveAtraso && !obsAtual.contains('[Cliente Atrasou]')
              ? (obsAtual.isEmpty ? '[Cliente Atrasou]' : '$obsAtual | [Cliente Atrasou]')
              : obsAtual;

          final atualizado = agendamento.copyWith(
            status: AgendamentoStatus.concluido,
            formaPagamento: forma,
            valor: valorFinal,
            observacao: novaObs,
          );
          ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
        },
        onCancelarAtendimento: () {
          _abrirModalCancelamento(context, ref, agendamento);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(agendamentoControllerProvider);
    final clientesAsync = ref.watch(clienteControllerProvider);
    final clientesPorId = clientesAsync.maybeWhen(
      data: (lista) => {for (final c in lista) c.id: c.nome},
      orElse: () => <String, String>{},
    );
    final moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final dataAtual = estadoAsync.value?.dataReferencia ?? DateTime.now();
          final dataIso = dataAtual.toIso8601String().split('T').first;
          context.push(Uri(path: AppRoutes.agendaNovo, queryParameters: {'data': dataIso}).toString());
        },
        child: const Icon(Icons.add),
      ),
      body: estadoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar agenda: $e')),
        data: (estado) {
          final notifier = ref.read(agendamentoControllerProvider.notifier);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(onPressed: notifier.voltar, icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: Text(
                        _rotulo(estado),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(onPressed: notifier.avancar, icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<VisaoAgenda>(
                  segments: const [
                    ButtonSegment(value: VisaoAgenda.dia, label: Text('Hoje')),
                    ButtonSegment(value: VisaoAgenda.semana, label: Text('Semana')),
                    ButtonSegment(value: VisaoAgenda.mes, label: Text('Mês')),
                  ],
                  selected: {estado.visao},
                  onSelectionChanged: (novo) => notifier.mudarVisao(novo.first),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: estado.visao == VisaoAgenda.dia
                      ? (estado.lista.isEmpty
                          ? const Center(child: Text('Nenhum agendamento neste dia.'))
                          : TimelineDayView(
                              agendamentos: estado.lista,
                              clientesPorId: clientesPorId,
                              moeda: moeda,
                              dataReferencia: estado.dataReferencia,
                              onNovoAgendamento: (horaInicio) {
                                final dataIso = estado.dataReferencia.toIso8601String().split('T').first;
                                context.push(Uri(
                                  path: AppRoutes.agendaNovo,
                                  queryParameters: {'data': dataIso, 'hora': horaInicio},
                                ).toString());
                              },
                              onEditar: (id) => context.push('${AppRoutes.agenda}/editar/$id'),
                              onConfirmar: (id) => notifier.confirmar(id),
                              onConcluir: (id) {
                                final agendamento = estado.lista.firstWhere((a) => a.id == id);
                                final nomeCliente = clientesPorId[agendamento.clienteId] ??
                                    (agendamento.clienteId == 'BLOQUEIO'
                                        ? 'Compromisso Pessoal'
                                        : 'Cliente');
                                _abrirModalComanda(context, ref, agendamento, nomeCliente);
                              },
                              onCancelar: (id) {
                                final agendamento = estado.lista.firstWhere((a) => a.id == id);
                                _abrirModalCancelamento(context, ref, agendamento);
                              },
                            ))
                      : estado.visao == VisaoAgenda.semana
                          ? TimelineWeekView(
                              agendamentos: estado.lista,
                              dataReferencia: estado.dataReferencia,
                              onIrParaDia: (dataCerta) {
                                notifier.mudarData(dataCerta);
                                notifier.mudarVisao(VisaoAgenda.dia);
                              },
                            )
                          : CalendarMonthView(
                              agendamentos: estado.lista,
                              dataReferencia: estado.dataReferencia,
                              onIrParaDia: (dataCerta) {
                                notifier.mudarData(dataCerta);
                                notifier.mudarVisao(VisaoAgenda.dia);
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ModalFecharComanda extends StatefulWidget {
  const ModalFecharComanda({
    super.key,
    required this.agendamento,
    required this.nomeCliente,
    required this.onConfirmar,
    required this.onCancelarAtendimento,
  });

  final Agendamento agendamento;
  final String nomeCliente;
  final void Function(FormaPagamento forma, double valorFinal, bool houveAtraso) onConfirmar;
  final VoidCallback onCancelarAtendimento;

  @override
  State<ModalFecharComanda> createState() => _ModalFecharComandaState();
}

class _ModalFecharComandaState extends State<ModalFecharComanda> {
  late double _valorFinal;
  FormaPagamento _formaSelecionada = FormaPagamento.pix;
  bool _houveAtraso = false;

  @override
  void initState() {
    super.initState();
    _valorFinal = widget.agendamento.valor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Fechar Comanda — ${widget.nomeCliente}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.agendamento.servico} — R\$ ${_valorFinal.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Text(
              'Forma de Pagamento:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FormaPagamento.values.map((forma) {
                final selecionado = _formaSelecionada == forma;
                return ChoiceChip(
                  label: Text(forma.rotulo),
                  selected: selecionado,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() => _formaSelecionada = forma);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _houveAtraso,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Cliente chegou atrasada?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Registra o atraso no histórico para métricas futuras.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) => setState(() => _houveAtraso = val ?? false),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Fecha a comanda
                      widget.onCancelarAtendimento(); // Abre o modal de cancelar/reagendar
                    },
                    child: const Text(
                      'Cancelar\nAtendimento',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onConfirmar(_formaSelecionada, _valorFinal, _houveAtraso);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formaSelecionada == FormaPagamento.pendente
                                ? 'Manter Aberta'
                                : 'Confirmar Recebimento',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
