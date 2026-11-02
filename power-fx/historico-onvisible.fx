UpdateContext({locHsFiltro: "Tudo", locHsAcao: LookUp(Acoes, ID = varAcaoHistorico.ID)});
ClearCollect(
    colHsHist,
    SortByColumns(
        Filter(HistoricoAcoes, AcaoID = varAcaoHistorico.ID Or acaoID = varAcaoHistorico.ID),
        "DataHora",
        SortOrder.Descending
    )
)
