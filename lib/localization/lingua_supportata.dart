class LinguaSupportata {
  final String nome;
  final String flag;

  LinguaSupportata({required this.nome, required this.flag});

  factory LinguaSupportata.fromJson(Map<String, dynamic> json) {
    return LinguaSupportata(
      nome: json['nome'],
      flag: json['flag'],
    );
  }
} 