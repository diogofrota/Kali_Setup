# Instalação

O projeto é modular. Não execute tudo em lote sem revisar cada etapa.

Listar módulos:

```bash
./install.sh --list
```

Validar sintaxe:

```bash
./install.sh --validate
```

Simular chamada de um módulo:

```bash
./install.sh --dry-run --module 15
```

Executar um módulo específico:

```bash
./install.sh --module 05
```

Módulos que alteram pacotes, serviços, usuários ou grupos pedem confirmação explícita. O projeto evita `kali-linux-everything` e prefere instalação controlada.
