# Ansible

O Ansible reconcilia o host Lightsail sem recriá-lo. Ele é executado no computador do operador; somente o Docker e os arquivos operacionais residem no host remoto.

## Preparação

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
export LIGHTSAIL_HOST="$(tofu -chdir=../terraform output -raw lightsail_static_ip)" # state homolog inicializado
export ANSIBLE_PRIVATE_KEY_FILE=../.local/pomi-lightsail
```

## Reconciliação do host e Caddy

```bash
ansible-playbook playbooks/reconcile-host.yml --check --diff
ansible-playbook playbooks/reconcile-host.yml
```

As roles `pomi` e `host` descrevem o estado da plataforma: arquivos de ambiente,
autenticação temporária no ECR, adoção de contêineres legados e Compose. Nenhum
segredo deve ser gravado em inventário, `group_vars` ou Git.

## Deploy de produto

Os playbooks consultam o state OpenTofu, recuperam os segredos no Parameter
Store, criam e enviam as imagens necessárias com tag UTC ao ECR e somente então
aplicam o serviço remoto. A autenticação no ECR é temporária e o fluxo inclui a
remoção da credencial após a operação.

```bash
ansible-playbook playbooks/deploy-pomi.yml
```

O POMI também pode ser atualizado por componente:

```bash
ansible-playbook playbooks/deploy-migrate.yml
ansible-playbook playbooks/deploy-data.yml
ansible-playbook playbooks/deploy-app.yml
ansible-playbook playbooks/deploy-injection.yml
```

Os três deploys de serviço verificam migrations pendentes antes de alterar
ambiente ou containers. Se houver migration pendente, execute explicitamente
`deploy-migrate.yml` e depois repita o deploy do componente. Nenhum deploy de
serviço executa migrations automaticamente.

Para rollback, informe uma tag que já exista no ECR:

```bash
ansible-playbook playbooks/deploy-pomi.yml \
  -e pomi_use_existing_image=true \
  -e pomi_image_tag=20260804201043
```


## Parada segura do POMI

`stop-pomi.yml` gera o dump no host, busca-o ao controlador, valida a estrutura
com `pg_restore`, envia o arquivo ao S3 com SSE e somente então para API e
PostgreSQL. Por fim, Caddy passa a responder 503 para o hostname do POMI.

```bash
ansible-playbook playbooks/stop-pomi.yml
```

Use `-e pomi_force_stop=true` somente quando aceitar explicitamente parar sem
backup válido.

Os scripts `slices/pomi/scripts/deploy-local.sh` e `stop-local.sh` permanecem
como atalhos compatíveis para esses playbooks; não contêm mais build, SSH, SCP
ou manipulação remota de Docker.
