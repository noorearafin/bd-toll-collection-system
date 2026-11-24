-- =====================================================================
--  Bangladesh Toll Collection System (BD-TCS)
--  03_views.sql  -  Reporting views used by the APEX pages
-- =====================================================================

-- Full transaction detail (Transactions report, Receipt page)
CREATE OR REPLACE VIEW tc_v_txn AS
SELECT t.txn_id,
       t.receipt_no,
       t.txn_time,
       TRUNC(t.txn_time)                    AS txn_date,
       p.plaza_id,
       p.plaza_code,
       p.plaza_name,
       p.plaza_name_bn,
       a.authority_code,
       l.lane_id,
       l.lane_no,
       l.lane_type,
       l.direction,
       s.shift_id,
       s.shift_code,
       e.emp_id                             AS collector_id,
       e.full_name                          AS collector_name,
       t.captured_reg_no,
       t.vehicle_id,
       c.class_id,
       c.class_code,
       c.class_name,
       c.class_name_bn,
       t.axle_count,
       t.toll_amount,
       tc_toll_pkg.fmt_bdt(t.toll_amount)   AS toll_amount_bdt,
       t.method_code,
       pm.method_name,
       t.payment_ref,
       t.tag_id,
       t.exemption_code,
       x.description                        AS exemption_desc,
       t.exemption_doc_ref,
       t.status,
       t.void_reason
  FROM tc_toll_txn t
  JOIN tc_shift          s  ON s.shift_id  = t.shift_id
  JOIN tc_toll_lane      l  ON l.lane_id   = s.lane_id
  JOIN tc_toll_plaza     p  ON p.plaza_id  = l.plaza_id
  JOIN tc_authority      a  ON a.authority_id = p.authority_id
  JOIN tc_employee       e  ON e.emp_id    = s.emp_id
  JOIN tc_toll_rate      r  ON r.rate_id   = t.rate_id
  JOIN tc_vehicle_class  c  ON c.class_id  = r.class_id
  LEFT JOIN tc_payment_method pm ON pm.method_code    = t.method_code
  LEFT JOIN tc_exemption_type x  ON x.exemption_code  = t.exemption_code;

-- Daily revenue per plaza and vehicle class (charts + reports)
CREATE OR REPLACE VIEW tc_v_daily_revenue AS
SELECT txn_date,
       plaza_id,
       plaza_code,
       plaza_name,
       class_code,
       class_name,
       COUNT(*)                                                    AS vehicle_count,
       SUM(CASE WHEN status = 'PAID'   THEN toll_amount ELSE 0 END) AS revenue,
       SUM(CASE WHEN status = 'EXEMPT' THEN 1 ELSE 0 END)          AS exempt_count,
       SUM(CASE WHEN method_code = 'CASH' AND status = 'PAID' THEN toll_amount ELSE 0 END) AS cash_revenue,
       SUM(CASE WHEN method_code = 'ETC'  AND status = 'PAID' THEN toll_amount ELSE 0 END) AS etc_revenue,
       SUM(CASE WHEN method_code IN ('BKASH','NAGAD','ROCKET','CARD') AND status = 'PAID'
                THEN toll_amount ELSE 0 END)                       AS digital_revenue
  FROM tc_v_txn
 WHERE status <> 'VOID'
 GROUP BY txn_date, plaza_id, plaza_code, plaza_name, class_code, class_name;

-- Shift reconciliation
CREATE OR REPLACE VIEW tc_v_shift_summary AS
SELECT s.shift_id,
       s.shift_date,
       s.shift_code,
       p.plaza_code,
       p.plaza_name,
       l.lane_no,
       l.lane_type,
       e.emp_code,
       e.full_name                                       AS collector_name,
       s.opened_at,
       s.closed_at,
       s.status,
       s.opening_float,
       (SELECT COUNT(*) FROM tc_toll_txn t
         WHERE t.shift_id = s.shift_id AND t.status <> 'VOID')                       AS vehicle_count,
       (SELECT NVL(SUM(t.toll_amount),0) FROM tc_toll_txn t
         WHERE t.shift_id = s.shift_id AND t.status = 'PAID')                        AS total_collection,
       (SELECT NVL(SUM(t.toll_amount),0) FROM tc_toll_txn t
         WHERE t.shift_id = s.shift_id AND t.status = 'PAID' AND t.method_code = 'CASH') AS cash_collection,
       s.declared_cash,
       s.cash_variance,
       sup.full_name                                     AS closed_by_name
  FROM tc_shift s
  JOIN tc_toll_lane  l ON l.lane_id  = s.lane_id
  JOIN tc_toll_plaza p ON p.plaza_id = l.plaza_id
  JOIN tc_employee   e ON e.emp_id   = s.emp_id
  LEFT JOIN tc_employee sup ON sup.emp_id = s.closed_by;

-- RFID tag balances with owner info
CREATE OR REPLACE VIEW tc_v_tag_balance AS
SELECT g.tag_id,
       g.tag_uid,
       g.status,
       g.balance,
       tc_toll_pkg.fmt_bdt(g.balance)                    AS balance_bdt,
       CASE WHEN g.balance < g.low_balance_limit THEN 'Y' ELSE 'N' END AS low_balance,
       v.vehicle_id,
       v.reg_no,
       c.class_name,
       o.full_name                                       AS owner_name,
       o.mobile                                          AS owner_mobile,
       g.issued_on
  FROM tc_etc_tag g
  JOIN tc_vehicle       v ON v.vehicle_id = g.vehicle_id
  JOIN tc_vehicle_class c ON c.class_id   = v.class_id
  JOIN tc_owner         o ON o.owner_id   = v.owner_id;

-- Current tariff board (rates in force today)
CREATE OR REPLACE VIEW tc_v_current_tariff AS
SELECT p.plaza_code,
       p.plaza_name,
       c.sort_order,
       c.class_code,
       c.class_name,
       c.class_name_bn,
       r.toll_amount,
       tc_toll_pkg.fmt_bdt(r.toll_amount)                AS toll_amount_bdt,
       r.extra_axle_amount,
       r.effective_from,
       r.reference_note
  FROM tc_toll_rate r
  JOIN tc_toll_plaza    p ON p.plaza_id = r.plaza_id
  JOIN tc_vehicle_class c ON c.class_id = r.class_id
 WHERE r.effective_from <= tc_toll_pkg.bd_now
   AND (r.effective_to IS NULL OR r.effective_to > tc_toll_pkg.bd_now);
