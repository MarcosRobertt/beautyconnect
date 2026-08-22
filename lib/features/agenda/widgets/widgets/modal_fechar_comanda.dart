import 'package:flutter/material.dart';
import '../models/agendamento.dart';

class ModalFecharComanda extends StatefulWidget {
  const ModalFecharComanda({
    super.key,
    required this.agendamento,
    required this.nomeCliente,
    required this.onConfirmar,
  });

  final Agendamento agendamento;
  final String nomeCliente;
  final Function(FormaPagamento forma, double valorFinal) onConfirmar;

  @override
  State<ModalFecharComanda> createState() => _ModalFecharComandaState();
}

class _ModalFecharComandaState extends State<ModalFecharComanda> {
  late double _valorFinal;
  FormaPagamento _formaSelecionada = FormaPagamento.pix;

  @override
  void initState() {
    super.initState();
    _valorFinal = widget.agendamento.valor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _formaSelecionada == FormaPagamento.pendente
                  ? 'Manter Comanda Aberta'
                  : 'Confirmar Recebimento',
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onConfirmar(_formaSelecionada, _valorFinal);
            },
          ),
        ],
      ),
    );
  }
}
