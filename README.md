# Pipeline Analítico de E-commerce (SQL + Python)

Pipeline que transforma o banco relacional do e-commerce brasileiro **Olist**
(9 tabelas, ~100 mil pedidos) em uma **tabela analítica única**, pronta para BI.

## 🎯 O projeto

- **Desafio:** consolidar dados espalhados em várias tabelas (pedidos, itens,
  pagamentos, avaliações, clientes) em uma base única para análise.
- **O que fiz:** pipeline em SQL com CTEs encadeadas, window functions e cálculo
  de KPIs de logística (entrega no prazo, atraso) e satisfação, orquestrado por
  um script Python que cria o banco SQLite e exporta o resultado.
- **Resultado:** tabela analítica com 96.478 pedidos e indicadores de negócio
  prontos para dashboard.

## 📈 Principais números

- Receita total: **R$ 15,4 milhões**
- Ticket médio: **R$ 159,83**
- Entregas no prazo: **93,2%**
- Nota média de satisfação: **4,16 / 5**
- Estado líder em receita: **São Paulo (R$ 5,7 mi)**

## 🛠️ Ferramentas

SQL (SQLite) · Python · pandas · CTEs · Window functions

## ▶️ Como rodar

1. Baixe o [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle).
2. Coloque os CSVs numa pasta `archive/`.
3. Instale as dependências: `pip install pandas`
4. Rode: `python rodar_pipeline_olist.py`

Gera o banco `olist.db` e a tabela final `tabela_analitica_olist.csv`.

## 📂 Arquivos

- `pipeline_olist_sqlite.sql` — o pipeline SQL comentado
- `rodar_pipeline_olist.py` — cria o banco e executa o pipeline

## 📊 Fonte dos dados

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) · Kaggle.
