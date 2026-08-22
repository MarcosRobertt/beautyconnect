import 'package:flutter/material.dart';
import '../../../core/services/whatsapp_service.dart';
import '../models/cliente.dart';

class ClienteCard extends StatelessWidget {
  const ClienteCard({
    super.key,
    required this.cliente,
    required this.inteligencia,
    required this.onEditar,
    required this.onExcluir,
    required this.onHistorico,
  });

  final Cliente cliente;
  final Map<String, dynamic> inteligencia;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onHistorico;

  @override
  Widget build(BuildContext context) {
    final int diasAusente = inteligencia['diasAusente'] ?? 0;
    final int totalVisitas = inteligencia['totalVisitas'] ?? 0;
    final double totalGasto = inteligencia['totalGasto'] ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.shade50,
                  child: Text(
                    cliente.nome[0].toUpperCase(),
                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(cliente.telefone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.purple),
                  tooltip: 'Histórico',
                  onPressed: onHistorico,
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$totalVisitas visita(s)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text('R\$ ${totalGasto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                // BOTÃO DE AÇÃO RÁPIDA WHATSAPP
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: () => WhatsAppService.enviarReativacao(
                      cliente: cliente,
                      diasAusente: diasAusente,
                    ),
                    icon: const Icon(Icons.chat, size: 14),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEditar),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: onExcluir),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
