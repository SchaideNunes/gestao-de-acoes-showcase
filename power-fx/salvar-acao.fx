// =========================================================================
// 0. VALIDAÇÃO DE REGRAS DE NEGÓCIO, PRAZOS E EVIDÊNCIAS (iguais às de antes)
// =========================================================================
UpdateContext({
    varFormValido:
        // Regra 1: Prazo não pode ser anterior à Data da Demanda
        (IsBlank(dtPrazo.SelectedDate) || IsBlank(dtDataDemanda.SelectedDate) || dtPrazo.SelectedDate >= dtDataDemanda.SelectedDate) &&
        // Regra 2: Alteração de Prazo (reprogramação) exige justificativa em Observações
        !( !IsBlank(itemEdicao) && (dtPrazo.SelectedDate <> itemEdicao.Prazo) && IsBlank(Trim(txtObservacao.Text)) ) &&
        // Regra 3: Se Requer Evidência e o Status é Concluído, exige pelo menos um anexo
        !( cmbStatus.Selected.Value = "Concluído" && tglRequerEvidencia.Checked && (CountRows(attAnexos.Attachments) = 0) )
});

If(
    !IsBlank(dtPrazo.SelectedDate) && !IsBlank(dtDataDemanda.SelectedDate) && (dtPrazo.SelectedDate < dtDataDemanda.SelectedDate),
    Notify(
        "Atenção: O Prazo da ação não pode ser anterior à Data da Demanda.",
        NotificationType.Error
    ),

    !IsBlank(itemEdicao) && (dtPrazo.SelectedDate <> itemEdicao.Prazo) && IsBlank(Trim(txtObservacao.Text)),
    Notify(
        "Como houve alteração de prazo (reprogramação), é obrigatório preencher o campo de Observações justificando o motivo.",
        NotificationType.Error
    ),

    cmbStatus.Selected.Value = "Concluído" && tglRequerEvidencia.Checked && (CountRows(attAnexos.Attachments) = 0),
    Notify(
        "Esta ação requer evidência obrigatória. Adicione pelo menos um anexo para concluir a ação.",
        NotificationType.Error
    )
);

// =========================================================================
// EXECUÇÃO DO SALVAMENTO (SÓ EXECUTA SE PASSAR NAS VALIDAÇÕES)
// =========================================================================
If(
    varFormValido,

    // Trava o botão (evita duplo clique) e assume sucesso até provar o contrário
    UpdateContext({varSalvando: true, varSalvouOk: true});

    // 1. MAPEIA RESPONSÁVEL E QUAIS CAMPOS CRÍTICOS SOFRERAM ALTERAÇÃO
    UpdateContext({
        varEhCriador: IsBlank(itemEdicao) || IsBlank(itemEdicao.CriadoPor.Email) || (Lower(User().Email) = Lower(itemEdicao.CriadoPor.Email)),
        varMudouStatusConcluido: !IsBlank(itemEdicao) && (cmbStatus.Selected.Value = "Concluído") && (itemEdicao.Status.Value <> "Concluído"),
        varMudouGerencia: !IsBlank(itemEdicao) && (itemEdicao.Gerencia.Value <> cmbGerencia.Selected.Value),
        varMudouDataDemanda: !IsBlank(itemEdicao) && (itemEdicao.DataDemanda <> dtDataDemanda.SelectedDate),
        varMudouAcao: !IsBlank(itemEdicao) && (Trim(itemEdicao.Acao) <> Trim(txtAcao.Text)),
        varMudouPrazo: !IsBlank(itemEdicao) && (itemEdicao.Prazo <> dtPrazo.SelectedDate),
        varMudouReprog: !IsBlank(itemEdicao) && (itemEdicao.Reprogramacao <> dtReprogramaçao.SelectedDate)
    });

    UpdateContext({
        varRequerAprovacao: !varEhCriador && (
            varMudouStatusConcluido ||
            varMudouGerencia ||
            varMudouDataDemanda ||
            varMudouAcao ||
            varMudouPrazo ||
            varMudouReprog
        )
    });

    If(
        varRequerAprovacao,

        // =================================================================
        // 2. CENÁRIO A: NÃO-CRIADOR TENTOU ALTERAR CAMPO CRÍTICO
        // =================================================================

        // A.1 Primeiro salva os campos liberados + anexos (e confere se deu certo)
        IfError(
            Patch(
                Acoes,
                LookUp(Acoes, ID = itemEdicao.ID),
                {
                    Observacoes: txtObservacao.Text,
                    DetalhamentoOrigem: txtDetalhamento.Text,
                    Status: If(varMudouStatusConcluido, itemEdicao.Status, {Value: cmbStatus.Selected.Value})
                },
                frmAnexos.Updates
            ),
            UpdateContext({varSalvouOk: false});
            Notify(
                "Não foi possível salvar: " & FirstError.Message & " Seus dados continuam na tela, tente novamente.",
                NotificationType.Error
            )
        );

        // A.2 Só cria as solicitações se o salvamento acima funcionou (tudo em uma chamada)
        If(
            varSalvouOk,
            With(
                {
                    _solicitacoes: DropColumns(
                        Filter(
                            Table(
                                {
                                    Incluir: varMudouStatusConcluido,
                                    Title: "Ação #" & itemEdicao.ID & " - Conclusão de Ação",
                                    AcaoID: itemEdicao.ID,
                                    CampoModificado: "Status",
                                    ValorAtual: Coalesce(itemEdicao.Status.Value, "-"),
                                    ValorProposto: "Concluído",
                                    SolicitanteNome: User().FullName,
                                    SolicitanteEmail: Lower(User().Email),
                                    ResponsavelEmail: Lower(itemEdicao.CriadoPor.Email),
                                    StatusAprovacao: "Pendente"
                                },
                                {
                                    Incluir: varMudouGerencia,
                                    Title: "Ação #" & itemEdicao.ID & " - Alteração de Gerência",
                                    AcaoID: itemEdicao.ID,
                                    CampoModificado: "Gerência",
                                    ValorAtual: Coalesce(itemEdicao.Gerencia.Value, "-"),
                                    ValorProposto: cmbGerencia.Selected.Value,
                                    SolicitanteNome: User().FullName,
                                    SolicitanteEmail: Lower(User().Email),
                                    ResponsavelEmail: Lower(itemEdicao.CriadoPor.Email),
                                    StatusAprovacao: "Pendente"
                                },
                                {
                                    Incluir: varMudouDataDemanda,
                                    Title: "Ação #" & itemEdicao.ID & " - Data da Demanda",
                                    AcaoID: itemEdicao.ID,
                                    CampoModificado: "DataDemanda",
                                    ValorAtual: If(!IsBlank(itemEdicao.DataDemanda), Text(itemEdicao.DataDemanda, "dd/mm/yyyy"), "-"),
                                    ValorProposto: If(!IsBlank(dtDataDemanda.SelectedDate), Text(dtDataDemanda.SelectedDate, "dd/mm/yyyy"), "-"),
                                    SolicitanteNome: User().FullName,
                                    SolicitanteEmail: Lower(User().Email),
                                    ResponsavelEmail: Lower(itemEdicao.CriadoPor.Email),
                                    StatusAprovacao: "Pendente"
                                },
                                {
                                    Incluir: varMudouAcao,
                                    Title: "Ação #" & itemEdicao.ID & " - Descrição da Ação",
                                    AcaoID: itemEdicao.ID,
                                    CampoModificado: "Ação",
                                    ValorAtual: Coalesce(itemEdicao.Acao, "-"),
                                    ValorProposto: txtAcao.Text,
                                    SolicitanteNome: User().FullName,
                                    SolicitanteEmail: Lower(User().Email),
                                    ResponsavelEmail: Lower(itemEdicao.CriadoPor.Email),
                                    StatusAprovacao: "Pendente"
                                },
                                {
                                    Incluir: varMudouPrazo,
                                    Title: "Ação #" & itemEdicao.ID & " - Alteração de Prazo",
                                    AcaoID: itemEdicao.ID,
                                    CampoModificado: "Prazo",
                                    ValorAtual: If(!IsBlank(itemEdicao.Prazo), Text(itemEdicao.Prazo, "dd/mm/yyyy"), "-"),
                                    ValorProposto: If(!IsBlank(dtPrazo.SelectedDate), Text(dtPrazo.SelectedDate, "dd/mm/yyyy"), "-"),
                                    SolicitanteNome: User().FullName,
                                    SolicitanteEmail: Lower(User().Email),
                                    ResponsavelEmail: Lower(itemEdicao.CriadoPor.Email),
                                    StatusAprovacao: "Pendente"
                                },
                                {
                                    Incluir: varMudouReprog,
                                    Title: "Ação #" & itemEdicao.ID & " - Reprogramação",
                                    AcaoID: itemEdicao.ID,
                                    CampoModificado: "Reprogramação",
                                    ValorAtual: If(!IsBlank(itemEdicao.Reprogramacao), Text(itemEdicao.Reprogramacao, "dd/mm/yyyy"), "-"),
                                    ValorProposto: If(!IsBlank(dtReprogramaçao.SelectedDate), Text(dtReprogramaçao.SelectedDate, "dd/mm/yyyy"), "-"),
                                    SolicitanteNome: User().FullName,
                                    SolicitanteEmail: Lower(User().Email),
                                    ResponsavelEmail: Lower(itemEdicao.CriadoPor.Email),
                                    StatusAprovacao: "Pendente"
                                }
                            ),
                            Incluir
                        ),
                        Incluir
                    )
                },
                Collect(SolicitacoesAprovacao, _solicitacoes);
                If(
                    IsEmpty(Errors(SolicitacoesAprovacao)),
                    Notify(
                        "Pedido enviado para aprovação de " & Coalesce(itemEdicao.CriadoPor.DisplayName, "criador da ação") & ": " &
                        Concat(
                            Filter(
                                Table(
                                    {n: "Status (Concluído)", i: varMudouStatusConcluido},
                                    {n: "Gerência", i: varMudouGerencia},
                                    {n: "Data da Demanda", i: varMudouDataDemanda},
                                    {n: "Ação", i: varMudouAcao},
                                    {n: "Prazo", i: varMudouPrazo},
                                    {n: "Reprogramação", i: varMudouReprog}
                                ),
                                i
                            ),
                            n,
                            ", "
                        ) & ". Esses campos só mudam depois da aprovação; as demais alterações já foram salvas.",
                        NotificationType.Success,
                        6000
                    ),
                    // Se as solicitações falharem, avisa (os campos liberados já foram salvos)
                    Notify(
                        "As alterações foram salvas, mas as solicitações de aprovação não foram enviadas: " & First(Errors(SolicitacoesAprovacao)).Message,
                        NotificationType.Warning
                    )
                )
            )
        ),

        // =================================================================
        // 3. CENÁRIO B: RESPONSÁVEL EDITANDO, NOVO CADASTRO OU MUDANÇA LIVRE
        // =================================================================

        // B.1 Patch oficial na lista Acoes + Anexos (e confere se deu certo)
        IfError(
            Patch(
                Acoes,
                If(
                    IsBlank(itemEdicao),
                    Defaults(Acoes),
                    LookUp(Acoes, ID = itemEdicao.ID)
                ),
                {
                    Gerencia: {Value: cmbGerencia.Selected.Value},
                    RequerEvidencia: tglRequerEvidencia.Checked,
                    Origem: {Value: cmbOrigem.Selected.Value},
                    DetalhamentoOrigem: txtDetalhamento.Text,
                    DataDemanda: dtDataDemanda.SelectedDate,
                    Acao: txtAcao.Text,
                    Solicitante: Coalesce(cmbSolicitante.Selected.Nome.DisplayName, cmbSolicitante.Selected.Title),
                    Responsavel: ForAll(
                        cmbResponsavel.SelectedItems As _item,
                        {
                            Claims: "i:0#.f|membership|" & Lower(_item.Email),
                            Department: "",
                            DisplayName: Coalesce(_item.Nome.DisplayName, _item.Title),
                            Email: Lower(_item.Email),
                            JobTitle: "",
                            Picture: ""
                        }
                    ),
                    Prioridade: {Value: cmbPrioridade.Selected.Value},
                    PrioridadeOrdem: Switch(cmbPrioridade.Selected.Value, "Urgente", 1, "Alta", 2, "Média", 3, 4),
                    Status: {Value: cmbStatus.Selected.Value},
                    Prazo: dtPrazo.SelectedDate,
                    Reprogramacao: dtReprogramaçao.SelectedDate,
                    Conclusao: If(
                        cmbStatus.Selected.Value = "Concluído",
                        If(IsBlank(dtConclusao.SelectedDate), Today(), dtConclusao.SelectedDate),
                        Blank()
                    ),
                    Observacoes: txtObservacao.Text,
                    Visibilidade: {Value: cmbVisibilidade.Selected.Value},
                    CriadoPor: If(
                        IsBlank(itemEdicao),
                        {
                            Claims: "i:0#.f|membership|" & Lower(User().Email),
                            Department: "",
                            DisplayName: User().FullName,
                            Email: Lower(User().Email),
                            JobTitle: "",
                            Picture: ""
                        },
                        itemEdicao.CriadoPor
                    )
                },
                frmAnexos.Updates
            ),
            UpdateContext({varSalvouOk: false});
            Notify(
                "Não foi possível salvar: " & FirstError.Message & " Seus dados continuam na tela, tente novamente.",
                NotificationType.Error
            )
        );

        // B.2 Histórico: só grava se o Patch acima funcionou (tudo em uma chamada)
        If(
            varSalvouOk && !IsBlank(itemEdicao),
            With(
                {
                    _historico: DropColumns(
                        Filter(
                            Table(
                                {
                                    Incluir: itemEdicao.Status.Value <> cmbStatus.Selected.Value,
                                    Title: "Ação #" & itemEdicao.ID,
                                    AcaoID: itemEdicao.ID,
                                    acaoID: itemEdicao.ID,
                                    CampoAlterado: "Status",
                                    ValorAnterior: Coalesce(itemEdicao.Status.Value, "-"),
                                    ValorNovo: Coalesce(cmbStatus.Selected.Value, "-"),
                                    AlteradoPor: User().FullName,
                                    DataHora: Now()
                                },
                                {
                                    Incluir: itemEdicao.Gerencia.Value <> cmbGerencia.Selected.Value,
                                    Title: "Ação #" & itemEdicao.ID,
                                    AcaoID: itemEdicao.ID,
                                    acaoID: itemEdicao.ID,
                                    CampoAlterado: "Gerência",
                                    ValorAnterior: Coalesce(itemEdicao.Gerencia.Value, "-"),
                                    ValorNovo: Coalesce(cmbGerencia.Selected.Value, "-"),
                                    AlteradoPor: User().FullName,
                                    DataHora: Now()
                                },
                                {
                                    Incluir: itemEdicao.DataDemanda <> dtDataDemanda.SelectedDate,
                                    Title: "Ação #" & itemEdicao.ID,
                                    AcaoID: itemEdicao.ID,
                                    acaoID: itemEdicao.ID,
                                    CampoAlterado: "Data Demanda",
                                    ValorAnterior: If(!IsBlank(itemEdicao.DataDemanda), Text(itemEdicao.DataDemanda, "dd/mm/yyyy"), "-"),
                                    ValorNovo: If(!IsBlank(dtDataDemanda.SelectedDate), Text(dtDataDemanda.SelectedDate, "dd/mm/yyyy"), "-"),
                                    AlteradoPor: User().FullName,
                                    DataHora: Now()
                                },
                                {
                                    Incluir: Trim(itemEdicao.Acao) <> Trim(txtAcao.Text),
                                    Title: "Ação #" & itemEdicao.ID,
                                    AcaoID: itemEdicao.ID,
                                    acaoID: itemEdicao.ID,
                                    CampoAlterado: "Ação",
                                    ValorAnterior: Coalesce(itemEdicao.Acao, "-"),
                                    ValorNovo: Coalesce(txtAcao.Text, "-"),
                                    AlteradoPor: User().FullName,
                                    DataHora: Now()
                                },
                                {
                                    Incluir: itemEdicao.Prazo <> dtPrazo.SelectedDate,
                                    Title: "Ação #" & itemEdicao.ID,
                                    AcaoID: itemEdicao.ID,
                                    acaoID: itemEdicao.ID,
                                    CampoAlterado: "Prazo",
                                    ValorAnterior: If(!IsBlank(itemEdicao.Prazo), Text(itemEdicao.Prazo, "dd/mm/yyyy"), "-"),
                                    ValorNovo: If(!IsBlank(dtPrazo.SelectedDate), Text(dtPrazo.SelectedDate, "dd/mm/yyyy"), "-"),
                                    AlteradoPor: User().FullName,
                                    DataHora: Now()
                                },
                                {
                                    Incluir: itemEdicao.Reprogramacao <> dtReprogramaçao.SelectedDate,
                                    Title: "Ação #" & itemEdicao.ID,
                                    AcaoID: itemEdicao.ID,
                                    acaoID: itemEdicao.ID,
                                    CampoAlterado: "Reprogramação",
                                    ValorAnterior: If(!IsBlank(itemEdicao.Reprogramacao), Text(itemEdicao.Reprogramacao, "dd/mm/yyyy"), "-"),
                                    ValorNovo: If(!IsBlank(dtReprogramaçao.SelectedDate), Text(dtReprogramaçao.SelectedDate, "dd/mm/yyyy"), "-"),
                                    AlteradoPor: User().FullName,
                                    DataHora: Now()
                                },
                                {
                                    Incluir: Trim(itemEdicao.Observacoes) <> Trim(txtObservacao.Text),
                                    Title: "Ação #" & itemEdicao.ID,
                                    AcaoID: itemEdicao.ID,
                                    acaoID: itemEdicao.ID,
                                    CampoAlterado: "Observações",
                                    ValorAnterior: Coalesce(itemEdicao.Observacoes, "-"),
                                    ValorNovo: Coalesce(txtObservacao.Text, "-"),
                                    AlteradoPor: User().FullName,
                                    DataHora: Now()
                                }
                            ),
                            Incluir
                        ),
                        Incluir
                    )
                },
                If(
                    !IsEmpty(_historico),
                    Collect(HistoricoAcoes, _historico);
                    // A ação já foi salva; só avisa se o histórico falhar
                    If(
                        !IsEmpty(Errors(HistoricoAcoes)),
                        Notify(
                            "A ação foi salva, mas o histórico de alterações não foi registrado: " & First(Errors(HistoricoAcoes)).Message,
                            NotificationType.Warning
                        )
                    )
                )
            )
        );

        If(
            varSalvouOk,
            Notify(
                If(IsBlank(itemEdicao), "Ação criada com sucesso!", "Ação atualizada com sucesso!"),
                NotificationType.Success
            )
        )
    );

    // =========================================================================
    // 4. FINALIZAÇÃO: só reseta e navega se salvou de verdade
    // =========================================================================
    If(
        varSalvouOk,
        ResetForm(frmAnexos);
        UpdateContext({varSalvando: false, varConfirmarSalvar: false, itemEdicao: Blank()});
        Navigate(HomePage, ScreenTransition.Fade),

        // Deu erro: libera o botão e fecha a confirmação, mantendo os dados na tela
        UpdateContext({varSalvando: false, varConfirmarSalvar: false})
    )
)
