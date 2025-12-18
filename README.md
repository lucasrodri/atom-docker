# AtoM em Docker

Stack dockerizada do Access to Memory (AtoM) pronta para desenvolvimento e provas de conceito. O conteudo de `./src` e montado dentro do container, permitindo editar o codigo no host enquanto os servicos de infraestrutura permanecem isolados.

## Visao geral
- `docker-compose.yml` orquestra MySQL 8, Elasticsearch 7.17, Gearman, o servidor web AtoM (`atom`) e um worker separado para filas (`atom-worker`).
- O container principal roda Nginx + PHP 8.3 via Supervisord e executa `symfony tools:install` automaticamente na primeira subida quando `AUTO_INSTALL=1`.
- Volumes nomeados preservam banco, indice de busca, cache e uploads entre recriacoes de containers.

## Requisitos
- Docker 24+ e Docker Compose Plugin v2.
- Pelo menos 6 GB de RAM disponivel (Elasticsearch exige ~2 GB dedicados) e 2 CPUs.
- Porta 8080 livre no host.

## Estrutura do repositorio
- `docker-compose.yml`: definicoes dos servicos, healthchecks e volumes persistentes.
- `Dockerfile`: imagem baseada em Ubuntu 24.04 com PHP 8.3, Nginx e Supervisord.
- `docker/entrypoint.sh`: aguarda dependencias, dispara instalacao inicial e aplica permissoes.
- `docker/nginx-atom.conf`: virtual host que entrega PHP via `php-fpm` e arquivos estaticos com cache.
- `docker/supervisord.conf`: inicia Nginx e PHP-FPM no mesmo container.
- `src/`: copia do codigo AtoM (bind mount). Nenhum artefato e copiado para a imagem durante o build.

## Servicos
| Servico       | Porta host | Descricao |
|---------------|------------|-----------|
| `mysql`       | n/a        | MySQL 8.0 com autenticacao `mysql_native_password`. Volume `mysql_data`. |
| `elasticsearch` | 9200     | Cluster single-node usado pelas pesquisas do AtoM. Volume `es_data`. |
| `gearman`     | 4730       | Broker de filas para tarefas assinc. |
| `atom`        | 8080->80   | Nginx + PHP-FPM servindo a aplicacao web. Monta `./src` e volumes `atom_cache`/`atom_uploads`. |
| `atom-worker` | n/a        | Roda `symfony jobs:worker` continuamente. Compartilha os mesmos volumes de codigo/cache/uploads. |

## Primeiros passos
1. Copie as variaveis padrao: `cp .env.example .env` e ajuste conforme necessario (URLs, credenciais externas etc.). Atente-se para que as credenciais do banco sejam as mesmas utilizadas no AtoM (ex.: `MYSQL_USER=atom` e `ATOM_DB_USER=atom`).
2. Construa a imagem local (necessario apenas na primeira vez ou quando o Dockerfile mudar): `docker compose build atom atom-worker`.
3. Suba toda a stack: `docker compose up -d`. Se preferir fazer build + subida em um unico passo, basta rodar `docker compose up -d --build`.
4. Acompanhe os logs iniciais: `docker compose logs -f atom` ate ver `Instalacao concluida.` (primeira subida) ou `DB ja inicializado`.
5. Acesse `http://localhost:8080`. O URL publico tambem e controlado pela variavel `ATOM_URL`.

> Observacao: a instalacao automatica ocorre somente quando o schema `atom` nao contem tabelas. Se desejar reexecutar, apague o volume `mysql_data` ou rode manualmente `docker compose exec atom php symfony tools:install` apos limpar o banco.

## Primeiros passos apos a instalacao
1. Na interface web do AtoM logue como administrador (default: usuario `lucasrodrigues@ibict.br` e senha `lucas`) e siga os passos:
2. Altere o idioma padrao para portugues clicando no icone de planeta no canto superior direito e selecionando `Português`.

## Fluxo de desenvolvimento
- **Codigo vivo**: edite qualquer arquivo em `src/` e suas mudancas aparecem imediatamente dentro dos containers.
- **CLI do Symfony**: use `docker compose exec atom php symfony <comando>` (ex.: `search:populate`, `cache:clear`).
- **Tarefas assinc**: o container `atom-worker` e dependente do `atom` e reusa as variaveis do `.env`. Se precisar rodar um job isolado, utilize `docker compose run --rm atom php symfony jobs:worker --trace`.
- **Assets front-end**: existem scripts em `src/package.json`. Execute `docker compose exec atom npm install` e `npm run dev`/`build` conforme o fluxo do projeto.

## Persistencia de dados
- `mysql_data`: armazena o banco AtoM.
- `es_data`: indice do Elasticsearch.
- `atom_cache`: cache Symfony e artefatos temporarios.
- `atom_uploads`: anexos enviados pelos usuarios.

Para backup local rapido: `docker run --rm -v mysql_data:/volume -v $(pwd):/backup alpine tar czf /backup/mysql_data.tar.gz -C /volume .` (repita para outros volumes). Sempre desligue os containers antes de copiar arquivos de dados.

## Variaveis de ambiente relevantes
- `ATOM_DB_*`: host, nome, usuario e senha do MySQL (default: `mysql`, `atom`, `root`, `rootpass`).
- `ATOM_ES_HOST`: host do Elasticsearch (default `elasticsearch`).
- `ATOM_GEARMAN_HOST`: host do Gearman (default `gearman`).
- `ATOM_URL`: URL externa usada pelo AtoM para gerar links absolutos.
- `AUTO_INSTALL`: definido em `docker-compose.yml` para `atom`. Quando `1`, dispara `symfony tools:install` se nao houver tabelas no banco.

Qualquer variavel do `.env` fica disponivel tanto no container `atom` quanto no `atom-worker`.

## Operacao e manutencao
- Ver logs em tempo real: `docker compose logs -f atom` (ou `mysql`, `elasticsearch`, `atom-worker`).
- Atualizar codigo: execute `git pull` no host e reinicie `docker compose up -d atom atom-worker`.
- Recriar somente os containers de aplicacao apos alterar dependencias PHP/JS: `docker compose up -d --build atom atom-worker`.
- Parar todo o ambiente: `docker compose down` (usa `-v` apenas se quiser descartar dados).
- Limpar caches manualmente: `docker compose exec atom php symfony cc`.

## Scripts auxiliares (`scripts/`)
- `reset.sh`: reset parcial. Para os containers, remove os volumes `mysql_data`, `es_data` e `atom_cache` (mantem `atom_uploads`) e sobe tudo novamente com `docker compose up -d --build`. Utilize quando quiser reinstalar banco e indices sem perder uploads.
- `reset-atom.sh`: reset total. Solicita confirmacao digitando `sim`, derruba os containers, remove todos os volumes (incluindo uploads) e religa o ambiente. Ideal para voltar ao estado zero; apos o procedimento o `symfony tools:install` roda automaticamente.
- Ambos os scripts devem possuir permissao de execucao (`chmod +x scripts/*.sh`) e podem ser executados a partir da raiz do projeto.

## Solucao de problemas
- **MySQL nunca fica healthy**: valide se outra instancia esta usando a porta 3306 no host; verifique `docker compose logs mysql` para mensagens de permissao no volume `mysql_data`.
- **Elasticsearch reinicia por falta de memoria**: reduza o uso local ou edite `ES_JAVA_OPTS` em `docker-compose.yml` (ex.: `-Xms512m -Xmx512m`).
- **Worker parado**: confirme que `atom-worker` esta `Up` com `docker compose ps`. Se necessario, reinicie apenas ele com `docker compose restart atom-worker`.
- **Permissoes quebradas em uploads**: rode `docker compose exec atom chown -R www-data:www-data /var/www/atom/uploads`.

# Atenção

Pode acontecer alguns erros na instalação automática dependendo do ambiente. Recomenda-se que na primeira instalação a pasta src seja copiada diretamente do repositório oficial do AtoM em: https://storage.accesstomemory.org/releases/atom-latest.tar.gz e descompactada na pasta src deste repositório.

## Referencias
- Documentacao oficial do AtoM: https://www.accesstomemory.org/en/docs/2.8/
- Guia do docker compose: https://docs.docker.com/compose/

## Autor
- Lucas Rodrigues Costa - [lucasrodrigues@ibict.br](mailto:lucasrodrigues@ibict.br)
