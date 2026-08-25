import 'package:flutter/material.dart';

class AnaliseIaScreen extends StatefulWidget {
  final String? contextoMetricas;

  const AnaliseIaScreen({super.key, this.contextoMetricas});

  @override
  State<AnaliseIaScreen> createState() => _AnaliseIaScreenState();
}

class _AnaliseIaScreenState extends State<AnaliseIaScreen> {
  bool _gerandoRelatorio = true;
  String _relatorioIA = "";

  @override
  void initState() {
    super.initState();
    _gerarRelatorio();
  }

  Future<void> _gerarRelatorio() async {
    // Simulando o tempo em que a IA está "lendo e pensando"
    await Future.delayed(const Duration(seconds: 3));

    // TODO: Aqui você fará a requisição para a sua API da OpenAI ou Google Gemini.
    // Exemplo: final resposta = await gemini.chat(widget.contextoMetricas);
    
    // Texto simulado para você ver como ficará bonito no aplicativo até colocar a API:
    final textoSimulado = '''
**Análise de Desempenho do Studio**

**1. Comparativo Semanal**
Notamos uma variação no seu Ticket Médio (TM). Na semana passada seu TM foi saudável, e a missão desta semana é manter a recorrência. Focar em oferecer serviços extras de baixo custo de tempo (como Spa dos Pés) pode ajudar a alavancar a semana atual.

**2. Análise do Mês**
Seu faturamento mensal está construindo uma base sólida. Os agendamentos estão fluindo bem, mas há oportunidades em dias historicamente ociosos (terças e quartas). 

**3. Sugestões Estratégicas:**
* **Combo Express:** Crie combos de "Mão + Hidratação" para elevar o TM instantaneamente.
* **Resgate de Inativas:** Envie uma mensagem de "saudades" pelo WhatsApp para clientes que não vêm há mais de 20 dias.
* **Preenchimento de Agenda:** Ofereça 10% de desconto em procedimentos rápidos para quem agendar nas terças-feiras.
''';

    if (mounted) {
      setState(() {
        _relatorioIA = textoSimulado;
        _gerandoRelatorio = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório da Consultoria IA'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _gerandoRelatorio
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.deepPurple),
                  const SizedBox(height: 24),
                  Text(
                    'A IA está analisando seu faturamento\ne comparando os resultados da semana...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                // Exibe o relatório gerado. No futuro, você pode usar um pacote de Markdown 
                // para formatar os negritos e listas automaticamente.
                child: Text(
                  _relatorioIA,
                  style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                ),
              ),
            ),
    );
  }
}
