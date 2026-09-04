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
          'A comanda "$nomeServico" possui duração prevista de $duracaoServico minutos.\n\n'
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
      int duracaoTotal = 0;

      for (var id in _servicosIdsSelecionados) {
        try {
          final s = servicos.firstWhere((x) => x.id == id);
          nomesCombinados.add(s.nome);
          duracaoTotal += s.duracaoMin;
        } catch (_) {}
      }

      nomeServico = nomesCombinados.isNotEmpty ? nomesCombinados.join(' + ') : _servicoNomeOriginal;
      
      final duracaoSelecionada = _calcularDuracaoEmMinutos(_horaInicio, _horaFim);
      if (duracaoSelecionada != duracaoTotal && duracaoTotal > 0) {
        final continuar = await _mostrarAlertaDuracao(
          context,
          nomeServico,
          duracaoTotal,
          duracaoSelecionada,
        );
        if (!continuar) return;
      }

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

  // 🚀 MODAL COM BUSCA BLINDADA (Controlador nativo + layout ajustado para teclado)
  void _abrirModalAdicionarServico(List<Servico> todosServicos) {
    FocusScope.of(context).unfocus();
    final buscaModalController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        bool processandoClique = false;
        
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final textoBusca = buscaModalController.text.trim().toLowerCase();

            final servicosDisponiveis = todosServicos
                .where((s) => !_servicosIdsSelecionados.contains(s.id))
                .toList();

            final ultimos5Servicos = servicosDisponiveis
                .where((s) => _ultimosServicosIds.contains(s.id))
                .toList();
            
            if (ultimos5Servicos.isEmpty && _ultimosServicosIds.isEmpty) {
              ultimos5Servicos.addAll(servicosDisponiveis.take(5));
            }

            final buscaAtiva = textoBusca.isNotEmpty;
            final listaExibicao = buscaAtiva 
              ? servicosDisponiveis.where((s) => 
                  s.nome.toLowerCase().contains(textoBusca)
                ).toList()
              : servicosDisponiveis;

            void _adicionarEFechar(Servico s) {
              if (processandoClique) return;
              setModalState(() => processandoClique = true);
              
              setState(() {
                _servicosIdsSelecionados.add(s.id);
                _recalcularTotais();
              });
              
              Navigator.pop(modalCtx);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(modalCtx).size.height * 0.85,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Adicionar Serviço', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: buscaModalController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar serviço por nome...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: buscaModalController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  buscaModalController.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => setModalState(() {}),
                      onSubmitted: (_) => FocusScope.of(modalCtx).unfocus(),
                    ),
                    const SizedBox(height: 12),
                    
                    if (!buscaAtiva && ultimos5Servicos.isNotEmpty) ...[
                      const Text('⭐ Últimos Utilizados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ultimos5Servicos.map((s) => ActionChip(
                          label: Text(s.nome, style: TextStyle(color: Colors.purple.shade900, fontSize: 12)),
                          backgroundColor: Colors.purple.shade50,
                          side: BorderSide(color: Colors.purple.shade200),
                          onPressed: () => _adicionarEFechar(s),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                    ],

                    const Text('Todos os Serviços', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),

                    Expanded(
                      child: listaExibicao.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum serviço encontrado.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: listaExibicao.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final s = listaExibicao[i];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(s.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text('R\$ ${s.valor.toStringAsFixed(2)} · ${s.duracaoMin}m'),
                                  trailing: const Icon(Icons.add_circle_outline, color: Colors.purple),
                                  onTap: () => _adicionarEFechar(s),
                                );
                              },
                            ),
                    ),
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
            : clientes
                .where((c) =>
                    c.nome.toLowerCase().contains(textoBusca) || c.telefone.contains(textoBusca))
                .toList();
                
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
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      border: Border.all(color: Colors.purple.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake, color: Colors.purple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🎉 Atenção: Aniversário chegando dia $dia/$mes! Que tal oferecer um mimo ou desconto?',
                            style: TextStyle(color: Colors.purple.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
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
            TextField(
              controller: _buscaClienteController,
              decoration: const InputDecoration(
                labelText: 'Cliente',
                hintText: 'Buscar cliente por nome ou telefone...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),

            if (clientesFiltrados.isNotEmpty)
              SizedBox(
                height: 180, 
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final cliente = clientesFiltrados[index];
                    final selecionado = _clienteId == cliente.id;

                    return ListTile(
                      leading: selecionado ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      title: Text(cliente.nome),
                      subtitle: Text(cliente.telefone),
                      selected: selecionado,
                      onTap: () {
                        setState(() {
                          _clienteId = cliente.id;
                          _buscaClienteController.clear(); 
                          FocusScope.of(context).unfocus(); 
                        });
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
                    '✓ Cliente selecionada: ${clientes.firstWhere((c) => c.id == _clienteId).nome}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
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
    final clientesAsync = ref.watch(clienteControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Horário' : 'Novo Horário'),
        actions: [
          if (_editando && !_isBloqueio && _original != null && _clienteId != null) ...[
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.green),
              tooltip: 'Enviar Confirmação pelo WhatsApp',
              onPressed: () {
                final clientes = clientesAsync.value ?? [];
                try {
                  final clienteAtual = clientes.firstWhere((c) => c.id == _clienteId);
                  WhatsAppService.enviarConfirmacao(
                    telefone: clienteAtual.telefone,
                    nomeCliente: clienteAtual.nome,
                    agendamento: _original!,
                  );
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao localizar telefone da cliente.')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              tooltip: 'Cancelar Agendamento',
              onPressed: () => _abrirModalCancelamento(context),
            ),
            const SizedBox(width: 8),
          ],
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
                            DropdownMenu<String>(
                              expandedInsets: EdgeInsets.zero,
                              initialSelection: _servicosIdsSelecionados.isNotEmpty ? _servicosIdsSelecionados.first : null,
                              label: const Text('Serviço Principal'),
                              enableFilter: true,
                              dropdownMenuEntries: servicos.map((s) => DropdownMenuEntry(
                                value: s.id,
                                label: '${s.nome} · ${s.duracaoMin}m',
                              )).toList(),
                              onSelected: (v) {
                                if (v != null) {
                                  setState(() {
                                    if (_servicosIdsSelecionados.isEmpty) {
                                      _servicosIdsSelecionados.add(v);
                                    } else {
                                      _servicosIdsSelecionados[0] = v;
                                    }
                                    _recalcularTotais();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            if (_servicosIdsSelecionados.length > 1) ...[
                              const Text('Serviços Adicionais:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 8),
                              ...List.generate(_servicosIdsSelecionados.length - 1, (indexOffset) {
                                final actualIndex = indexOffset + 1;
                                final id = _servicosIdsSelecionados[actualIndex];
                                final s = servicos.firstWhere((x) => x.id == id, orElse: () => Servico(id: id, nome: 'Desconhecido', valor: 0, duracaoMin: 0, corValor: 0, createdAt: DateTime.now()));
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300)
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${s.nome} (+R\$ ${s.valor.toStringAsFixed(0)})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _servicosIdsSelecionados.removeAt(actualIndex);
                                            _recalcularTotais();
                                          });
                                        },
                                        child: const Icon(Icons.close, size: 18, color: Colors.grey),
                                      )
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                            ],

                            OutlinedButton.icon(
                              onPressed: () => _abrirModalAdicionarServico(servicos),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Adicionar serviço'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ] 
                  else ...[
                    TextFormField(
                      controller: _motivoBloqueioController,
                      decoration: const InputDecoration(
                        labelText: 'Motivo (Ex: Academia, Almoço, Médico)',
                        prefixIcon: Icon(Icons.block, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selecionarData,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Data'),
                            child: Text(_formatarDataGoogle(_data)),
                          ),
                        ),
                      ),
                      if (!_isBloqueio) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _valorController,
                            decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            decoration: const InputDecoration(
                              labelText: 'Repetir evento?',
                              prefixIcon: Icon(Icons.event_repeat, color: Colors.grey),
                            ),
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
                              items: List.generate(11, (i) => i + 2) 
                                  .map((v) => DropdownMenuItem(value: v, child: Text('$v vezes')))
                                  .toList(),
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
                    decoration: const InputDecoration(labelText: 'Observação extra (Opcional)'),
                    maxLines: 3,
                  ),
                  
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
