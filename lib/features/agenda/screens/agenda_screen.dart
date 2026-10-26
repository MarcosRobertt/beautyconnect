import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../dashboard/controllers/dashboard_controller.dart'; 
import '../../estoque/controllers/estoque_controller.dart';
import '../../estoque/models/insumo.dart';
import '../../financeiro/controllers/financeiro_controller.dart';

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  String _rotulo(AgendaState estado) {
    final hoje = DateTime.now();
    final isHoje = estado.dataReferencia.year == hoje.year &&
                   estado.dataReferencia.month == hoje.month &&
                   estado.dataReferencia.day == hoje.day;

    switch (estado.visao) {
      case VisaoAgenda.dia:
        final dataFormatada = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(estado.dataReferencia);
        return isHoje ? 'Hoje, $dataFormatada' : dataFormatada;
      case VisaoAgenda.semana:
        final inicio = estado.dataReferencia.subtract(Duration(days: estado.dataReferencia.weekday % 7));
        return 'Semana de ${DateFormat('dd/MM').format(inicio)}';
      case VisaoAgenda.mes:
        return DateFormat("MMMM 'de' yyyy", 'pt_BR').format(estado.dataReferencia);
    }
  }

  void _mostrarRelatorioDeErro(BuildContext context, String erroRaw) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Diagnóstico de Erro', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText( 
              erroRaw, 
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar Erro'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: erroRaw));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Relatório copiado! Cole no chat da IA.'), backgroundColor: Colors.blue),
              );
            },
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalCancelamento(BuildContext context, WidgetRef ref, Agendamento agendamento) {
    final motivoController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar ou Reagendar?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Você pode excluir este agendamento ou reagendá-lo para outra data.'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)', hintText: 'Ex: Cliente teve imprevisto'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); 
              context.push('${AppRoutes.agenda}/editar/${agendamento.id}'); 
            },
            child: const Text('Reagendar', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final motivo = motivoController.text.trim();
              String? relatorioDeErro; 

              if (motivo.isNotEmpty) {
                final novaObs = agendamento.observacao.isEmpty ? '[Cancelado: $motivo]' : '${agendamento.observacao} | [Cancelado: $motivo]';
                final atualizado = agendamento.copyWith(status: AgendamentoStatus.cancelado, observacao: novaObs);
                relatorioDeErro = await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
                try {
                  await FirebaseFirestore.instance.collection('agendamentos').doc(agendamento.id).set({
                    'observacao': novaObs,
                    'status': 'cancelado',
                  }, SetOptions(merge: true));
                } catch (e) {
                  relatorioDeErro = 'Erro no Firestore: $e';
                }
              } else {
                relatorioDeErro = await ref.read(agendamentoControllerProvider.notifier).cancelar(agendamento.id);
              }

              if (context.mounted) {
                if (relatorioDeErro != null) {
                  _mostrarRelatorioDeErro(context, relatorioDeErro);
                } else {
                  ref.invalidate(todosAgendamentosProvider);
                  ref.invalidate(dashboardMetricsProvider);
                  ref.invalidate(financeiroControllerProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Ação realizada com sucesso!'), backgroundColor: Colors.green));
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _confirmarReabertura(BuildContext context, WidgetRef ref, Agendamento agendamento) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Text('Reabrir Comanda?', style: TextStyle(color: Colors.orange.shade900, fontSize: 18)),
          ],
        ),
        content: const Text('Atenção: Ao reabrir, os valores desta comanda serão removidos do caixa realizado e ela voltará para status "Agendado".\n\nVocê poderá definir novas datas e valores livremente. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              Navigator.pop(ctx);
              
              final regexLimpeza = RegExp(r'\n?\[Baixa Financeira.*?\]');
              final novaObs = agendamento.observacao.replaceAll(regexLimpeza, '').trim();
              
              final atualizado = agendamento.copyWith(
                status: AgendamentoStatus.agendado,
                formaPagamento: FormaPagamento.pendente,
                observacao: novaObs,
              );
              
              String? relatorioDeErro = await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
              
              try {
                await FirebaseFirestore.instance.collection('agendamentos').doc(agendamento.id).set({
                  'observacao': novaObs,
                  'status': 'agendado',
                  'dataPagamento': FieldValue.delete(),
                  'pagamentosDetalhados': FieldValue.delete(),
                }, SetOptions(merge: true));
              } catch (e) {
                relatorioDeErro = (relatorioDeErro != null ? '$relatorioDeErro\n' : '') + 'Falha no banco ao reabrir: $e';
              }
              
              if (context.mounted) {
                if (relatorioDeErro != null) {
                  _mostrarRelatorioDeErro(context, relatorioDeErro);
                } else {
                  ref.invalidate(todosAgendamentosProvider);
                  ref.invalidate(dashboardMetricsProvider);
                  ref.invalidate(financeiroControllerProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comanda reaberta e pronta para novo fechamento.'), backgroundColor: Colors.blue));
                }
              }
            },
            child: const Text('Sim, Reabrir'),
          ),
        ],
      ),
    );
  }

  void _abrirModalComanda(BuildContext context, WidgetRef ref, Agendamento agendamento, String nomeCliente) {
    showModalBottomSheet<void>(
      context: context, 
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) => ModalFecharComanda(
        agendamento: agendamento,
        nomeCliente: nomeCliente,
        onConfirmar: (pagamentos, valorFinal, houveAtraso, insumosAcabaram, produtosUtilizados) async {
          
          String baixasStr = '';
          if (insumosAcabaram.isNotEmpty) {
            for (final insumo in insumosAcabaram) {
              final novaQtd = insumo.quantidade > 0 ? insumo.quantidade - 1 : 0;
              final atualizacaoInsumo = insumo.copyWith(quantidade: novaQtd);
              await ref.read(estoqueControllerProvider.notifier).salvar(atualizacaoInsumo);
            }
            final nomes = insumosAcabaram.map((i) => i.nome).join(', ');
            baixasStr = '[Potes Esgotados (Baixa): $nomes]';
          }

          String utilizadosStr = '';
          if (produtosUtilizados.isNotEmpty) {
            final nomes = produtosUtilizados.map((i) => i.nome).join(', ');
            utilizadosStr = '[Produtos Utilizados: $nomes]';
          }

          final regexLimpeza = RegExp(r'\n?\[Baixa Financeira.*?\]');
          String novaObs = agendamento.observacao.replaceAll(regexLimpeza, '').trim();
          
          if (houveAtraso && !novaObs.contains('[Cliente Atrasou]')) {
            novaObs = novaObs.isEmpty ? '[Cliente Atrasou]' : '$novaObs | [Cliente Atrasou]';
          }

          if (utilizadosStr.isNotEmpty) {
            novaObs = novaObs.isEmpty ? utilizadosStr : '$novaObs\n$utilizadosStr';
          }

          if (baixasStr.isNotEmpty) {
            novaObs = novaObs.isEmpty ? baixasStr : '$novaObs\n$baixasStr';
          }

          FormaPagamento formaPrincipal = FormaPagamento.pix;
          String detalhePagamentoStr = '';
          DateTime dataDoPagamentoReal = DateTime.now();

          try {
            final dynamic d = (agendamento as dynamic).data;
            if (d is DateTime) dataDoPagamentoReal = d;
            else if (d is String) dataDoPagamentoReal = DateTime.parse(d);
          } catch (_) {}

          final List<Map<String, dynamic>> listaPagamentosDetalhados = [];

          if (pagamentos.isNotEmpty) {
            try {
              final maiorPagamento = pagamentos.reduce((a, b) => (a['valor'] as double) > (b['valor'] as double) ? a : b);
              formaPrincipal = maiorPagamento['forma'] as FormaPagamento;
              dataDoPagamentoReal = maiorPagamento['data'] as DateTime;

              final formataMoeda = (double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

              Map<String, List<String>> pagamentosPorData = {};
              for (var p in pagamentos) {
                final d = p['data'] as DateTime;
                final dStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                final f = (p['forma'] as FormaPagamento).rotulo;
                final v = formataMoeda(p['valor'] as double);
                pagamentosPorData.putIfAbsent(dStr, () => []).add('$f: $v');

                listaPagamentosDetalhados.add({
                  'forma': f,
                  'valor': (p['valor'] as num).toDouble(),
                  'data': d.toIso8601String(),
                });
              }

              List<String> blocosDeData = [];
              pagamentosPorData.forEach((dataStr, detalhes) {
                blocosDeData.add('$dataStr -> ${detalhes.join(' | ')}');
              });

              detalhePagamentoStr = '[Baixa Financeira: ${blocosDeData.join(' || ')}]';
            } catch (e) {
              detalhePagamentoStr = '[Baixa Financeira Registrada: ${agendamento.data.day.toString().padLeft(2, '0')}/${agendamento.data.month.toString().padLeft(2, '0')}]';
            }
          } else if (valorFinal <= 0.01) {
            detalhePagamentoStr = '[Baixa Financeira: Sem Custo / Retorno]';
          }

          if (detalhePagamentoStr.isNotEmpty) {
            novaObs = novaObs.isEmpty ? detalhePagamentoStr : '$novaObs\n$detalhePagamentoStr';
          }

          final atualizado = agendamento.copyWith(
            status: AgendamentoStatus.concluido,
            formaPagamento: formaPrincipal,
            valor: valorFinal,
            observacao: novaObs,
          );

          String? relatorioDeErro = await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
          
          try {
            await FirebaseFirestore.instance.collection('agendamentos').doc(agendamento.id).set({
              'dataPagamento': dataDoPagamentoReal.toIso8601String(),
              'observacao': novaObs,
              'status': 'concluido',
              'pagamentosDetalhados': listaPagamentosDetalhados,
            }, SetOptions(merge: true));
          } catch (e) {
            relatorioDeErro = (relatorioDeErro != null ? '$relatorioDeErro\n' : '') + 'Falha no banco ao salvar comanda: $e';
          }

          if (context.mounted) {
            if (relatorioDeErro != null) {
              _mostrarRelatorioDeErro(context, relatorioDeErro);
            } else {
              ref.invalidate(todosAgendamentosProvider);
              ref.invalidate(dashboardMetricsProvider);
              ref.invalidate(financeiroControllerProvider);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Comanda fechada com sucesso!'), backgroundColor: Colors.green));
            }
          }
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
    final clientesPorId = clientesAsync.maybeWhen(data: (lista) => {for (final c in lista) c.id: c.nome}, orElse: () => <String, String>{});
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
          final hoje = DateTime.now();
          final isHoje = estado.dataReferencia.year == hoje.year && estado.dataReferencia.month == hoje.month && estado.dataReferencia.day == hoje.day;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(onPressed: notifier.voltar, icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final dataSelecionada = await showDatePicker(context: context, initialDate: estado.dataReferencia, firstDate: DateTime(2020), lastDate: DateTime(2035), helpText: 'IR PARA A DATA');
                          if (dataSelecionada != null) notifier.mudarData(dataSelecionada);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_rotulo(estado), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isHoje ? Theme.of(context).colorScheme.primary : null, fontWeight: isHoje ? FontWeight.bold : null)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 20, color: isHoje ? Theme.of(context).colorScheme.primary : Colors.grey.shade600),
                            ],
                          ),
                        ),
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
                      ? TimelineDayView(
                          agendamentos: estado.lista,
                          clientesPorId: clientesPorId,
                          moeda: moeda,
                          dataReferencia: estado.dataReferencia,
                          onNovoAgendamento: (horaInicio) {
                            final dataIso = estado.dataReferencia.toIso8601String().split('T').first;
                            context.push(Uri(path: AppRoutes.agendaNovo, queryParameters: {'data': dataIso, 'hora': horaInicio}).toString());
                          },
                          onEditar: (id) => context.push('${AppRoutes.agenda}/editar/$id'),
                          onConfirmar: (id) => notifier.confirmar(id),
                          onConcluir: (id) {
                            final agendamento = estado.lista.firstWhere((a) => a.id == id);
                            final nomeCliente = clientesPorId[agendamento.clienteId] ?? (agendamento.clienteId == 'BLOQUEIO' ? 'Compromisso Pessoal' : 'Cliente removido');
                            _abrirModalComanda(context, ref, agendamento, nomeCliente);
                          },
                          onCancelar: (id) {
                            final agendamento = estado.lista.firstWhere((a) => a.id == id);
                            _abrirModalCancelamento(context, ref, agendamento);
                          },
                          onReabrir: (id) {
                            final agendamento = estado.lista.firstWhere((a) => a.id == id);
                            _confirmarReabertura(context, ref, agendamento);
                          },
                        )
                      : estado.visao == VisaoAgenda.semana
                          ? TimelineWeekView(agendamentos: estado.lista, dataReferencia: estado.dataReferencia, onIrParaDia: (dataCerta) { notifier.mudarData(dataCerta); notifier.mudarVisao(VisaoAgenda.dia); })
                          : CalendarMonthView(agendamentos: estado.lista, dataReferencia: estado.dataReferencia, onIrParaDia: (dataCerta) { notifier.mudarData(dataCerta); notifier.mudarVisao(VisaoAgenda.dia); }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ModalFecharComanda extends ConsumerStatefulWidget {
  const ModalFecharComanda({super.key, required this.agendamento, required this.nomeCliente, required this.onConfirmar, required this.onCancelarAtendimento});
  
  final Agendamento agendamento;
  final String nomeCliente;
  final void Function(List<Map<String, dynamic>> pagamentos, double valorFinal, bool houveAtraso, List<Insumo> insumosAcabaram, List<Insumo> produtosUtilizados) onConfirmar;
  final VoidCallback onCancelarAtendimento;
  
  @override
  ConsumerState<ModalFecharComanda> createState() => _ModalFecharComandaState();
}

class _ModalFecharComandaState extends ConsumerState<ModalFecharComanda> {
  late double _valorTotal;
  bool _houveAtraso = false;
  
  late DateTime _dataPagamentoAtual; 
  final List<Map<String, dynamic>> _pagamentos = [];
  FormaPagamento _formaAtual = FormaPagamento.pix;
  final TextEditingController _valorParcialController = TextEditingController();

  final List<Insumo> _insumosAcabaram = [];
  final List<Insumo> _produtosUtilizados = []; 

  @override
  void initState() {
    super.initState();
    _valorTotal = widget.agendamento.valor;
    _dataPagamentoAtual = DateTime.now();

    _valorParcialController.text = _valorTotal.toStringAsFixed(2).replaceAll('.', ',');
    _valorParcialController.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _valorParcialController.dispose(); super.dispose(); }

  double get _valorRestante {
    final pago = _pagamentos.fold<double>(0, (soma, p) => soma + (p['valor'] as double));
    return _valorTotal - pago;
  }

  double get _valorDigitado => double.tryParse(_valorParcialController.text.replaceAll(',', '.')) ?? 0.0;

  bool get _podeConfirmar {
    if (_valorTotal <= 0.01) return true; 
    if (_valorRestante <= 0.01) return true; 
    if (_valorRestante > 0.01) return true; 
    return false;
  }

  void _adicionarPagamento() {
    final valorDigitado = _valorDigitado;
    if (valorDigitado > 0 && valorDigitado <= _valorRestante) {
      setState(() { 
        _pagamentos.add({'forma': _formaAtual, 'valor': valorDigitado, 'data': _dataPagamentoAtual}); 
        _valorParcialController.text = _valorRestante.toStringAsFixed(2).replaceAll('.', ','); 
      });
    }
  }

  void _removerPagamento(int index) {
    setState(() { _pagamentos.removeAt(index); _valorParcialController.text = _valorRestante.toStringAsFixed(2).replaceAll('.', ','); });
  }

  void _abrirModalProdutosUtilizados(List<Insumo> estoqueGlobal) {
    FocusScope.of(context).unfocus();
    final buscaInsumoController = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final textoBusca = buscaInsumoController.text.trim().toLowerCase();
            final listaExibicao = textoBusca.isEmpty ? estoqueGlobal : estoqueGlobal.where((e) => e.nome.toLowerCase().contains(textoBusca) || e.categoria.toLowerCase().contains(textoBusca)).toList();

            final Map<String, List<Insumo>> agrupados = {};
            for (final item in listaExibicao) {
              agrupados.putIfAbsent(item.categoria, () => []).add(item);
            }
            final categoriasOrdenadas = agrupados.keys.toList()..sort();

            void _toggleInsumo(Insumo item) {
              setModalState(() {
                if (_produtosUtilizados.contains(item)) {
                  _produtosUtilizados.remove(item);
                } else {
                  _produtosUtilizados.add(item);
                }
              });
              setState((){});
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(modalCtx).size.height * 0.85, padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Produtos Utilizados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                      ],
                    ),
                    const Text('Marque os produtos que você usou na cliente:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: buscaInsumoController,
                      decoration: const InputDecoration(hintText: 'Buscar produto...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: listaExibicao.isEmpty
                          ? const Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: categoriasOrdenadas.length,
                              itemBuilder: (c, i) {
                                final cat = categoriasOrdenadas[i];
                                final itens = agrupados[cat]!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      color: Colors.purple.shade50,
                                      child: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade900, fontSize: 12)),
                                    ),
                                    ...itens.map((item) {
                                      final isSelected = _produtosUtilizados.contains(item);
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                        title: Text(item.nome, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? Colors.purple.shade900 : Colors.black87)),
                                        subtitle: Text('Restam: ${item.quantidade} un', style: const TextStyle(fontSize: 12)),
                                        trailing: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? Colors.purple : Colors.grey),
                                        onTap: () => _toggleInsumo(item),
                                      );
                                    }).toList(),
                                  ],
                                );
                              }
                            )
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar Seleção', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(modalCtx),
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  void _abrirSeletorInsumo(List<Insumo> estoqueGlobal) {
    final TextEditingController buscaInsumoController = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final textoBusca = buscaInsumoController.text.trim().toLowerCase();
            final disponiveis = estoqueGlobal.where((e) => !_insumosAcabaram.any((a) => a.id == e.id)).toList();
            
            final listaExibicao = textoBusca.isEmpty 
              ? disponiveis 
              : disponiveis.where((e) => e.nome.toLowerCase().contains(textoBusca) || e.categoria.toLowerCase().contains(textoBusca)).toList();

            final usadosNestaComanda = listaExibicao.where((e) => _produtosUtilizados.any((u) => u.id == e.id)).toList();
            final outrosEstoque = listaExibicao.where((e) => !_produtosUtilizados.any((u) => u.id == e.id)).toList();

            Widget buildTile(Insumo item) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.delete_sweep, size: 20, color: Colors.red.shade400)),
                title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item.categoria} • Restam: ${item.quantidade} un', style: const TextStyle(fontSize: 12)),
                trailing: FilledButton.tonal(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Confirmar Baixa'),
                        content: Text('Tem certeza que o pote de "${item.nome}" acabou?\n\nIsso descontará 1 unidade do estoque imediatamente após fechar a comanda.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              setState(() => _insumosAcabaram.add(item)); 
                              Navigator.pop(modalCtx); 
                            },
                            child: const Text('Sim, Acabou'),
                          )
                        ]
                      )
                    );
                  },
                  child: const Text('Acabou'),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(modalCtx).size.height * 0.75, padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Baixa de Estoque', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                      ],
                    ),
                    const Text('Selecione o produto que chegou ao fim:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: buscaInsumoController,
                      decoration: const InputDecoration(hintText: 'Buscar no estoque...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: listaExibicao.isEmpty
                          ? const Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.grey)))
                          : ListView(
                              children: [
                                if (usadosNestaComanda.isNotEmpty && textoBusca.isEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    color: Colors.orange.shade50,
                                    child: Row(
                                      children: [
                                        Icon(Icons.star, size: 16, color: Colors.orange.shade800),
                                        const SizedBox(width: 6),
                                        Text('Utilizados nesta cliente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 12)),
                                      ],
                                    )
                                  ),
                                  ...usadosNestaComanda.map((item) => buildTile(item)).toList(),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    color: Colors.grey.shade100,
                                    child: const Text('Outros Produtos do Estoque', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
                                  ),
                                ],
                                ...outrosEstoque.map((item) => buildTile(item)).toList(),
                              ]
                            )
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final valorPendente = _valorRestante;
    final estoqueAsync = ref.watch(estoqueControllerProvider);

    return Container(
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: dynamicNome,
              children: [
                Expanded(child: Text('Fechar Comanda — ${widget.nomeCliente}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${widget.agendamento.servico} — R\$ ${_valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const Divider(height: 32),

            const Text('Pagamentos Registrados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (_pagamentos.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum pagamento registrado ainda.', style: TextStyle(fontSize: 12, color: Colors.grey))),
            ..._pagamentos.asMap().entries.map((entry) {
              final index = entry.key; final p = entry.value; final forma = p['forma'] as FormaPagamento; final valor = p['valor'] as double; final dataP = p['data'] as DateTime; final dataStr = '${dataP.day.toString().padLeft(2,'0')}/${dataP.month.toString().padLeft(2,'0')}';
              return ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(Icons.check_circle, color: Colors.green.shade600, size: 18), title: Text('${forma.rotulo} ($dataStr)'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _removerPagamento(index))]));
            }),

            if (valorPendente > 0.01) ...[
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(12), color: Colors.orange.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Falta Receber:', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)), Text('R\$ ${valorPendente.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16))])),
              const SizedBox(height: 24),
              const Text('Registrar Entrada / Recebimento:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async { final picked = await showDatePicker(context: context, initialDate: _dataPagamentoAtual, firstDate: DateTime(2020), lastDate: DateTime(2035)); if (picked != null) setState(() => _dataPagamentoAtual = picked); },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.purple), const SizedBox(width: 8), Text('Data do Recebimento: ${_dataPagamentoAtual.day.toString().padLeft(2, '0')}/${_dataPagamentoAtual.month.toString().padLeft(2, '0')}/${_dataPagamentoAtual.year}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))])),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 2, child: DropdownButtonFormField<FormaPagamento>(value: _formaAtual, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)), items: FormaPagamento.values.where((f) => f != FormaPagamento.pendente).map((f) => DropdownMenuItem(value: f, child: Text(f.rotulo, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => _formaAtual = v!))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(controller: _valorParcialController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixText: 'R\$ ', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)))),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: FilledButton(style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _adicionarPagamento, child: const Icon(Icons.add))),
                ],
              ),
            ],

            const SizedBox(height: 24),
            const Divider(height: 32),
            
            const Text('Registro de Produtos (Opcional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Quais produtos foram usados nesta cliente?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                  const SizedBox(height: 8),
                  if (_produtosUtilizados.isNotEmpty) ...[
                    Wrap(spacing: 8, runSpacing: -8, children: _produtosUtilizados.map((insumo) => Chip(label: Text(insumo.nome, style: TextStyle(fontSize: 11, color: Colors.purple.shade900)), onDeleted: () => setState(() => _produtosUtilizados.remove(insumo)), backgroundColor: Colors.white, side: BorderSide(color: Colors.purple.shade200))).toList()),
                    const SizedBox(height: 8),
                  ],
                  estoqueAsync.when(
                    loading: () => const LinearProgressIndicator(), 
                    error: (_, __) => const Text('Erro.'), 
                    data: (estoqueGlobal) { 
                      return OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.purple.shade800, side: BorderSide(color: Colors.purple.shade200), backgroundColor: Colors.white), 
                        onPressed: () => _abrirModalProdutosUtilizados(estoqueGlobal), 
                        icon: const Icon(Icons.water_drop, size: 18), 
                        label: const Text('Selecionar Produtos Utilizados')
                      ); 
                    }
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Baixa de Estoque (Pote Vazio)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Text('Algum produto chegou ao fim neste atendimento?', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (_insumosAcabaram.isNotEmpty) ...[
                    Wrap(
                      spacing: 8, runSpacing: -8,
                      children: _insumosAcabaram.map((insumo) => Chip(
                        label: Text(insumo.nome, style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                        onDeleted: () => setState(() => _insumosAcabaram.remove(insumo)),
                        backgroundColor: Colors.red.shade50,
                        deleteIconColor: Colors.red.shade300,
                        side: BorderSide(color: Colors.red.shade200),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  estoqueAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Erro ao carregar estoque.'),
                    data: (estoqueGlobal) {
                      return OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade800, side: BorderSide(color: Colors.red.shade200), backgroundColor: Colors.white),
                        onPressed: () => _abrirSeletorInsumo(estoqueGlobal),
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('Registrar pote vazio (Baixa)')
                      );
                    }
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            CheckboxListTile(value: _houveAtraso, contentPadding: EdgeInsets.zero, title: const Text('Cliente chegou atrasada?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)), subtitle: const Text('Registra o atraso no histórico para métricas.', style: TextStyle(fontSize: 11, color: Colors.grey)), controlAffinity: ListTileControlAffinity.leading, onChanged: (val) => setState(() => _houveAtraso = val ?? false)),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () { Navigator.pop(context); widget.onCancelarAtendimento(); }, child: const Text('Cancelar\nAtendimento', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: _podeConfirmar ? Colors.green.shade700 : Colors.grey),
                    onPressed: _podeConfirmar ? () {
                      if (_valorRestante > 0.01) { 
                        _pagamentos.add({'forma': _formaAtual, 'valor': _valorRestante, 'data': _dataPagamentoAtual}); 
                      }
                      Navigator.pop(context);
                      widget.onConfirmar(_pagamentos, _valorTotal, _houveAtraso, _insumosAcabaram, _produtosUtilizados);
                    } : null,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.check_circle_outline, size: 18, color: Colors.white), SizedBox(width: 6), Expanded(child: Text('Confirmar Recebimento', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white), maxLines: 2))]),
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
const dynamic dynamicNome = MainAxisAlignment.spaceBetween;
