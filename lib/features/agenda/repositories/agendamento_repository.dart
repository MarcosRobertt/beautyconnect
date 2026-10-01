import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/storage/storage_service.dart';
import '../models/agendamento.dart';

bool _mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _inicioDaSemana(DateTime data) {
  final d = DateTime(data.year, data.month, data.day);
  return d.subtract(Duration(days: d.weekday % 7)); 
}

class AgendamentoRepository {
  AgendamentoRepository(this._storage);

  final StorageService<Agendamento> _storage;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Agendamento>> listarTodos() async {
    final snapshot = await _firestore.collection('agendamentos').get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs.map((doc) => Agendamento.fromJson(doc.data())).toList();
  }

  Future<List<Agendamento>> listarDia(DateTime dia) async {
    final todos = await listarTodos();
    final lista = todos.where((a) => _mesmoDia(a.data, dia)).toList();
    lista.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    return lista;
  }

  Future<List<Agendamento>> listarSemana(DateTime referencia) async {
    final inicio = _inicioDaSemana(referencia);
    final fim = inicio.add(const Duration(days: 6));
    final todos = await listarTodos();
    final lista = todos.where((a) => !a.data.isBefore(inicio) && !a.data.isAfter(fim)).toList();
    
    lista.sort((a, b) {
      final cmpData = a.data.compareTo(b.data);
      return cmpData != 0 ? cmpData : a.horaInicio.compareTo(b.horaInicio);
    });
    return lista;
  }

  Future<List<Agendamento>> listarMes(DateTime referencia) async {
    final todos = await listarTodos();
    final lista = todos.where((a) => a.data.year == referencia.year && a.data.month == referencia.month).toList();
    
    lista.sort((a, b) {
      final cmpData = a.data.compareTo(b.data);
      return cmpData != 0 ? cmpData : a.horaInicio.compareTo(b.horaInicio);
    });
    return lista;
  }

  int _horaParaMinutos(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  bool _temSobreposicao(String inicio1, String fim1, String inicio2, String fim2) {
    final min1 = _horaParaMinutos(inicio1);
    final min2 = _horaParaMinutos(fim1);
    final min3 = _horaParaMinutos(inicio2);
    final min4 = _horaParaMinutos(fim2);
    return min1 < min4 && min3 < min2;
  }

  Future<bool> existeConflito(Agendamento novo, {String? ignorarId}) async {
    final todos = await listarTodos();
    return todos.any((a) =>
        a.id != ignorarId &&
        a.status != AgendamentoStatus.cancelado &&
        _mesmoDia(a.data, novo.data) &&
        _temSobreposicao(a.horaInicio, a.horaFim, novo.horaInicio, novo.horaFim));
  }

  Future<void> novo(Agendamento agendamento) async {
    final conflito = await existeConflito(agendamento);
    if (conflito) {
      throw Exception('Já existe um agendamento não cancelado nesse dia e horário.');
    }
    await _firestore.collection('agendamentos').doc(agendamento.id).set(agendamento.toJson());
  }

  Future<Agendamento?> _buscarNaNuvem(String id) async {
    final doc = await _firestore.collection('agendamentos').doc(id).get(const GetOptions(source: Source.server));
    if (!doc.exists || doc.data() == null) return null;
    return Agendamento.fromJson(doc.data()!);
  }

  Future<void> editar(Agendamento agendamento) async {
    final atual = await _buscarNaNuvem(agendamento.id);
    
    bool mudouHorario = true;
    if (atual != null) {
      if (_mesmoDia(atual.data, agendamento.data) && 
          atual.horaInicio == agendamento.horaInicio && 
          atual.horaFim == agendamento.horaFim) {
        mudouHorario = false; 
      }
    }

    if (mudouHorario) {
      final conflito = await existeConflito(agendamento, ignorarId: agendamento.id);
      if (conflito) {
        throw Exception('BLOQUEIO DE CONFLITO: Já existe outra agenda bloqueando esse mesmo horário.');
      }
    }
    
    await _firestore.collection('agendamentos').doc(agendamento.id).update(agendamento.toJson());
  }

  Future<void> cancelar(String id) async {
    final atual = await _buscarNaNuvem(id);
    if (atual == null) throw Exception("Comanda Fantasma! O agendamento não foi encontrado no servidor.");
    final alterado = atual.copyWith(status: AgendamentoStatus.cancelado, updatedAt: DateTime.now());
    await _firestore.collection('agendamentos').doc(id).update(alterado.toJson());
  }

  Future<void> confirmar(String id) async {
    final atual = await _buscarNaNuvem(id);
    if (atual == null) throw Exception("Comanda Fantasma! O agendamento não foi encontrado no servidor.");
    final alterado = atual.copyWith(status: AgendamentoStatus.confirmado, updatedAt: DateTime.now());
    await _firestore.collection('agendamentos').doc(id).update(alterado.toJson());
  }

  Future<void> concluir(String id) async {
    final atual = await _buscarNaNuvem(id);
    if (atual == null) throw Exception("Comanda Fantasma! O agendamento não foi encontrado no servidor.");
    final alterado = atual.copyWith(status: AgendamentoStatus.concluido, updatedAt: DateTime.now());
    await _firestore.collection('agendamentos').doc(id).update(alterado.toJson());
  }

  Future<void> substituirTudo(List<Agendamento> novos) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore.collection('agendamentos').get();
    for (final doc in snapshot.docs) { batch.delete(doc.reference); }
    for (final a in novos) {
      final docRef = _firestore.collection('agendamentos').doc(a.id);
      batch.set(docRef, a.toJson());
    }
    await batch.commit();
  }
}
