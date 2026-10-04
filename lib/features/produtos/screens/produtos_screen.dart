import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../clientes/controllers/cliente_controller.dart';
import '../controllers/produto_controller.dart';
import '../controllers/venda_controller.dart';
import '../models/produto.dart';
import '../models/venda_produto.dart';

class ProdutosScreen extends ConsumerStatefulWidget {
  const ProdutosScreen({super.key});

  @override
  ConsumerState<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends ConsumerVestindo novamente o meu chapéu de **Tech Lead e UI/UX Designer**! Peço desculpas pelo bloqueio anterior; o sistema de segurança da IA às vezes é um pouco rigoroso com blocos de código muito grandes. 

Mas a sua ideia de colocar um **Filtro de Mês** no histórico de vendas é perfeita! Sem isso, você ficaria presa apenas ao mês atual e não conseguiria ver as vendas passadas.

Para resolver isso sem precisar instalar pacotes extras no seu aplicativo, nós vamos usar o calendário nativo do Flutter. O usuário clica no botão, escolhe qualquer dia do mês que deseja consultar, e o nosso `venda_controller` recalcula o DRE e a lista de vendas instantaneamente.

Copie o código abaixo e **substitua TODO O CONTEÚDO** do arquivo **`lib/features/produtos/screens/produtos_screen.dart`**:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../clientes/controllers/cliente_controller.dart'; 
import '../controllers/produto_controller.dart';
import '../controllers/venda_controller.dart';
import '../models/produto.dart';
import '../models/venda_produto.dart';

class ProdutosScreen extends ConsumerStatefulWidget {
  const ProdutosScreen({super.key});
