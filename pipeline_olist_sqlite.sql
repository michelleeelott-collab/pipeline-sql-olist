/* =============================================================================
   PIPELINE ANALÍTICO — E-COMMERCE OLIST  (versão SQLite)
   Do banco relacional cru à tabela analítica pronta para BI
   -----------------------------------------------------------------------------
   Autora: Michelle Lott
   Ferramentas: SQL (CTEs, joins, window functions, agregações)
   Dataset: Brazilian E-Commerce Public Dataset by Olist (Kaggle)

   OBJETIVO: transformar as tabelas relacionais em uma tabela analítica única,
   no nível do pedido, pronta para alimentar um dashboard.

   DIALETO: SQLite (compatível com SQLiteOnline, DB Browser, etc.).
   ============================================================================= */


/* -----------------------------------------------------------------------------
   ETAPA 1 — Consolidar itens por pedido
   Um pedido tem vários itens. Agregamos para o nível do pedido.
   ----------------------------------------------------------------------------- */
WITH itens_por_pedido AS (
    SELECT
        order_id,
        COUNT(*)                    AS qtd_itens,
        SUM(price)                  AS receita_produtos,
        SUM(freight_value)          AS total_frete,
        COUNT(DISTINCT seller_id)   AS qtd_vendedores
    FROM olist_order_items_dataset
    GROUP BY order_id
),

/* -----------------------------------------------------------------------------
   ETAPA 2 — Pagamento por pedido
   Consolida múltiplas formas de pagamento em um valor total por pedido.
   (No SQLite usamos GROUP_CONCAT no lugar do STRING_AGG do PostgreSQL.)
   ----------------------------------------------------------------------------- */
pagamento_por_pedido AS (
    SELECT
        order_id,
        SUM(payment_value)                AS valor_pago,
        MAX(payment_installments)         AS max_parcelas,
        GROUP_CONCAT(DISTINCT payment_type) AS formas_pagamento
    FROM olist_order_payments_dataset
    GROUP BY order_id
),

/* -----------------------------------------------------------------------------
   ETAPA 3 — Avaliação por pedido
   Alguns pedidos têm mais de uma review; ficamos com a mais recente.
   ----------------------------------------------------------------------------- */
review_por_pedido AS (
    SELECT order_id, review_score
    FROM (
        SELECT
            order_id,
            review_score,
            ROW_NUMBER() OVER (
                PARTITION BY order_id
                ORDER BY review_creation_date DESC
            ) AS rn
        FROM olist_order_reviews_dataset
    )
    WHERE rn = 1
),

/* -----------------------------------------------------------------------------
   ETAPA 4 — Tabela-base do pedido
   Junta pedido + cliente + os blocos acima. Calcula prazos de entrega.
   (No SQLite as datas são texto; usamos julianday() para calcular dias.)
   ----------------------------------------------------------------------------- */
base_pedidos AS (
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_state                             AS uf,
        o.order_status                               AS status,
        o.order_purchase_timestamp                   AS data_compra,
        strftime('%Y-%m', o.order_purchase_timestamp) AS mes_compra,

        i.qtd_itens,
        i.qtd_vendedores,
        i.receita_produtos,
        i.total_frete,
        (i.receita_produtos + i.total_frete)         AS receita_total,
        p.valor_pago,
        p.max_parcelas,
        p.formas_pagamento,
        rv.review_score,

        /* Dias entre a compra e a entrega efetiva */
        CAST(julianday(o.order_delivered_customer_date)
             - julianday(o.order_purchase_timestamp) AS INTEGER) AS dias_entrega,

        /* Atraso: entrega real - estimada (positivo = atrasou) */
        CAST(julianday(o.order_delivered_customer_date)
             - julianday(o.order_estimated_delivery_date) AS INTEGER) AS dias_atraso
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset      c  ON c.customer_id = o.customer_id
    LEFT JOIN itens_por_pedido        i  ON i.order_id   = o.order_id
    LEFT JOIN pagamento_por_pedido    p  ON p.order_id   = o.order_id
    LEFT JOIN review_por_pedido       rv ON rv.order_id  = o.order_id
    WHERE o.order_status = 'delivered'
),

/* -----------------------------------------------------------------------------
   ETAPA 5 — Ranking de estados por receita
   Agrega a receita por UF e ranqueia (window function sobre o agregado).
   ----------------------------------------------------------------------------- */
ranking_uf AS (
    SELECT
        uf,
        SUM(receita_total)                              AS receita_uf,
        DENSE_RANK() OVER (ORDER BY SUM(receita_total) DESC) AS rank_uf_receita
    FROM base_pedidos
    GROUP BY uf
)

/* -----------------------------------------------------------------------------
   CAMADA ANALÍTICA FINAL
   Enriquecemos cada pedido com flags, faixa de satisfação, ticket médio do
   estado (window) e o ranking da UF. É a tabela que vai para o BI.
   ----------------------------------------------------------------------------- */
SELECT
    b.*,

    /* Entrega no prazo (KPI de logística) */
    CASE WHEN b.dias_atraso <= 0 THEN 1 ELSE 0 END      AS entregue_no_prazo,

    /* Faixa de satisfação a partir da nota */
    CASE
        WHEN b.review_score >= 4 THEN 'Satisfeito'
        WHEN b.review_score = 3  THEN 'Neutro'
        WHEN b.review_score <= 2 THEN 'Insatisfeito'
        ELSE 'Sem avaliacao'
    END                                                 AS faixa_satisfacao,

    /* Ticket médio do estado (window function) */
    ROUND(AVG(b.receita_total) OVER (PARTITION BY b.uf), 2) AS ticket_medio_uf,

    /* Ranking do estado por receita */
    r.rank_uf_receita
FROM base_pedidos b
LEFT JOIN ranking_uf r ON r.uf = b.uf
ORDER BY b.data_compra;


/* =============================================================================
   CONSULTAS DE APOIO (rode uma de cada vez, separadas do bloco acima)
   ============================================================================= */

/* KPI 1 — Receita e ticket médio por mês (série temporal)
SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS mes,
       SUM(i.price + i.freight_value)                AS receita,
       AVG(i.price + i.freight_value)                AS ticket_medio
FROM olist_orders_dataset o
JOIN olist_order_items_dataset i ON i.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1 ORDER BY 1;
*/

/* KPI 2 — % de entregas no prazo por estado
SELECT c.customer_state,
       ROUND(AVG(CASE WHEN julianday(o.order_delivered_customer_date)
                          <= julianday(o.order_estimated_delivery_date)
                      THEN 1.0 ELSE 0 END), 3) AS pct_no_prazo
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY 1 ORDER BY 2 DESC;
*/

/* KPI 3 — Relação entre atraso na entrega e nota da avaliação
SELECT CASE WHEN julianday(o.order_delivered_customer_date)
                 <= julianday(o.order_estimated_delivery_date)
            THEN 'No prazo' ELSE 'Atrasado' END AS situacao,
       ROUND(AVG(r.review_score), 2)            AS nota_media
FROM olist_orders_dataset o
JOIN olist_order_reviews_dataset r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1;
*/
