# Expressões usadas nos fluxos

## Fluxo 2 · condição do gatilho
Só processa pedidos já decididos e ainda não processados (evita loop, já que o próprio fluxo atualiza o item):

```
@and(
  not(equals(triggerOutputs()?['body/StatusAprovacao'], 'Pendente')),
  not(equals(triggerOutputs()?['body/Processando'], true))
)
```

## Data proposta (dd/mm/aaaa → aaaa-mm-dd)
```
concat(
  substring(triggerOutputs()?['body/ValorProposto'], 6, 4), '-',
  substring(triggerOutputs()?['body/ValorProposto'], 3, 2), '-',
  substring(triggerOutputs()?['body/ValorProposto'], 0, 2)
)
```

## Case "Status": aplica o valor proposto e só data a conclusão quando concluído
```
Status:    triggerOutputs()?['body/ValorProposto']
Conclusao: if(equals(triggerOutputs()?['body/ValorProposto'], 'Concluído'),
              convertTimeZone(utcNow(), 'UTC', 'E. South America Standard Time', 'yyyy-MM-dd'),
              null)
```

## Autor no histórico
```
concat(
  coalesce(triggerOutputs()?['body/SolicitanteNome'], triggerOutputs()?['body/SolicitanteEmail']),
  ' (aprovado por ', triggerOutputs()?['body/ResponsavelEmail'], ')'
)
```

## Fluxo 1 · proteção contra decisão duplicada
Depois de "Postar cartão adaptável e aguardar resposta", o fluxo relê a solicitação.
Se `StatusAprovacao` já não for `Pendente` (decidida pelo app enquanto o card esperava), encerra com **Terminate · Succeeded** sem alterar nada.
