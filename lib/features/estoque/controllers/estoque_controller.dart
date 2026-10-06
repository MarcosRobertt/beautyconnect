import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/insumo.dart';

final estoqueControllerProvider = StateNotifierProvider<EstoqueController, AsyncValue<List<Insumo>>>((ref) {
  return EstoqueController();
});

class EstoqueController extends StateNotifier<AsyncValue<List<Insumo>>> {
  EstoqueController() : super(const AsyncValue.loading()) {
    carregarInsumos();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void carregarInsumos() {
    try {
      _db.collection('estoque').snapshots().listen((snapshot) {
        final lista = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Insumo.fromMap(data);
        }).toList();

        lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        state = AsyncValue.data(lista);
      }, onError: (e, stack) {
        state = AsyncValue.error(e, stack);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> salvar(Insumo insumo) async {
    final mapData = insumo.toMap();

    if (insumo.id.isEmpty) {
      final docRef = await _db.collection('estoque').add(mapData);
      await docRef.update({'id': docRef.id});
    } else {
      await _db.collection('estoque').doc(insumo.id).set(
        mapData,
        SetOptions(merge: true),
      );
    }
  }

  Future<void> deletar(String id) async {
    if (id.isNotEmpty) {
      await _db.collection('estoque').doc(id).delete();
    }
  }

  Future<void> iniciarPote(Insumo insumo) async {
    final novoCiclo = CicloDeUso(
      id: const Uuid().v4(),
      dataAbertura: DateTime.now(),
    );
    
    final listaAtualizada = List<CicloDeUso>.from(insumo.ciclosDeUso)..add(novoCiclo);
    final novoEstoque = insumo.quantidade > 0 ? insumo.quantidade - 1 : 0;
    
    await _db.collection('estoque').doc(insumo.id).update({
      'quantidade': novoEstoque,
      'ciclosDeUso': listaAtualizada.map((c) => c.toMap()).toList(),
    });
  }

  Future<void> finalizarPoteAberto(Insumo insumo) async {
    final indexAberto = insumo.ciclosDeUso.indexWhere((c) => c.dataFim == null);
    if (indexAberto == -1) return; 

    final listaAtualizada = List<CicloDeUso>.from(insumo.ciclosDeUso);
    final cicloAntigo = listaAtualizada[indexAberto];
    
    listaAtualizada[indexAberto] = CicloDeUso(
      id: cicloAntigo.id,
      dataAbertura: cicloAntigo.dataAbertura,
      dataFim: DateTime.now(), 
    );

    await _db.collection('estoque').doc(insumo.id).update({
      'ciclosDeUso': listaAtualizada.map((c) => c.toMap()).toList(),
    });
  }
}

// ==========================================
// 🧠 O CÉREBRO DA IA (FILTRANDO POR MÊS)
// ==========================================

class RelatorioIA {
  final Insumo insumo;
  final int totalServicos;
  final double custoPorProcedimento;
  final int duracaoMediaDias;
  final String insightTexto;
  final bool alertaCustoAlto;

  RelatorioIA({
    required this.insumo,
    required this.totalServicos,
    required this.custoPorProcedimento,
    required this.duracaoMediaDias,
    required this.insightTexto,
    required this.alertaCustoAlto,
  });
}

// 🧠 NOVO: A IA agora exige o "mesFiltro" para auditar apenas os potes fechados naquele mês
final iaRelatorioProvider = FutureProvider.autoDispose.family<List<RelatorioIA>, DateTime>((ref, mesFiltro) async {
  final db = FirebaseFirestore.instance;
  final insumos = ref.watch(estoqueControllerProvider).value ?? [];
  List<RelatorioIA> relatorios = [];

  for (var insumo in insumos) {
    // 🔍 Filtro: Apenas ciclos que acabaram dentro do mês e ano selecionados na tela
    final ciclosFechadosNoMes = insumo.ciclosDeUso.where((c) {
      if (c.dataFim == null) return false;
      return c.dataFim!.year == mesFiltro.year && c.dataFim!.month == mesFiltro.month;
    }).toList();

    if (ciclosFechadosNoMes.isEmpty) continue; 

    int servicosTotais = 0;
    int diasTotais = 0;

    for (var ciclo in ciclosFechadosNoMes) {
      diasTotais += ciclo.dataFim!.difference(ciclo.dataAbertura).inDays;
      if (diasTotais == 0) diasTotais = 1; 

      try {
        final query = await db.collection('agendamentos')
            .where('status', isEqualTo: 'concluido')
            .where('data', isGreaterThanOrEqualTo: ciclo.dataAbertura.toIso8601String())
            .where('data', isLessThanOrEqualTo: ciclo.dataFim!.toIso8601String())
            .get();

        int count = 0;
        for (var doc in query.docs) {
          final servicoNome = doc.data()['servico']?.toString() ?? '';
          if (insumo.servicosVinculados.contains('Todos') || insumo.servicosVinculados.contains(servicoNome)) {
            count++;
          }
        }
        servicosTotais += count;
      } catch (e) {}
    }

    if (servicosTotais > 0) {
      double custoTotalGasto = insumo.precoPago * ciclosFechadosNoMes.length;
      double custoPorProcedimento = custoTotalGasto / servicosTotais;
      int duracaoMedia = diasTotais ~/ ciclosFechadosNoMes.length;

      String insight = "O produto ${insumo.nome} rendeu em média $duracaoMedia dias por unidade neste mês, atendendo um total de $servicosTotais procedimentos. Seu custo exato por cliente ficou em R\$ ${custoPorProcedimento.toStringAsFixed(2).replaceAll('.', ',')}.";
      
      bool alerta = custoPorProcedimento > (insumo.precoPago * 0.20);
      if (alerta) {
        insight += "\n\n⚠️ ATENÇÃO: O custo deste produto por aplicação está muito alto. Sugerimos verificar o desperdício ou reajustar o valor do serviço cobrado da cliente.";
      }

      relatorios.add(RelatorioIA(
        insumo: insumo,
        totalServicos: servicosTotais,
        custoPorProcedimento: custoPorProcedimento,
        duracaoMediaDias: duracaoMedia,
        insightTexto: insight,
        alertaCustoAlto: alerta,
      ));
    } else {
      relatorios.add(RelatorioIA(
        insumo: insumo,
        totalServicos: 0,
        custoPorProcedimento: insumo.precoPago,
        duracaoMediaDias: diasTotais ~/ ciclosFechadosNoMes.length,
        insightTexto: "Uma unidade de ${insumo.nome} acabou neste mês, mas a IA não encontrou nenhum serviço compatível concluído na Agenda durante o uso. Verifique se você vinculou o produto ao serviço correto.",
        alertaCustoAlto: true,
      ));
    }
  }

  relatorios.sort((a, b) => a.alertaCustoAlto ? -1 : 1);
  return relatorios;
});
