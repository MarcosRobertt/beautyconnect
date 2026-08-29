// --- CÁLCULO UNIFICADO E ISOLADO DE VALOR E DURAÇÃO ---

double get _valorTotal {
  // 1. Inicia com o valor do serviço principal (se houver)
  double total = _servicoPrincipal?.valor ?? 0.0;
  
  // 2. Soma exatamente 1x o valor de cada item presente na lista de adicionais
  for (final adicional in _servicosAdicionais) {
    total += adicional.valor;
  }
  return total;
}

int get _duracaoTotal {
  // 1. Inicia com a duração do serviço principal
  int duracao = _servicoPrincipal?.duracaoMin ?? 0;
  
  // 2. Soma a duração de cada adicional
  for (final adicional in _servicosAdicionais) {
    duracao += adicional.duracaoMin;
  }
  return duracao;
}

// --- MÉTODO DE ADIÇÃO DE SERVIÇO ADICIONAL ---

void _adicionarServicoAdicional(Servico servico) {
  setState(() {
    // Adiciona apenas UMA instância do serviço por clique
    _servicosAdicionais.add(servico);
  });
}

void _removerServicoAdicional(int index) {
  setState(() {
    // Remove especificamente o item pelo índice exato para não apagar múltiplos itens iguais
    _servicosAdicionais.removeAt(index);
  });
}
