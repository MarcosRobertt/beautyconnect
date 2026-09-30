// ============================================================================
// 🛡️ MÓDULO DE MANUTENÇÃO DE DADOS (Limpeza ROOT Direto no Banco)
// ============================================================================
class BotaoManutencaoFirebase extends ConsumerStatefulWidget {
  const BotaoManutencaoFirebase({super.key});

  @override
  ConsumerState<BotaoManutencaoFirebase> createState() => _BotaoManutencaoFirebaseState();
}

class _BotaoManutencaoFirebaseState extends ConsumerState<BotaoManutencaoFirebase> {
  bool _executandoLimpeza = false;

  Future<void> _executarLimpezaFantasmas() async {
    setState(() => _executandoLimpeza = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Busca os clientes REAIS direto no servidor (Ignora a memória do app)
      final clientesSnap = await firestore.collection('clientes').get();
      final List<String> idsValidos = clientesSnap.docs.map((doc) => doc.id).toList();

      if (idsValidos.isEmpty) {
        throw Exception("Nenhum cliente encontrado no banco de dados. Abortando por segurança.");
      }

      // 2. Busca a agenda REAL direto no servidor
      final agendamentosSnap = await firestore.collection('agendamentos').get();

      final batch = firestore.batch();
      int orfaosEncontrados = 0;

      for (final doc in agendamentosSnap.docs) {
        final data = doc.data();
        final clienteId = data['clienteId']?.toString() ?? '';
        final status = data['status']?.toString().toLowerCase() ?? ''; 

        // Se não for um bloqueio da agenda e o ID não estiver vazio...
        if (clienteId != 'BLOQUEIO' && clienteId.isNotEmpty) {
          
          // Se o ID da comanda NÃO existe na tabela de clientes vivos...
          if (!idsValidos.contains(clienteId)) {
            
            // 🛡️ MITIGAÇÃO: Se não tiver a palavra "concluido" no status, pode apagar!
            if (!status.contains('concluido')) {
              batch.delete(doc.reference);
              orfaosEncontrados++;
            }
          }
        }
      }

      // 3. Executa a limpeza
      if (orfaosEncontrados > 0) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ SUCESSO! $orfaosEncontrados agendamentos fantasmas foram apagados direto do banco.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhuma comanda fantasma aberta encontrada no banco.'), backgroundColor: Colors.blue),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🚨 Erro na faxina: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _executandoLimpeza = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.red.shade800),
                const SizedBox(width: 8),
                Text('Limpeza ROOT (Banco de Dados)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Comunicação direta com o servidor para apagar agendamentos ABERTOS de clientes excluídas.', style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: _executandoLimpeza ? null : _executarLimpezaFantasmas,
                icon: _executandoLimpeza ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.delete_sweep),
                label: Text(_executandoLimpeza ? 'Acessando Banco...' : 'Apagar Comandas Travadas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
