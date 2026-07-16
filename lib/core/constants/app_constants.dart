/// Constantes centrais do app: nomes de boxes do Hive e caminhos de rota.
/// Mantidas em um único lugar para evitar strings "mágicas" espalhadas pelo código.
class HiveBoxes {
  static const String clientes = 'box_clientes';
  static const String agendamentos = 'box_agendamentos';
  static const String servicos = 'box_servicos';
}

class AppRoutes {
  static const String dashboard = '/';
  static const String clientes = '/clientes';
  static const String clienteNovo = '/clientes/novo';
  static const String clienteEditar = '/clientes/editar';
  static const String clienteHistorico = '/clientes/historico';
  static const String servicos = '/servicos';
  static const String servicoNovo = '/servicos/novo';
  static const String servicoEditar = '/servicos/editar';
  static const String agenda = '/agenda';
  static const String agendaNovo = '/agenda/novo';
  static const String agendaInteligente = '/agenda-inteligente';
  static const String configuracoes = '/configuracoes';
}
