import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../agenda/services/inteligencia_service.dart';
import '../models/cliente.dart';

class ClienteCard extends StatelessWidget {
  const ClienteCard({
    super.key,
    required this.cliente,
    required this.onEditar,
    required this.onExcluir,
    required this.onHistorico,
    this.inteligencia,
  });

  final Cliente cliente;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onHistorico;

  /// Último atendimento / próxima data sugerida, já calculados pela tela
  /// (ver InteligenciaService). Nulo enquanto os agendamentos ainda carregam.
  final InteligenciaCliente? inteligencia;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cliente.nome, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.phone, size: 12),
                    const SizedBox(width: 4),
                    Text(cliente.telefone, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  if (cliente.aniversario != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.cake_outlined, size: 12),
                      const SizedBox(width: 4),
                      Text(fmt.format(cliente.aniversario!), style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ],
                  if (inteligencia != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.history, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        inteligencia!.ultimoAtendimento != null
                            ? 'Último atendimento: ${fmt.format(inteligencia!.ultimoAtendimento!)}'
                            : 'Sem atendimentos concluídos ainda',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]),
                    if (inteligencia!.proximaDataSugerida != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.event_repeat, size: 12, color: inteligencia!.atrasado ? Theme.of(context).colorScheme.error : null),
                        const SizedBox(width: 4),
                        Text(
                          'Retorno sugerido: ${fmt.format(inteligencia!.proximaDataSugerida!)}${inteligencia!.atrasado ? " (atrasado)" : ""}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: inteligencia!.atrasado ? Theme.of(context).colorScheme.error : null,
                                fontWeight: inteligencia!.atrasado ? FontWeight.w600 : null,
                              ),
                        ),
                      ]),
                    ],
                  ],
                  if (cliente.observacoes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(cliente.observacoes,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(onPressed: onHistorico, icon: const Icon(Icons.receipt_long_outlined, size: 18), tooltip: 'Histórico'),
                IconButton(onPressed: onEditar, icon: const Icon(Icons.edit_outlined, size: 18)),
                IconButton(onPressed: onExcluir, icon: const Icon(Icons.delete_outline, size: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
