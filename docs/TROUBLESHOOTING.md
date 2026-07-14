# Troubleshooting

## Um pacote não existe

O módulo deve avisar e continuar quando um pacote opcional não existir no `apt-cache`.

Verifique:

```bash
apt-cache show nome-do-pacote
apt search nome-do-pacote
```

## Go ou pipx ausente

Execute primeiro:

```bash
sudo ./modules/10-install-python.sh
sudo ./modules/11-install-go.sh
```

## ARM64

Em Apple Silicon via Parallels, confira:

```bash
uname -m
```

Ferramentas marcadas como compatibilidade desconhecida devem ser revisadas antes de instalar.

## Docker

No Kali, o pacote do mecanismo é `docker.io`. O pacote `docker` não é o mecanismo Docker esperado.
