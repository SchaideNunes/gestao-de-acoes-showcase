If(
    IsBlank(varIdPeriodo),
    UpdateContext({varIdPeriodo: "3 meses", varIdInicio: DateAdd(Today(), -3, TimeUnit.Months), varIdCategoria: "Gerência"})
);
ClearCollect(
    colIdBase,
    Filter(
        Acoes,
        Excluida = false,
        Visibilidade.Value = "Pública"
            Or Lower(CriadoPor.Email) = Lower(User().Email)
            Or Lower(Solicitante) = Lower(User().FullName)
            Or User().Email in Responsavel.Email
    )
)
