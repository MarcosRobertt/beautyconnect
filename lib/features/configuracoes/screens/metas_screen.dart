import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ==========================================
// 🧠 1. MOTOR (CONTROLLER DA NUVEM)
// ==========================================
class MetaMensal {
  final double faturamentoMensal;
  final double faturamentoDiario;
  final int atendimentosMensal;
  final int atendimentosDiario;

  MetaMensal({
    required this.faturamentoMensal, required this.faturamentoDiario,
    required this.atendimentosMensal, required this.atendimentosDiario,
  });

  factory MetaMensal.fromMap(Map<String, dynamic>? map) {
    if (map == null) return MetaMensal(faturamentoMensal: 0, faturamentoDiario: 0, atendimentosMensal: 0, atendimentosDiario: 0);
    return MetaMensal(
      faturamentoMensal: (map['faturamentoMensal'] ?? 0).toDouble(),
      faturamentoDiario: (map['faturamentoDiario'] ?? 0).toDouble(),
      atendimentosMensal: map['atendimentosMensal'] ?? 0,
      atendimentosDiario: map['atendimentosDiario'] ?? 0,
    );
  }
  
  Map<String, dynamic> toMap() => {
    'faturamentoMensal': faturamentoMensal, 'faturamentoDiario': faturamentoDiario,
    'atendimentosMensal': atendimentosMensal, 'atendimentosDiario': atendimentosDiario,
  };
}

// Otimização Firebase: Lê 1 único documento com todos os meses dentro!
final metasControllerProvider = StreamProvider.autoDispose<Map<String, MetaMensal>>((ref) {
  return FirebaseFirestore.instance.collection('loja_configuracoes').doc('metas_negocio').snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) return {};
    final data = doc.data()!;
    final map = <String, MetaMensal>{};
    data.forEach((key, value) { map[key] = MetaMensal.fromMap(value as Map<String, dynamic>); });
    return map;
  });
});

// ==========================================
// 🎨 2. A TELA DE PLANEJAMENTO
// ==========================================
class MetasPlanejamentoScreen extends ConsumerStatefulWidget {
  const MetasPlanejamentoScreen({super.key});

  @override
  ConsumerState<MetasPlanejamentoScreen> createState() => _MetasPlanejamentoScreenState();
}

class _MetasPlanejamentoScreenState extends ConsumerState<MetasPlanejamentoScreen> {
  DateTime _mesSelecionado = DateTime.now();
  bool _usarCalculadoraIA = true;
  int _diasPorSemana = 5; 
  bool _carregado = false;

  final _fatMensalCtrl = TextEditingController();
  final _fatDiarioCtrl = TextEditingController();
  final _atendMensalCtrl = TextEditingController();
  final _atendDiarioCtrl = TextEditingController();

  String get _chaveMes => '${_mesSelecionado.year}-${_mesSelecionado.month.toString().padLeft(2, '0')}';

  void _carregarDadosDoBanco(Map<String, MetaMensal> todasAsMetas) {
    if (_carregado) return;
    final metaDoMes = todasAsMetas[_chaveMes];
    if (metaDoMes != null) {
      _fatMensalCtrl.text = metaDoMes.faturamentoMensal > 0 ? metaDoMes.faturamentoMensal.toStringAsFixed(2).replaceAll('.', ',') : '';
      _fatDiarioCtrl.text = metaDoMes.faturamentoDiario > 0 ? metaDoMes.faturamentoDiario.toStringAsFixed(2).replaceAll('.', ',') : '';
      _atendMensalCtrl.text = metaDoMes.atendimentosMensal > 0 ? metaDoMes.atendimentosMensal.toString() : '';
      _atendDiarioCtrl.text = metaDoMes.atendimentosDiario > 0 ? metaDoMes.atendimentosDiario.toString() : '';
    } else {
      _fatMensalCtrl.clear(); _fatDiarioCtrl.clear(); _atendMensalCtrl.clear(); _atendDiarioCtrl.clear();
    }
  }

  void _calcularIA() {
    if (!_usarCalculadoraIA) return;
    final fatMensal = double.tryParse(_fatMensalCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final atendMensal = int.tryParse(_atendMensalCtrl.text) ?? 0;

    int diasTrabalhadosNoMes = 0;
    final diasNoMes = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0).day;
    
    for (int i = 1; i <= diasNoMes; i++) {
      final dia = DateTime(_mesSelecionado.year, _mesSelecionado.month, i);
      if (_diasPorSemana == 5 && (dia.weekday == 7 || dia.weekday == 1)) continue;
      if (_diasPorSemana == 6 && dia.weekday == 7) continue;
      diasTrabalhadosNoMes++;
    }

    if (diasTrabalhadosNoMes > 0) {
      if (fatMensal > 0) _fatDiarioCtrl.text = (fatMensal / diasTrabalhadosNoMes).toStringAsFixed(2).replaceAll('.', ',');
      if (atendMensal > 0) _atendDiarioCtrl.text = (atendMensal / diasTrabalhadosNoMes).ceil().toString();
    }
  }

  Future<void> _salvarNoBanco() async {
    final fatMensal = double.tryParse(_fatMensalCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final fatDiario = double.tryParse(_fatDiarioCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final atendMensal = int.tryParse(_atendMensalCtrl.text) ?? 0;
    final atendDiario = int.tryParse(_atendDiarioCtrl.text) ?? 0;

    final novaMeta = MetaMensal(
      faturamentoMensal: fatMensal, faturamentoDiario: fatDiario,
      atendimentosMensal: atendMensal, atendimentosDiario: atendDiario,
    );

    await FirebaseFirestore.instance.collection('loja_configuracoes').doc('metas_negocio').set({
      _chaveMes: novaMeta.toMap()
    }, SetOptions(merge: true));

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Metas salvas com sucesso!'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF8A2463);
    final metasAsync = ref.watch(metasControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0F4),
      appBar: AppBar(
        title: const Text('Planejamento de Metas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      ),
      body: metasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (todasAsMetas) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_carregado) { _carregarDadosDoBanco(todasAsMetas); setState(() => _carregado = true); }
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left, color: primary), onPressed: () { setState(() { _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1); _carregado = false; }); }),
                      Text(DateFormat('MMMM yyyy', 'pt_BR').format(_mesSelecionado).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primary)),
                      IconButton(icon: const Icon(Icons.chevron_right, color: primary), onPressed: () { setState(() { _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1); _carregado = false; }); }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text('O que você quer alcançar neste mês?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _fatMensalCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _calcularIA(), decoration: const InputDecoration(labelText: 'Faturamento Mensal', prefixText: 'R\$ ', border: OutlineInputBorder(), filled: true, fillColor: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _atendMensalCtrl, keyboardType: TextInputType.number, onChanged: (_) => _calcularIA(), decoration: const InputDecoration(labelText: 'Clientes no Mês', prefixIcon: Icon(Icons.people_outline), border: OutlineInputBorder(), filled: true, fillColor: Colors.white))),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _usarCalculadoraIA ? Colors.blue.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: _usarCalculadoraIA ? Colors.blue.shade200 : Colors.grey.shade300)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero, title: const Text('Calculadora Reversa (IA)', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('A Inteligência divide a sua meta mensal automaticamente nos dias trabalhados.', style: TextStyle(fontSize: 12)),
                        value: _usarCalculadoraIA, activeColor: Colors.blue.shade700,
                        onChanged: (val) { setState(() { _usarCalculadoraIA = val; if (val) _calcularIA(); }); },
                      ),
                      if (_usarCalculadoraIA) ...[
                        const Divider(),
                        const Text('Quantos dias na semana o salão abre?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Slider(
                          value: _diasPorSemana.toDouble(), min: 4, max: 7, divisions: 3, label: '$_diasPorSemana dias', activeColor: Colors.blue.shade700,
                          onChanged: (val) { setState(() { _diasPorSemana = val.toInt(); _calcularIA(); }); },
                        ),
                        Text('Considerando $_diasPorSemana dias por semana (removendo feriados/domingos), o sistema fracionou sua meta nos campos abaixo.', style: TextStyle(fontSize: 11, color: Colors.blue.shade800)),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(_usarCalculadoraIA ? 'Metas Diárias Geradas pela IA:' : 'Ajuste de Metas Diárias (Manual):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _fatDiarioCtrl, enabled: !_usarCalculadoraIA, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Faturamento Diário', prefixText: 'R\$ ', border: const OutlineInputBorder(), filled: true, fillColor: _usarCalculadoraIA ? Colors.grey.shade200 : Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _atendDiarioCtrl, enabled: !_usarCalculadoraIA, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Clientes por Dia', prefixIcon: const Icon(Icons.person), border: const OutlineInputBorder(), filled: true, fillColor: _usarCalculadoraIA ? Colors.grey.shade200 : Colors.white))),
                  ],
                ),
                const SizedBox(height: 32),

                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _salvarNoBanco, icon: const Icon(Icons.save), label: const Text('SALVAR PLANEJAMENTO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
