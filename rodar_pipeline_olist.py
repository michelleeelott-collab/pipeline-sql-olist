"""
================================================================================
Pipeline Analítico Olist — Execução via Python + SQLite
--------------------------------------------------------------------------------
Autora: Michelle Lott
Ferramentas: Python, SQL (SQLite), pandas

O que faz:
  1. Lê os 5 CSVs do dataset Olist e cria um banco SQLite local (olist.db).
  2. Executa o pipeline SQL (arquivo pipeline_olist_sqlite.sql).
  3. Salva o resultado (tabela analítica) em 'tabela_analitica_olist.csv'.

COMO USAR:
  1. Deixe este script, o arquivo pipeline_olist_sqlite.sql e a pasta com os
     CSVs na mesma pasta do projeto.
  2. Ajuste PASTA_CSV abaixo se os CSVs estiverem em outro lugar.
  3. Instale: pip install pandas
  4. Rode: python rodar_pipeline_olist.py
================================================================================
"""

import os
import sqlite3
import pandas as pd

# ============================ CONFIGURAÇÃO =================================
PASTA_CSV = "archive"                          # pasta onde estão os CSVs
ARQUIVO_SQL = "pipeline_olist_sqlite.sql"  # arquivo com o pipeline
BANCO = "olist.db"                        # banco SQLite gerado
SAIDA = "tabela_analitica_olist.csv"      # resultado final
# ===========================================================================

TABELAS = [
    "olist_orders_dataset",
    "olist_customers_dataset",
    "olist_order_items_dataset",
    "olist_order_payments_dataset",
    "olist_order_reviews_dataset",
]


def criar_banco():
    """Lê os CSVs e monta o banco SQLite."""
    print("1. Criando o banco SQLite a partir dos CSVs...")
    con = sqlite3.connect(BANCO)
    for tabela in TABELAS:
        caminho = os.path.join(PASTA_CSV, tabela + ".csv")
        if not os.path.exists(caminho):
            raise FileNotFoundError(
                f"Não encontrei '{caminho}'. Ajuste a variável PASTA_CSV.")
        df = pd.read_csv(caminho)
        df.to_sql(tabela, con, if_exists="replace", index=False)
        print(f"   {tabela}: {len(df):,} linhas")
    con.commit()
    return con


def rodar_pipeline(con):
    """Executa o bloco principal do pipeline SQL."""
    print("\n2. Executando o pipeline SQL...")
    with open(ARQUIVO_SQL, encoding="utf-8") as f:
        sql = f.read()

    # Usa só o bloco principal (antes das consultas de apoio comentadas)
    sql_principal = sql.split("CONSULTAS DE APOIO")[0].rsplit("/* ===", 1)[0]

    df = pd.read_sql_query(sql_principal, con)
    print(f"   Pipeline concluído: {len(df):,} pedidos na tabela analítica.")
    return df


def resumo(df):
    """Mostra alguns KPIs rápidos para conferência."""
    print("\n3. KPIs rápidos:")
    print(f"   Receita total: R$ {df['receita_total'].sum():,.2f}")
    print(f"   Ticket médio:  R$ {df['receita_total'].mean():,.2f}")
    print(f"   Entregas no prazo: {df['entregue_no_prazo'].mean()*100:.1f}%")
    print(f"   Nota média: {df['review_score'].mean():.2f}")
    print("\n   Top 5 estados por receita:")
    top = (df.groupby("uf")["receita_total"].sum()
             .sort_values(ascending=False).head())
    for uf, v in top.items():
        print(f"     {uf}: R$ {v:,.2f}")


if __name__ == "__main__":
    con = criar_banco()
    df = rodar_pipeline(con)
    df.to_csv(SAIDA, index=False, encoding="utf-8-sig")
    print(f"\n[ok] Tabela analítica salva: {SAIDA}")
    resumo(df)
    con.close()
    print("\nConcluído. ✅")
