import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/whatsapp_service.dart';
import '../../clientes/controllers/cliente_controller.dart';
import '../../clientes/models/cliente.dart';
import '../../servicos/controllers/servico_controller.dart';
import '../../servicos/models/servico.dart';
import '../controllers/agendamento_controller.dart';
import '../models/agendamento.dart';
import '../../estoque/controllers/estoque_controller.dart';
import '../../estoque/models/insumo.dart';

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
  final _motivoBloqueioController = TextEditingController(); 

  bool _isBloqueio = false; 
  String? _clienteId;
  
  final List<String> _servicosIdsSelecionados = [];
  String _servicoNomeOriginal = ''; 
  List<String> _ultimosServicosIds = []; 
  
  DateTime _data = DateTime.now();
  TimeOfDay _horaInicio = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaFim = const TimeOfDay(hour: 10, minute: 0);
  Agendamento? _original;
  bool _carregando = true;
  String? _erro;

  String _tipoRepeticao = 'nenhum'; 
  int _ocorrencias = 2; 

  bool get _editando => widget.agendamentoId != null;

  @override
  void initState() {
    super.initState();
    if (widget.dataInicialIso != null) {
      _data = DateTime.tryParse(widget.dataInicialIso!) ?? DateTime.now();
    }
    if (widget.horaInicialStr != null) {
      _horaInicio = _parseHora(widget.horaInicialStr!);
      _horaFim = _somarMinutos(_horaInicio, 60); 
    }
    _carregar();
  }

  Future<void> _carregar() async {
    final todosAgendamentos = await ref.read(agendamentoControllerProvider.notifier).todos();
    
    final agendamentosOrdenados = List<Agendamento>.from(todosAgendamentos)
      ..sort((a, b) => b.data.compareTo(a.data));
    final idsUnicos = <String>{};
    for (final ag in agendamentosOrdenados) {
      if (ag.servicoId != null && ag.clienteId != 'BLOQUEIO') {
        idsUnicos.add(ag.servicoId!);
        if (idsUnicos.length >= 5) break;
      }
    }
    _ultimosServicosIds = idsUnicos.toList();

    if (_editando) {
      Agendamento? ag;
      for (final a in todosAgendamentos) {
        if (a.id == widget.agendamentoId) {
          ag = a;
          break;
        }
      }
      if (ag != null) {
        _original = ag;
        if (ag.clienteId == 'BLOQUEIO') {
          _isBloqueio = true;
          _motivoBloqueioController.text = ag.servico;
        } else {
          _clienteId = ag.clienteId;
          if (ag.servicoId != null) {
            _servicosIdsSelecionados.add(ag.servicoId!);
          }
          _servicoNomeOriginal = ag.servico;
          _valorController.text = ag.valor.toString();
        }
        _data = ag.data;
        _horaInicio = _parseHora(ag.horaInicio);
        _horaFim = _parseHora(ag.horaFim);
        _observacaoController.text = ag.observacao;
      }
    }
    setState(() => _carregando = false);
  }

  void _recalcularTotais() {
    final servicos = ref.read(servicoControllerProvider).value ?? [];
    double totalValor = 0;
    int totalMin = 0;
    for (var id in _servicosIdsSelecionados) {
      try {
        final s = servicos.firstWhere((x) => x.id == id);
        totalValor += s.valor;
        totalMin += s.duracaoMin;
      } catch (_) {}
    }
    _valorController.text = totalValor.toStringAsFixed(2).replaceAll('.', ',');
    _horaFim = _somarMinutos(_horaInicio, totalMin);
  }

  TimeOfDay _parseHora(String hhmm) {
    final partes = hhmm.split(':');
    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  String _formatarHora(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  String _formatarDataGoogle(DateTime data) {
    final meses = ['jan.', 'fev.', 'mar.', 'abr.', 'mai.', 'jun.', 'jul.', 'ago.', 'set.', 'out.', 'nov.', 'dez.'];
    final dias = ['Seg.', 'Ter.', 'Qua.', 'Qui.', 'Sex.', 'Sáb.', 'Dom.'];
    return '${dias[data.weekday - 1]}, ${data.day} de ${meses[data.month - 1]} de ${data.year}';
  }

  TimeOfDay _somarMinutos(TimeOfDay hora, int minutos) {
    final total = (hora.hour * 60 + hora.minute + minutos) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  bool get _horaFimDepoisDoInicio =>
      (_horaFim.hour * 60 + _horaFim.minute) > (_horaInicio.hour * 60 + _horaInicio.minute);

  Future<void> _selecionarData() async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      cancelText: 'Cancelar',
      confirmText: 'OK',
      helpText: 'Selecione a data',
    );
    if (selecionada != null) setState(() => _data = selecionada);
  }

  Future<void> _selecionarHora({required bool inicio}) async {
    final selecionada = await showTimePicker(
      context: context, 
      initialTime: inicio ? _horaInicio : _horaFim,
      cancelText: 'Cancelar',
      confirmText: 'OK',
      helpText: 'Selecione o horário',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (selecionada != null) {
      setState(() {
        if (inicio) {
          _horaInicio = selecionada;
          if (_isBloqueio) {
            _horaFim = _somarMinutos(_horaInicio, 60); 
          } else if (_servicosIdsSelecionados.isNotEmpty) {
            final servicos = ref.read(servicoControllerProvider).value ?? [];
            int totalMin = 0;
            for (var id in _servicosIdsSelecionados) {
              try {
                totalMin += servicos.firstWhere((s) => s.id == id).duracaoMin;
              } catch (_) {}
            }
            _horaFim = _somarMinutos(_horaInicio, totalMin);
          }
        } else {
          _horaFim = selecionada;
        }
      });
    }
  }

  int _calcularDuracaoEmMinutos(TimeOfDay inicio, TimeOfDay fim) {
    final minInicio = inicio.hour * 60 + inicio.minute;
    final minFim = fim.hour * 60 + fim.minute;
    return minFim - minInicio;
  }

  Future<bool> _verificarConflitoDeHorarioParaData(DateTime dataAlvo) async {
    final todosAgendamentos = await ref.read(agendamentoControllerProvider.notifier).todos();
    final minNovoInicio = _horaInicio.hour * 60 + _horaInicio.minute;
    final minNovoFim = _horaFim.hour * 60 + _horaFim.minute;

    for (final agendamento in todosAgendamentos) {
      if ((_editando && agendamento.id == _original?.id) || 
          agendamento.status == AgendamentoStatus.cancelado) {
        continue;
      }
      if (agendamento.data.year == dataAlvo.year &&
          agendamento.data.month == dataAlvo.month &&
          agendamento.data.day == dataAlvo.day) {
        
        final horaExistenteInicio = _parseHora(agendamento.horaInicio);
        final horaExistenteFim = _parseHora(agendamento.horaFim);
        final minExistenteInicio = horaExistenteInicio.hour * 60 + horaExistenteInicio.minute;
        final minExistenteFim = horaExistenteFim.hour * 60 + horaExistenteFim.minute;

        if (minNovoInicio < minExistenteFim && minNovoFim > minExistenteInicio) {
          return true; 
        }
      }
    }
    return false; 
  }

  void _abrirModalCancelamento(BuildContext context) {
    final motivoController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar Agendamento?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('O agendamento será registrado como cancelado no histórico.'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ex: Cliente não confirmou / Imprevisto',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final motivo = motivoController.text.trim();

              final obsAtual = _observacaoController.text.trim();
              final novaObs = motivo.isNotEmpty
                  ? (obsAtual.isEmpty ? '[Cancelado: $motivo]' : '$obsAtual | [Cancelado: $motivo]')
                  : obsAtual;

              final cancelado = _original!.copyWith(
                status: AgendamentoStatus.cancelado,
                observacao: novaObs,
                updatedAt: DateTime.now(),
              );

              final erro = await ref
                  .read(agendamentoControllerProvider.notifier)
                  .salvar(cancelado, novo: false);

              if (erro == null && mounted) {
                context.pop();
              } else if (mounted && erro != null) {
                setState(() => _erro = erro);
              }
            },
            child: const Text('Confirmar Cancelamento'),
          ),
        ],
      ),
    );
  }

  void _abrirModalComandaCompleto(BuildContext context, WidgetRef ref, Agendamento agendamento, String nomeCliente) {
    showModalBottomSheet<void>(
      context: context, 
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) => ModalFecharComandaForm(
        agendamento: agendamento,
        nomeCliente: nomeCliente,
        onConfirmar: (pagamentos, valorFinal, houveAtraso, insumosAcabaram, produtosUtilizados) async {
          
          try {
            final docVerificacao = await FirebaseFirestore.instance
                .collection('agendamentos')
                .doc(agendamento.id)
                .get(const GetOptions(source: Source.server));
                
            if (docVerificacao.exists) {
              final statusBanco = docVerificacao.data()?['status']?.toString().toLowerCase() ?? '';
              
              if (statusBanco.contains('concluido') && agendamento.status != AgendamentoStatus.concluido) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.gpp_bad_rounded, color: Colors.orange.shade800, size: 28),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Duplicidade Evitada!', style: TextStyle(color: Colors.orange.shade900, fontSize: 18))),
                        ],
                      ),
                      content: const Text('O sistema interceptou esta ação porque a comanda já consta como FECHADA no banco de dados.\n\nA ação foi bloqueada e nenhum valor extra foi lançado.'),
                      actions: [
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.invalidate(todosAgendamentosProvider);
                          },
                          child: const Text('Entendi, Atualizar Tela'),
                        ),
                      ],
                    ),
                  );
                }
                return; 
              }
            }
          } catch (e) {}

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

          final obsAtual = agendamento.observacao;
          String novaObs = obsAtual;
          
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

          if (pagamentos.isNotEmpty) {
            final maiorPagamento = pagamentos.reduce((a, b) => (a['valor'] as double) > (b['valor'] as double) ? a : b);
            formaPrincipal = maiorPagamento['forma'] as FormaPagamento;
            
            final formataMoeda = (double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
            
            final listaDetalhes = pagamentos.map((p) {
              final d = p['data'] as DateTime;
              final dStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
              final f = (p['forma'] as FormaPagamento).rotulo;
              final v = formataMoeda(p['valor'] as double);
              return '[$dStr] $f: $v';
            }).join(' | ');
            
            detalhePagamentoStr = '[Baixa Financeira: $listaDetalhes]';
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

          final relatorioDeErro = await ref.read(agendamentoControllerProvider.notifier).salvar(atualizado, novo: false);
          
          if (context.mounted) {
            if (relatorioDeErro != null) {
              setState(() => _erro = relatorioDeErro);
            } else {
              ref.invalidate(todosAgendamentosProvider);
              setState(() {
                _original = atualizado; 
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Comanda fechada com sucesso!'), backgroundColor: Colors.green));
            }
          }
        },
        onCancelarAtendimento: () {
          _abrirModalCancelamento(context);
        },
      ),
    );
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    
    if (!_horaFimDepoisDoInicio) {
      setState(() => _erro = 'A hora de fim deve ser depois da hora de início.');
      return;
    }

    String nomeServico = '';
    double valor = 0.0;
    String? servicoIdFinal;

    if (_isBloqueio) {
      if (_motivoBloqueioController.text.trim().isEmpty) {
        setState(() => _erro = 'Informe o motivo do bloqueio (ex: Almoço).');
        return;
      }
      nomeServico = _motivoBloqueioController.text.trim();
    } else {
      if (_clienteId == null) {
        setState(() => _erro = 'Selecione um cliente.');
        return;
      }
      if (_servicosIdsSelecionados.isEmpty) {
        setState(() => _erro = 'Selecione um serviço.');
        return;
      }
      
      final servicos = ref.read(servicoControllerProvider).value ?? [];
      List<String> nomesCombinados = [];

      for (var id in _servicosIdsSelecionados) {
        try {
          final s = servicos.firstWhere((x) => x.id == id);
          nomesCombinados.add(s.nome);
        } catch (_) {}
      }

      nomeServico = nomesCombinados.isNotEmpty ? nomesCombinados.join(' + ') : _servicoNomeOriginal;
      valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;
      servicoIdFinal = _servicosIdsSelecionados.first; 
    }

    List<DateTime> datasParaSalvar = [];
    if (_editando || _tipoRepeticao == 'nenhum') {
      datasParaSalvar.add(_data);
    } else {
      DateTime dataAtual = _data;
      for (int i = 0; i < _ocorrencias; i++) {
        datasParaSalvar.add(dataAtual);
        if (_tipoRepeticao == 'semanal') {
          dataAtual = dataAtual.add(const Duration(days: 7));
        } else if (_tipoRepeticao == 'quinzenal') {
          dataAtual = dataAtual.add(const Duration(days: 15));
        } else if (_tipoRepeticao == 'mensal') {
          dataAtual = DateTime(dataAtual.year, dataAtual.month + 1, dataAtual.day);
        }
      }
    }

    for (final d in datasParaSalvar) {
      final conflito = await _verificarConflitoDeHorarioParaData(d);
      if (conflito) {
        final diaConflito = _formatarDataGoogle(d);
        setState(() => _erro = '⚠️ Conflito de horário detectado no dia: $diaConflito. Modifique a data/hora ou cancele a repetição.');
        return;
      }
    }

    final duracaoCalculada = _calcularDuracaoEmMinutos(_horaInicio, _horaFim);

    for (final d in datasParaSalvar) {
      final agendamento = _editando
          ? _original!.copyWith(
              clienteId: _isBloqueio ? 'BLOQUEIO' : _clienteId,
              data: d,
              horaInicio: _formatarHora(_horaInicio),
              horaFim: _formatarHora(_horaFim),
              duracaoMinutos: duracaoCalculada,
              servico: nomeServico,
              servicoId: servicoIdFinal,
              valor: valor,
              observacao: _observacaoController.text.trim(),
              status: _isBloqueio ? AgendamentoStatus.concluido : _original!.status, 
            )
          : Agendamento(
              id: const Uuid().v4(), 
              clienteId: _isBloqueio ? 'BLOQUEIO' : _clienteId!,
              data: d,
              horaInicio: _formatarHora(_horaInicio),
              horaFim: _formatarHora(_horaFim),
              duracaoMinutos: duracaoCalculada,
              servico: nomeServico,
              servicoId: servicoIdFinal,
              valor: valor,
              status: _isBloqueio ? AgendamentoStatus.concluido : AgendamentoStatus.agendado,
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
    }

    if (mounted) context.pop();
  }

  void _abrirModalServicos(List<Servico> todosServicos) {
    FocusScope.of(context).unfocus();
    final buscaModalController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final textoBusca = buscaModalController.text.trim().toLowerCase();
            final servicosDisponiveis = todosServicos;
            final ultimos5Servicos = servicosDisponiveis.where((s) => _ultimosServicosIds.contains(s.id)).toList();
            if (ultimos5Servicos.isEmpty && _ultimosServicosIds.isEmpty) {
              ultimos5Servicos.addAll(servicosDisponiveis.take(5));
            }

            final buscaAtiva = textoBusca.isNotEmpty;
            final listaExibicao = buscaAtiva 
              ? servicosDisponiveis.where((s) => s.nome.toLowerCase().contains(textoBusca)).toList()
              : servicosDisponiveis;

            void _toggleServico(Servico s) {
              setModalState(() {
                if (_servicosIdsSelecionados.contains(s.id)) {
                  _servicosIdsSelecionados.remove(s.id);
                } else {
                  _servicosIdsSelecionados.add(s.id);
                }
              });
              setState(() {
                _recalcularTotais();
              });
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(modalCtx).size.height * 0.85,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Selecionar Serviços', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: buscaModalController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar serviço por nome...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    
                    if (!buscaAtiva && ultimos5Servicos.isNotEmpty) ...[
                      const Text('⭐ Últimos Utilizados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: ultimos5Servicos.map((s) {
                          final isSelected = _servicosIdsSelecionados.contains(s.id);
                          return ActionChip(
                            label: Text(s.nome, style: TextStyle(color: isSelected ? Colors.white : Colors.purple.shade900, fontSize: 12)),
                            backgroundColor: isSelected ? Colors.purple : Colors.purple.shade50,
                            side: BorderSide(color: isSelected ? Colors.purple : Colors.purple.shade200),
                            avatar: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                            onPressed: () => _toggleServico(s),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                    ],

                    const Text('Todos os Serviços (Pode selecionar vários)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),

                    Expanded(
                      child: listaExibicao.isEmpty
                          ? const Center(child: Text('Nenhum serviço encontrado.', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              itemCount: listaExibicao.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final s = listaExibicao[i];
                                final isSelected = _servicosIdsSelecionados.contains(s.id);
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(s.nome, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isSelected ? Colors.purple.shade900 : Colors.black87)),
                                  subtitle: Text('R\$ ${s.valor.toStringAsFixed(2)} · ${s.duracaoMin}m'),
                                  trailing: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.green : Colors.grey.shade400, size: 28),
                                  onTap: () => _toggleServico(s),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar Seleção', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(modalCtx),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    _buscaClienteController.dispose();
    _motivoBloqueioController.dispose();
    super.dispose();
  }

  Widget _construirSeletorCliente() {
    final clientesAsync = ref.watch(clienteControllerProvider);

    return clientesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro ao carregar clientes: $e'),
      data: (clientes) {
        if (clientes.isEmpty) {
          return const Text('Cadastre um cliente antes de criar um agendamento.');
        }

        final textoBusca = _buscaClienteController.text.trim().toLowerCase();
        
        final clientesFiltrados = textoBusca.isEmpty
            ? clientes 
            : clientes.where((c) => c.nome.toLowerCase().contains(textoBusca) || c.telefone.contains(textoBusca)).toList();
                
        Widget? alertaAniversario;
        if (_clienteId != null) {
          try {
            final clienteAtual = clientes.firstWhere((c) => c.id == _clienteId);
            if (clienteAtual.aniversario != null) {
              final hoje = DateTime.now();
              final hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);
              var niverEsteAno = DateTime(hoje.year, clienteAtual.aniversario!.month, clienteAtual.aniversario!.day);
              
              if (niverEsteAno.isBefore(hojeZerado)) {
                niverEsteAno = DateTime(hoje.year + 1, clienteAtual.aniversario!.month, clienteAtual.aniversario!.day);
              }
              
              final diff = niverEsteAno.difference(hojeZerado).inDays;
              if (diff >= 0 && diff <= 15) {
                final dia = clienteAtual.aniversario!.day.toString().padLeft(2, '0');
                final mes = clienteAtual.aniversario!.month.toString().padLeft(2, '0');
                alertaAniversario = Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.purple.shade50, border: Border.all(color: Colors.purple.shade200), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.cake, color: Colors.purple),
                        const SizedBox(width: 8),
                        Expanded(child: Text('🎉 Atenção: Aniversário chegando dia $dia/$mes! Que tal oferecer um mimo ou desconto?', style: TextStyle(color: Colors.purple.shade800, fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                  ),
                );
              }
            }
          } catch (_) {}
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_editando || _clienteId == null) ...[
              TextField(
                controller: _buscaClienteController,
                decoration: const InputDecoration(labelText: 'Cliente', hintText: 'Buscar cliente por nome ou telefone...', prefixIcon: Icon(Icons.search)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),

              if (clientesFiltrados.isNotEmpty)
                SizedBox(
                  height: 180, 
                  child: ListView.builder(
                    shrinkWrap: true, itemCount: clientesFiltrados.length,
                    itemBuilder: (context, index) {
                      final cliente = clientesFiltrados[index];
                      final selecionado = _clienteId == cliente.id;
                      return ListTile(
                        leading: selecionado ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        title: Text(cliente.nome), subtitle: Text(cliente.telefone), selected: selecionado,
                        onTap: () {
                          setState(() { _clienteId = cliente.id; _buscaClienteController.clear(); FocusScope.of(context).unfocus(); });
                        },
                      );
                    },
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      const Center(child: Text('Nenhuma cliente encontrada.', style: TextStyle(color: Colors.grey))),
                      const SizedBox(height: 8),
                      Center(child: TextButton.icon(onPressed: () => context.push(AppRoutes.clienteNovo), icon: const Icon(Icons.add), label: const Text('Cadastrar nova cliente'))),
                    ],
                  ),
                ),
            ],

            if (_clienteId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue.shade200, width: 1.5), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 18, backgroundColor: Colors.blue.shade50, child: Icon(Icons.person, size: 20, color: Colors.blue.shade800)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cliente Vinculada', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(clientes.firstWhere((c) => c.id == _clienteId).nome, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                          ),
                          if (_editando && _original != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _original!.status == AgendamentoStatus.concluido ? Colors.blue.shade100 : (_original!.status == AgendamentoStatus.confirmado ? Colors.green.shade100 : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(6)
                              ),
                              child: Text(_original!.status.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87))
                            )
                        ],
                      ),
                      
                      if (_editando && !_isBloqueio && _original != null) ...[
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                        const Text('Ações Rápidas do Agendamento:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.chat, size: 16, color: Colors.green),
                              label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              backgroundColor: Colors.green.shade50, side: BorderSide(color: Colors.green.shade200),
                              onPressed: () {
                                final clienteAtual = clientes.firstWhere((c) => c.id == _clienteId);
                                WhatsAppService.enviarConfirmacao(telefone: clienteAtual.telefone, nomeCliente: clienteAtual.nome, agendamento: _original!);
                              }
                            ),
                            if (_original!.status == AgendamentoStatus.agendado)
                              ActionChip(
                                avatar: const Icon(Icons.verified_outlined, size: 16, color: Colors.blue),
                                label: const Text('Confirmar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.blue.shade50, side: BorderSide(color: Colors.blue.shade200),
                                onPressed: () async {
                                  final att = _original!.copyWith(status: AgendamentoStatus.confirmado);
                                  await ref.read(agendamentoControllerProvider.notifier).salvar(att, novo: false);
                                  setState(() => _original = att);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirmado com sucesso!'), backgroundColor: Colors.green));
                                }
                              ),
                            if (_original!.status == AgendamentoStatus.agendado || _original!.status == AgendamentoStatus.confirmado)
                              ActionChip(
                                avatar: const Icon(Icons.check_circle_outline, size: 16, color: Colors.indigo),
                                label: const Text('Concluir e Receber', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.indigo.shade50, side: BorderSide(color: Colors.indigo.shade200),
                                onPressed: () {
                                  final clienteAtual = clientes.firstWhere((c) => c.id == _clienteId);
                                  _abrirModalComandaCompleto(context, ref, _original!, clienteAtual.nome);
                                }
                              ),
                            if (_original!.status == AgendamentoStatus.concluido)
                              ActionChip(
                                avatar: const Icon(Icons.settings_backup_restore, size: 16, color: Colors.orange),
                                label: const Text('Reabrir Comanda', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.orange.shade50, side: BorderSide(color: Colors.orange.shade200),
                                onPressed: () async {
                                  final att = _original!.copyWith(status: AgendamentoStatus.agendado);
                                  await ref.read(agendamentoControllerProvider.notifier).salvar(att, novo: false);
                                  setState(() => _original = att);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comanda reaberta.'), backgroundColor: Colors.orange));
                                }
                              ),
                            if (_original!.status != AgendamentoStatus.cancelado)
                              ActionChip(
                                avatar: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                label: const Text('Cancelar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.red.shade50, side: BorderSide(color: Colors.red.shade200),
                                onPressed: () => _abrirModalCancelamento(context),
                              ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              ),
              
            if (alertaAniversario != null) alertaAniversario,
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

    final servicosAsync = ref.watch(servicoControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Horário' : 'Novo Horário'),
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
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Agendamento', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: true, label: Text('Bloqueio (Pessoal)', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_isBloqueio},
                    onSelectionChanged: (set) => setState(() => _isBloqueio = set.first),
                  ),
                  const SizedBox(height: 20),

                  if (!_isBloqueio) ...[
                    _construirSeletorCliente(),
                    const SizedBox(height: 12),
                    servicosAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Erro ao carregar serviços: $e'),
                      data: (servicos) {
                        if (servicos.isEmpty) return const Text('Cadastre ao menos um serviço.');

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Serviços (Selecione um ou mais)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 6),
                            
                            if (_servicosIdsSelecionados.isEmpty)
                              InkWell(
                                onTap: () => _abrirModalServicos(servicos),
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.add_circle_outline, color: Colors.purple), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                                  child: const Text('Toque para selecionar serviços', style: TextStyle(fontSize: 15, color: Colors.grey)),
                                ),
                              )
                            else ...[
                              ...List.generate(_servicosIdsSelecionados.length, (index) {
                                final id = _servicosIdsSelecionados[index];
                                final s = servicos.firstWhere((x) => x.id == id, orElse: () => Servico(id: id, nome: 'Desconhecido', valor: 0, duracaoMin: 0, corValor: 0, createdAt: DateTime.now()));
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.shade200, width: 1.5)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.nome, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                                          Text('R\$ ${s.valor.toStringAsFixed(2)} · ${s.duracaoMin} min', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _servicosIdsSelecionados.removeAt(index);
                                            _recalcularTotais();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                          child: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                onPressed: () => _abrirModalServicos(servicos),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Adicionar mais serviços nesta comanda'),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Colors.purple.shade300)),
                              ),
                            ],
                          ], // 🐛 FIX: Vírgula adicionada aqui (em vez de ; )
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ] 
                  else ...[
                    TextFormField(
                      controller: _motivoBloqueioController,
                      decoration: const InputDecoration(labelText: 'Motivo (Ex: Academia, Almoço, Médico)', prefixIcon: Icon(Icons.block, color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      Expanded(child: InkWell(onTap: _selecionarData, child: InputDecorator(decoration: const InputDecoration(labelText: 'Data'), child: Text(_formatarDataGoogle(_data))))),
                      if (!_isBloqueio) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _valorController,
                            decoration: const InputDecoration(labelText: 'Valor Total (R\$)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  if (!_editando) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _tipoRepeticao,
                            decoration: const InputDecoration(labelText: 'Repetir evento?', prefixIcon: Icon(Icons.event_repeat, color: Colors.grey)),
                            items: const [
                              DropdownMenuItem(value: 'nenhum', child: Text('Não repetir')),
                              DropdownMenuItem(value: 'semanal', child: Text('Toda semana')),
                              DropdownMenuItem(value: 'quinzenal', child: Text('A cada 15 dias')),
                              DropdownMenuItem(value: 'mensal', child: Text('Todo mês')),
                            ],
                            onChanged: (v) => setState(() => _tipoRepeticao = v!),
                          ),
                        ),
                        if (_tipoRepeticao != 'nenhum') ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<int>(
                              value: _ocorrencias,
                              decoration: const InputDecoration(labelText: 'Quantas vezes?'),
                              items: List.generate(11, (i) => i + 2).map((v) => DropdownMenuItem(value: v, child: Text('$v vezes'))).toList(),
                              onChanged: (v) => setState(() => _ocorrencias = v!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: InkWell(onTap: () => _selecionarHora(inicio: true), child: InputDecorator(decoration: const InputDecoration(labelText: 'Hora início'), child: Text(_formatarHora(_horaInicio))))),
                      const SizedBox(width: 12),
                      Expanded(child: InkWell(onTap: () => _selecionarHora(inicio: false), child: InputDecorator(decoration: const InputDecoration(labelText: 'Hora fim'), child: Text(_formatarHora(_horaFim))))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  TextFormField(controller: _observacaoController, decoration: const InputDecoration(labelText: 'Observação extra (Opcional)'), maxLines: 3),
                  
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)),
                      child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Voltar'))),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton(onPressed: _salvar, child: const Text('Salvar Agendamento'))),
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

class ModalFecharComandaForm extends ConsumerStatefulWidget {
  const ModalFecharComandaForm({super.key, required this.agendamento, required this.nomeCliente, required this.onConfirmar, required this.onCancelarAtendimento});
  
  final Agendamento agendamento;
  final String nomeCliente;
  final void Function(List<Map<String, dynamic>> pagamentos, double valorFinal, bool houveAtraso, List<Insumo> insumosAcabaram, List<Insumo> produtosUtilizados) onConfirmar;
  final VoidCallback onCancelarAtendimento;
  
  @override
  ConsumerState<ModalFecharComandaForm> createState() => _ModalFecharComandaFormState();
}

class _ModalFecharComandaFormState extends ConsumerState<ModalFecharComandaForm> {
  late double _valorTotal;
  bool _houveAtraso = false;
  
  DateTime _dataPagamentoAtual = DateTime.now(); 
  final List<Map<String, dynamic>> _pagamentos = [];
  FormaPagamento _formaAtual = FormaPagamento.pix;
  final TextEditingController _valorParcialController = TextEditingController();

  final List<Insumo> _insumosAcabaram = [];
  final List<Insumo> _produtosUtilizados = []; 

  @override
  void initState() {
    super.initState();
    _valorTotal = widget.agendamento.valor;
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
        _dataPagamentoAtual = DateTime.now(); 
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
                          : ListView.separated(
                              itemCount: listaExibicao.length, separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (c, i) {
                                final item = listaExibicao[i];
                                final isSelected = _produtosUtilizados.contains(item);
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.nome, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? Colors.purple.shade900 : Colors.black87)),
                                  subtitle: Text(item.categoria, style: const TextStyle(fontSize: 12)),
                                  trailing: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? Colors.purple : Colors.grey),
                                  onTap: () => _toggleInsumo(item),
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
            final listaExibicao = textoBusca.isEmpty ? disponiveis : disponiveis.where((e) => e.nome.toLowerCase().contains(textoBusca) || e.categoria.toLowerCase().contains(textoBusca)).toList();

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
                          : ListView.separated(
                              itemCount: listaExibicao.length, separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (c, i) {
                                final item = listaExibicao[i];
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
                                                Navigator.pop(ctx); 
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                onTap: () async { final picked = await showDatePicker(context: context, initialDate: _dataPagamentoAtual, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setState(() => _dataPagamentoAtual = picked); },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.purple), const SizedBox(width: 8), Text('Data: ${_dataPagamentoAtual.day.toString().padLeft(2, '0')}/${_dataPagamentoAtual.month.toString().padLeft(2, '0')}/${_dataPagamentoAtual.year}', style: const TextStyle(fontSize: 14))])),
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
                  estoqueAsync.when(loading: () => const LinearProgressIndicator(), error: (_, __) => const Text('Erro.'), data: (estoqueGlobal) { return OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.purple.shade800, side: BorderSide(color: Colors.purple.shade200), backgroundColor: Colors.white), onPressed: () => _abrirModalProdutosUtilizados(estoqueGlobal), icon: const Icon(Icons.format_paint, size: 18), label: const Text('Selecionar Produtos Utilizados')); })
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
                    Wrap(spacing: 8, runSpacing: -8, children: _insumosAcabaram.map((insumo) => Chip(label: Text(insumo.nome, style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.bold)), onDeleted: () => setState(() => _insumosAcabaram.remove(insumo)), backgroundColor: Colors.red.shade50, deleteIconColor: Colors.red.shade300, side: BorderSide(color: Colors.red.shade200))).toList()),
                    const SizedBox(height: 8),
                  ],
                  estoqueAsync.when(loading: () => const LinearProgressIndicator(), error: (_, __) => const Text('Erro.'), data: (estoqueGlobal) { return OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade800, side: BorderSide(color: Colors.red.shade200), backgroundColor: Colors.white), onPressed: () => _abrirSeletorInsumo(estoqueGlobal), icon: const Icon(Icons.delete_sweep, size: 18), label: const Text('Registrar pote vazio (Baixa)')); })
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            CheckboxListTile(value: _houveAtraso, contentPadding: EdgeInsets.zero, title: const Text('Cliente chegou atrasada?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)), subtitle: const Text('Registra o atraso no histórico para métricas.', style: TextStyle(fontSize: 11, color: Colors.grey)), controlAffinity: ListTileControlAffinity.leading, onChanged: (val) => setState(() => _houveAtraso = val ?? false)),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(flex: 1, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () { Navigator.pop(context); widget.onCancelarAtendimento(); }, child: const Text('Cancelar\nAtendimento', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: _podeConfirmar ? Colors.green.shade700 : Colors.grey),
                    onPressed: _podeConfirmar ? () {
                      if (_valorRestante > 0.01) _pagamentos.add({'forma': _formaAtual, 'valor': _valorRestante, 'data': _dataPagamentoAtual});
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
