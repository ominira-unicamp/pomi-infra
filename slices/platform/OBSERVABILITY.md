# Observabilidade do POMI

## Dimensões obrigatórias

Logs, métricas e traces devem usar as mesmas dimensões:

- `service.name`: nome da aplicação ou `pomi-host`;
- `service.version`: SHA ou identificador do deploy;
- `deployment.environment.name`: `production`, `staging` ou `development`;
- `cloud.provider`: `aws`;
- `cloud.region`: `sa-east-1`.

Os ambientes ficam na mesma organização e nos mesmos streams por sinal. O
ambiente é filtrado por atributo, evitando um stream para cada ambiente.

## Alertas recomendados no OpenObserve

Configure alertas para:

1. ausência do indicador de disponibilidade por cinco minutos;
2. aumento de respostas HTTP 5xx;
3. `pomi_sync_errors_total` maior que zero em uma janela de 15 minutos;
4. ausência de uma execução de sync em oito horas;
5. `pomi_notifications_failed_total` maior que zero;
6. filesystem acima de 80%;
7. memória acima de 80%;
8. ausência de métricas `service.name = pomi-host` por cinco minutos.

As regras de alerta dependem da API/plano da organização OpenObserve e devem
ser criadas no painel ou via API dessa organização. Valide a disponibilidade
de cada sinal no ambiente antes de ativar a regra.
