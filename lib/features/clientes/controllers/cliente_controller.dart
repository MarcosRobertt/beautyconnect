import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cliente.dart';

final clienteControllerProvider = StateNotifierProvider<ClienteController, AsyncValue<List<Cliente>>>((ref) {
  return ClienteController();
});

class ClienteController extends StateNotifier<AsyncValue<List<Cliente>>> {
  ClienteController() : super(const AsyncValue.loading()) {
    carregarClientes();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ouve as alterações na coleção de clientes em tempo real
  Future<void> carregarClientes() async {
    try {
      _db.collection('clientes').snapshots().listen((snapshot) {
        final lista = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Cliente.fromMap(data);
        }).toList();
        
        state = AsyncValue.data(lista);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Salva um novo cliente ou atualiza um existente ignorando o próprio ID na validação de duplicidade
  Future<void> salvar(Cliente cliente) async {
    final clientesAtuais = state.value ?? [];

    // Higieniza o número removendo formatação (espaços, traços, parênteses)
    final telLimpoNovo = cliente.telefone.replaceAll(RegExp(r'\D'), '');

    if (telLimpoNovo.isNotEmpty) {
      // Verifica se o telefone pertence a um cliente DIFERENTE do que está sendo editado
      final jaExisteOutro = clientesAtuais.any((c) {
        final telLimpoExistente = c.telefone.replaceAll(RegExp(r'\D'), '');
        
        final ehMesmoTelefone = telLimpoExistente == telLimpoNovo;
        final ehOutroCliente = c.id != cliente.id; // Permite edição se for o mesmo ID

        return ehMesmoTelefone && ehOutroCliente;
      });

      if (jaExisteOutro) {
        throw Exception('Este número de telefone já está cadastrado para outro cliente.');
      }
    }

    final mapData = cliente.toMap();

    if (cliente.id.isEmpty) {
      // Novo Cadastro
      final docRef = await _db.collection('clientes').add(mapData);
      await docRef.update({'id': docRef.id});
    } else {
      // Edição de Cadastro Existente
      await _db.collection('clientes').doc(cliente.id).set(
        mapData,
        SetOptions(merge: true),
      );
    }
  }

  /// Remove um cliente da base de dados
  Future<void> deletar(String id) async {
    if (id.isNotEmpty) {
      await _db.collection('clientes').doc(id).delete();
    }
  }

  /// Retorna lista de clientes com nomes parecidos para alerta preventivo não-bloqueante
  List<Cliente> verificarNomesSemelhantes(String nome, {String? idAtual}) {
    if (nome.trim().length < 3) return [];
    final clientesAtuais = state.value ?? [];
    final nomeLower = nome.toLowerCase().trim();

    return clientesAtuais.where((c) {
      final ehOutro = c.id != idAtual;
      final contemNome = c.nome.toLowerCase().contains(nomeLower);
      return ehOutro && contemNome;
    }).toList();
  }
}
