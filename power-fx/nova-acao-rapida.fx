// =========================================================================
// NOVA RÁPIDA: salva a ação atual e mantém os campos "fixos" para a próxima
// (só funciona para ação nova; em edição o botão fica oculto)
// =========================================================================
With(
    {
        _faltantes: Filter(
            [
                If(IsBlank(cmbGerencia.Selected), "Gerência"),
                If(IsBlank(cmbOrigem.Selected), "Origem"),
                If(IsBlank(txtDetalhamento.Text), "Detalhamento da Origem"),
                If(IsBlank(dtDataDemanda.SelectedDate), "Data da Demanda"),
                If(IsBlank(cmbPrioridade.Selected), "Prioridade"),
                If(IsBlank(txtAcao.Text), "Ação"),
                If(IsBlank(cmbSolicitante.Selected), "Solicitante"),
                If(IsEmpty(cmbResponsavel.SelectedItems), "Responsável"),
                If(IsBlank(dtPrazo.SelectedDate), "Prazo"),
                If(IsBlank(cmbVisibilidade.Selected), "Visibilidade"),
                If(IsBlank(cmbStatus.Selected), "Status"),
                If(
                    !IsBlank(dtPrazo.SelectedDate) && dtPrazo.SelectedDate < Today() &&
                    cmbStatus.Selected.Value <> "Concluído" && IsBlank(dtReprogramaçao.SelectedDate),
                    "Reprogramação (item em atraso)"
                )
            ],
            !IsBlank(Value)
        )
    },
    If(
        CountRows(_faltantes) > 0,
        Notify("Preencha os seguintes campos obrigatórios: " & Concat(_faltantes, Value, ", "), NotificationType.Error),

        !IsBlank(dtPrazo.SelectedDate) && !IsBlank(dtDataDemanda.SelectedDate) && dtPrazo.SelectedDate < dtDataDemanda.SelectedDate,
        Notify("O Prazo não pode ser anterior à Data da Demanda.", NotificationType.Error),

        cmbStatus.Selected.Value = "Concluído" && tglRequerEvidencia.Checked && CountRows(attAnexos.Attachments) = 0,
        Notify("Esta ação exige evidência: anexe pelo menos um arquivo para concluir.", NotificationType.Error),

        // ---- salva ----
        UpdateContext({varSalvando: true, varSalvouOk: true});
        IfError(
            Patch(
                Acoes,
                Defaults(Acoes),
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
                    Excluida: false,
                    CriadoPor: {
                        Claims: "i:0#.f|membership|" & Lower(User().Email),
                        Department: "",
                        DisplayName: User().FullName,
                        Email: Lower(User().Email),
                        JobTitle: "",
                        Picture: ""
                    }
                },
                frmAnexos.Updates
            ),
            UpdateContext({varSalvouOk: false});
            Notify("Não foi possível salvar: " & FirstError.Message & " Seus dados continuam na tela.", NotificationType.Error)
        );

        // ---- se salvou: limpa só o que muda de uma ação para outra ----
        If(
            varSalvouOk,
            Notify("Ação criada! Pode cadastrar a próxima (campos fixos mantidos).", NotificationType.Success);
            // LIMPA (muda a cada ação):
            Reset(txtAcao);
            Reset(dtPrazo);
            Reset(dtReprogramaçao);
            Reset(dtConclusao);
            Reset(txtObservacao);
            Reset(cmbStatus);
            ResetForm(frmAnexos);
            // MANTÉM (não tem Reset): Gerência, Origem, Detalhamento, Data da Demanda,
            // Prioridade, Solicitante, Responsável, Visibilidade, Requer evidência
        );
        UpdateContext({varSalvando: false})
    )
)
