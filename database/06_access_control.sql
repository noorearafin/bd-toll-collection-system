-- =====================================================================
--  Bangladesh Toll Collection System (BD-TCS)
--  06_access_control.sql  -  Admin-configurable permissions
--
--  What this adds
--    * TC_PERMISSION        : catalogue of permissions (one per feature)
--    * TC_ROLE_PERMISSION   : default permissions of each role (matrix)
--    * TC_EMP_PERMISSION    : per-user override  (GRANT extra / REVOKE)
--    * TC_EMP_PLAZA_ACCESS  : extra plazas a user may work with
--    * TC_ACCESS_PKG        : has_perm / can_access_plaza / set_user_access
--    * Views                : role matrix (editable), effective permissions,
--                             my plazas, user access summary
--    * TC_V_TXN and TC_V_SHIFT_SUMMARY are re-created with plaza scoping,
--      so every report built on them only shows the user's plazas.
--
--  Rule used everywhere
--    ADMIN                      -> everything, every plaza (cannot be locked out)
--    user REVOKE                -> denied, even if the role has it
--    user GRANT                 -> allowed, even if the role does not have it
--    otherwise                  -> whatever TC_ROLE_PERMISSION says for the role
--    Plaza: home plaza (tc_employee.plaza_id) + TC_EMP_PLAZA_ACCESS rows,
--           or every plaza with the ALL_PLAZA_ACCESS permission.
--
--  Run AFTER 01-05 in SQL Workshop -> SQL Scripts (safe to re-run).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Clean re-run (ignore "does not exist" errors on the first run)
-- ---------------------------------------------------------------------
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
             WHERE table_name IN ('TC_EMP_PLAZA_ACCESS','TC_EMP_PERMISSION',
                                  'TC_ROLE_PERMISSION','TC_PERMISSION')
             ORDER BY DECODE(table_name,'TC_EMP_PLAZA_ACCESS',1,'TC_EMP_PERMISSION',2,
                                        'TC_ROLE_PERMISSION',3,4)) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------
CREATE TABLE tc_permission (
  perm_code         VARCHAR2(30 CHAR) CONSTRAINT tc_permission_pk PRIMARY KEY
                    CONSTRAINT tc_permission_code_ck CHECK (REGEXP_LIKE(perm_code, '^[A-Z_]+$')),
  module            VARCHAR2(30 CHAR) NOT NULL,
  perm_name         VARCHAR2(100 CHAR) NOT NULL,
  perm_name_bn      VARCHAR2(100 CHAR),
  description       VARCHAR2(400 CHAR),
  sort_order        NUMBER(3) DEFAULT 0 NOT NULL
);
COMMENT ON TABLE tc_permission IS 'Catalogue of permissions. Each APEX authorization scheme checks one perm_code.';

CREATE TABLE tc_role_permission (
  role_code         VARCHAR2(15 CHAR) NOT NULL
                    CONSTRAINT tc_role_perm_role_ck CHECK (role_code IN ('TOLL_COLLECTOR','SUPERVISOR','PLAZA_MANAGER','ADMIN')),
  perm_code         VARCHAR2(30 CHAR) NOT NULL
                    CONSTRAINT tc_role_perm_perm_fk REFERENCES tc_permission (perm_code) ON DELETE CASCADE,
  CONSTRAINT tc_role_permission_pk PRIMARY KEY (role_code, perm_code)
);
COMMENT ON TABLE tc_role_permission IS 'Default permissions of a role (designation). Edited by Admin in the matrix page.';

CREATE TABLE tc_emp_permission (
  emp_id            NUMBER NOT NULL
                    CONSTRAINT tc_emp_perm_emp_fk REFERENCES tc_employee (emp_id) ON DELETE CASCADE,
  perm_code         VARCHAR2(30 CHAR) NOT NULL
                    CONSTRAINT tc_emp_perm_perm_fk REFERENCES tc_permission (perm_code) ON DELETE CASCADE,
  grant_type        VARCHAR2(6 CHAR) NOT NULL
                    CONSTRAINT tc_emp_perm_type_ck CHECK (grant_type IN ('GRANT','REVOKE')),
  granted_by        VARCHAR2(255 CHAR) DEFAULT ON NULL NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER),
  granted_at        DATE DEFAULT ON NULL SYSDATE,
  CONSTRAINT tc_emp_permission_pk PRIMARY KEY (emp_id, perm_code)
);
COMMENT ON TABLE tc_emp_permission IS 'Per-user override: GRANT adds a permission the role lacks, REVOKE removes one the role has.';

CREATE TABLE tc_emp_plaza_access (
  emp_id            NUMBER NOT NULL
                    CONSTRAINT tc_emp_plaza_emp_fk REFERENCES tc_employee (emp_id) ON DELETE CASCADE,
  plaza_id          NUMBER NOT NULL
                    CONSTRAINT tc_emp_plaza_plaza_fk REFERENCES tc_toll_plaza (plaza_id) ON DELETE CASCADE,
  granted_by        VARCHAR2(255 CHAR) DEFAULT ON NULL NVL(SYS_CONTEXT('APEX$SESSION','APP_USER'), USER),
  granted_at        DATE DEFAULT ON NULL SYSDATE,
  CONSTRAINT tc_emp_plaza_access_pk PRIMARY KEY (emp_id, plaza_id)
);
COMMENT ON TABLE tc_emp_plaza_access IS 'Extra plazas a user may see and work with, in addition to the home plaza.';

CREATE INDEX tc_role_perm_perm_ix  ON tc_role_permission (perm_code);
CREATE INDEX tc_emp_perm_perm_ix   ON tc_emp_permission (perm_code);
CREATE INDEX tc_emp_plaza_plaza_ix ON tc_emp_plaza_access (plaza_id);

-- ---------------------------------------------------------------------
-- 2. PACKAGE
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE tc_access_pkg AS
  -- TRUE if the (current) user has the permission
  FUNCTION has_perm    (p_perm IN VARCHAR2, p_username IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
  FUNCTION has_perm_yn (p_perm IN VARCHAR2, p_username IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;

  -- Why a user has / lacks a permission: ADMIN, ROLE, GRANT, REVOKE, NONE
  FUNCTION perm_source (p_emp_id IN NUMBER, p_perm IN VARCHAR2) RETURN VARCHAR2;

  -- 'Y' if the (current) user may see / work with this plaza
  FUNCTION can_access_plaza (p_plaza_id IN NUMBER, p_username IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;

  -- Admin "Edit User Access" page: colon separated lists from shuttles
  PROCEDURE set_user_access (p_emp_id  IN NUMBER,
                             p_grants  IN VARCHAR2,
                             p_revokes IN VARCHAR2,
                             p_plazas  IN VARCHAR2);
END tc_access_pkg;
/

CREATE OR REPLACE PACKAGE BODY tc_access_pkg AS

  FUNCTION perm_source (p_emp_id IN NUMBER, p_perm IN VARCHAR2) RETURN VARCHAR2 IS
    l_desig  tc_employee.designation%TYPE;
    l_active tc_employee.is_active%TYPE;
    l_type   tc_emp_permission.grant_type%TYPE;
    l_cnt    PLS_INTEGER;
  BEGIN
    SELECT designation, is_active INTO l_desig, l_active
      FROM tc_employee WHERE emp_id = p_emp_id;

    IF l_active <> 'Y' THEN
      RETURN 'NONE';
    ELSIF l_desig = 'ADMIN' THEN
      RETURN 'ADMIN';
    END IF;

    BEGIN
      SELECT grant_type INTO l_type
        FROM tc_emp_permission
       WHERE emp_id = p_emp_id AND perm_code = UPPER(p_perm);
      RETURN l_type;                         -- GRANT or REVOKE wins over the role
    EXCEPTION
      WHEN NO_DATA_FOUND THEN NULL;
    END;

    SELECT COUNT(*) INTO l_cnt
      FROM tc_role_permission
     WHERE role_code = l_desig AND perm_code = UPPER(p_perm);

    RETURN CASE WHEN l_cnt > 0 THEN 'ROLE' ELSE 'NONE' END;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'NONE';
  END perm_source;

  FUNCTION has_perm (p_perm IN VARCHAR2, p_username IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    l_emp_id NUMBER := tc_toll_pkg.current_emp_id(p_username);
  BEGIN
    IF l_emp_id IS NULL THEN
      RETURN FALSE;
    END IF;
    RETURN perm_source(l_emp_id, p_perm) IN ('ADMIN','ROLE','GRANT');
  END has_perm;

  FUNCTION has_perm_yn (p_perm IN VARCHAR2, p_username IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN has_perm(p_perm, p_username) THEN 'Y' ELSE 'N' END;
  END has_perm_yn;

  FUNCTION can_access_plaza (p_plaza_id IN NUMBER, p_username IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    l_app_id NUMBER := NV('APP_ID');
    l_emp_id NUMBER;
    l_desig  tc_employee.designation%TYPE;
    l_home   tc_employee.plaza_id%TYPE;
    l_cnt    PLS_INTEGER;
  BEGIN
    -- Outside the application (SQL Workshop, SQL Developer, APEX builder 4xxx):
    -- do not filter, so the developer still sees all data.
    IF p_username IS NULL AND (l_app_id IS NULL OR l_app_id BETWEEN 4000 AND 4999) THEN
      RETURN 'Y';
    END IF;

    l_emp_id := tc_toll_pkg.current_emp_id(p_username);
    IF l_emp_id IS NULL THEN
      RETURN 'N';
    END IF;

    SELECT designation, plaza_id INTO l_desig, l_home
      FROM tc_employee WHERE emp_id = l_emp_id;

    IF l_desig = 'ADMIN' OR l_home = p_plaza_id THEN
      RETURN 'Y';
    END IF;

    IF perm_source(l_emp_id, 'ALL_PLAZA_ACCESS') IN ('ROLE','GRANT') THEN
      RETURN 'Y';
    END IF;

    SELECT COUNT(*) INTO l_cnt
      FROM tc_emp_plaza_access
     WHERE emp_id = l_emp_id AND plaza_id = p_plaza_id;

    RETURN CASE WHEN l_cnt > 0 THEN 'Y' ELSE 'N' END;
  END can_access_plaza;

  PROCEDURE set_user_access (p_emp_id  IN NUMBER,
                             p_grants  IN VARCHAR2,
                             p_revokes IN VARCHAR2,
                             p_plazas  IN VARCHAR2) IS
    l_grants  apex_t_varchar2 := apex_string.split(p_grants,  ':');
    l_revokes apex_t_varchar2 := apex_string.split(p_revokes, ':');
    l_plazas  apex_t_varchar2 := apex_string.split(p_plazas,  ':');
    l_cnt     PLS_INTEGER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM tc_employee WHERE emp_id = p_emp_id;
    IF l_cnt = 0 THEN
      RAISE_APPLICATION_ERROR(-20060, 'Employee not found.');
    END IF;

    -- the same permission cannot be both granted and revoked
    SELECT COUNT(*) INTO l_cnt
      FROM TABLE(l_grants) g JOIN TABLE(l_revokes) r ON r.column_value = g.column_value
     WHERE g.column_value IS NOT NULL;
    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(-20061,
        'একই permission একসাথে Extra Grant আর Revoke করা যাবে না। / A permission cannot be both granted and revoked.');
    END IF;

    DELETE FROM tc_emp_permission   WHERE emp_id = p_emp_id;
    DELETE FROM tc_emp_plaza_access WHERE emp_id = p_emp_id;

    INSERT INTO tc_emp_permission (emp_id, perm_code, grant_type)
      SELECT p_emp_id, column_value, 'GRANT'  FROM TABLE(l_grants)  WHERE column_value IS NOT NULL;
    INSERT INTO tc_emp_permission (emp_id, perm_code, grant_type)
      SELECT p_emp_id, column_value, 'REVOKE' FROM TABLE(l_revokes) WHERE column_value IS NOT NULL;

    -- home plaza is always accessible, so it is not stored again
    INSERT INTO tc_emp_plaza_access (emp_id, plaza_id)
      SELECT p_emp_id, TO_NUMBER(column_value)
        FROM TABLE(l_plazas)
       WHERE column_value IS NOT NULL
         AND TO_NUMBER(column_value) <> NVL((SELECT plaza_id FROM tc_employee WHERE emp_id = p_emp_id), -1);
  END set_user_access;

END tc_access_pkg;
/

-- ---------------------------------------------------------------------
-- 2b. TC_TOLL_PKG.void_txn: check the TXN_VOID permission instead of the
--     old "Supervisor or above" rank, so the database agrees with the
--     Admin's settings. (Re-compiles the existing package body from
--     USER_SOURCE with that one line changed; skipped if already done.)
-- ---------------------------------------------------------------------
DECLARE
  l_ddl CLOB := 'CREATE OR REPLACE ';
  l_old CONSTANT VARCHAR2(200) := q'[IF role_rank(l_desig) < role_rank('SUPERVISOR') THEN]';
  l_new CONSTANT VARCHAR2(200) := q'[IF tc_access_pkg.perm_source(p_voided_by, 'TXN_VOID') NOT IN ('ADMIN','ROLE','GRANT') THEN]';
BEGIN
  FOR r IN (SELECT text FROM user_source
             WHERE name = 'TC_TOLL_PKG' AND type = 'PACKAGE BODY' ORDER BY line) LOOP
    l_ddl := l_ddl || r.text;
  END LOOP;
  IF INSTR(l_ddl, l_old) > 0 THEN
    l_ddl := REPLACE(l_ddl, l_old, l_new);
    l_ddl := REPLACE(l_ddl, 'Only a Supervisor or above can void a toll receipt.',
                            'You do not have the TXN_VOID permission to void a toll receipt.');
    EXECUTE IMMEDIATE l_ddl;
  END IF;
END;
/

-- ---------------------------------------------------------------------
-- 3. SEED: permission catalogue + default role matrix
--    (defaults reproduce the old IS_COLLECTOR/IS_SUPERVISOR/... behaviour)
-- ---------------------------------------------------------------------
INSERT INTO tc_permission VALUES ('TOLL_COLLECT',      'Operations',   'Toll Booth: collect toll',          'টোল আদায়',                 'Toll Booth and Receipt pages', 10);
INSERT INTO tc_permission VALUES ('ANY_SHIFT_COLLECT', 'Operations',   'Collect on other users'' shifts',  'অন্যের শিফটে টোল আদায়',      'Without it a collector sees only own open shift in Toll Booth', 15);
INSERT INTO tc_permission VALUES ('SHIFT_VIEW',        'Operations',   'View shifts',                      'শিফট দেখা',                  'Shifts report', 20);
INSERT INTO tc_permission VALUES ('SHIFT_OPEN',        'Operations',   'Open shift',                       'শিফট খোলা',                  'Open Shift dialog', 30);
INSERT INTO tc_permission VALUES ('SHIFT_CLOSE',       'Operations',   'Close shift and cash-up',          'শিফট বন্ধ ও ক্যাশ মেলানো',      'Close Shift dialog', 40);
INSERT INTO tc_permission VALUES ('TXN_VIEW',          'Operations',   'View transactions',                'লেনদেন দেখা',                'Transactions report', 50);
INSERT INTO tc_permission VALUES ('TXN_VOID',          'Operations',   'Void a receipt',                   'রসিদ বাতিল',                 'Void link and Void Receipt dialog', 60);
INSERT INTO tc_permission VALUES ('VEHICLE_VIEW',      'Vehicles',     'View vehicles',                    'গাড়ি দেখা',                  'Vehicles report', 110);
INSERT INTO tc_permission VALUES ('VEHICLE_MANAGE',    'Vehicles',     'Add / edit vehicles and owners',   'গাড়ি ও মালিক নিবন্ধন',         'Vehicle form buttons, Owners pages', 120);
INSERT INTO tc_permission VALUES ('TAG_MANAGE',        'Vehicles',     'RFID tags and recharge',           'RFID ট্যাগ ও রিচার্জ',          'RFID Tags pages and Recharge dialog', 130);
INSERT INTO tc_permission VALUES ('VIOLATION_MANAGE',  'Vehicles',     'Violations',                       'লঙ্ঘন ব্যবস্থাপনা',             'Violations pages', 140);
INSERT INTO tc_permission VALUES ('REPORT_REVENUE',    'Reports',      'Revenue reports',                  'আয়ের রিপোর্ট',               'Daily Revenue report', 210);
INSERT INTO tc_permission VALUES ('MASTER_DATA',       'Administration','Plazas, lanes, classes, rates',   'প্লাজা, লেন, শ্রেণি, রেট',        'Master data grids', 310);
INSERT INTO tc_permission VALUES ('SYSTEM_SETUP',      'Administration','Employees, payment methods, exemptions', 'কর্মী ও সিস্টেম সেটআপ', 'Admin setup pages', 320);
INSERT INTO tc_permission VALUES ('ALL_PLAZA_ACCESS',  'Access',       'Access every plaza',               'সব প্লাজার ডেটা',              'Data from all plazas, not only home + assigned plazas', 410);
INSERT INTO tc_permission VALUES ('ACCESS_MANAGE',     'Access',       'Manage roles and user access',     'পারমিশন ব্যবস্থাপনা',           'Role Permissions and User Access pages', 420);

-- Toll Collector
INSERT INTO tc_role_permission (role_code, perm_code)
  SELECT 'TOLL_COLLECTOR', perm_code FROM tc_permission
   WHERE perm_code IN ('TOLL_COLLECT','SHIFT_VIEW','SHIFT_OPEN','TXN_VIEW','VEHICLE_VIEW');
-- Supervisor = collector + supervision
INSERT INTO tc_role_permission (role_code, perm_code)
  SELECT 'SUPERVISOR', perm_code FROM tc_permission
   WHERE perm_code IN ('TOLL_COLLECT','SHIFT_VIEW','SHIFT_OPEN','TXN_VIEW','VEHICLE_VIEW',
                       'SHIFT_CLOSE','TXN_VOID','VEHICLE_MANAGE','TAG_MANAGE','VIOLATION_MANAGE');
-- Plaza Manager = supervisor + reports + master data
INSERT INTO tc_role_permission (role_code, perm_code)
  SELECT 'PLAZA_MANAGER', perm_code FROM tc_permission
   WHERE perm_code IN ('TOLL_COLLECT','SHIFT_VIEW','SHIFT_OPEN','TXN_VIEW','VEHICLE_VIEW',
                       'SHIFT_CLOSE','TXN_VOID','VEHICLE_MANAGE','TAG_MANAGE','VIOLATION_MANAGE',
                       'REPORT_REVENUE','MASTER_DATA');
-- Admin: everything (also enforced in code, stored here only for display)
INSERT INTO tc_role_permission (role_code, perm_code)
  SELECT 'ADMIN', perm_code FROM tc_permission;

-- Demo: Manager Shahana (E002) also looks after the other Padma plaza
INSERT INTO tc_emp_plaza_access (emp_id, plaza_id)
  SELECT e.emp_id, p.plaza_id
    FROM tc_employee e, tc_toll_plaza p
   WHERE e.emp_code = 'E002' AND p.plaza_code IN ('PDM-MAWA','PDM-JANJ')
     AND p.plaza_id <> NVL(e.plaza_id, -1);

COMMIT;

-- ---------------------------------------------------------------------
-- 4. VIEWS
-- ---------------------------------------------------------------------

-- Plazas the logged-in user may see (used to scope reports and LOVs)
CREATE OR REPLACE VIEW tc_v_my_plaza AS
SELECT p.plaza_id, p.plaza_code, p.plaza_name
  FROM tc_toll_plaza p
 WHERE tc_access_pkg.can_access_plaza(p.plaza_id) = 'Y';

-- Editable Role x Permission matrix (Interactive Grid source)
CREATE OR REPLACE VIEW tc_v_role_perm_matrix AS
SELECT p.perm_code,
       p.module,
       p.perm_name,
       p.perm_name_bn,
       p.description,
       p.sort_order,
       CASE WHEN EXISTS (SELECT 1 FROM tc_role_permission r
                          WHERE r.perm_code = p.perm_code AND r.role_code = 'TOLL_COLLECTOR')
            THEN 'Y' ELSE 'N' END AS collector,
       CASE WHEN EXISTS (SELECT 1 FROM tc_role_permission r
                          WHERE r.perm_code = p.perm_code AND r.role_code = 'SUPERVISOR')
            THEN 'Y' ELSE 'N' END AS supervisor,
       CASE WHEN EXISTS (SELECT 1 FROM tc_role_permission r
                          WHERE r.perm_code = p.perm_code AND r.role_code = 'PLAZA_MANAGER')
            THEN 'Y' ELSE 'N' END AS manager,
       'Y' AS admin
  FROM tc_permission p;

CREATE OR REPLACE TRIGGER tc_v_role_perm_matrix_iou
INSTEAD OF UPDATE ON tc_v_role_perm_matrix
FOR EACH ROW
DECLARE
  PROCEDURE sync_role (p_role IN VARCHAR2, p_flag IN VARCHAR2) IS
  BEGIN
    DELETE FROM tc_role_permission WHERE role_code = p_role AND perm_code = :old.perm_code;
    IF p_flag = 'Y' THEN
      INSERT INTO tc_role_permission (role_code, perm_code) VALUES (p_role, :old.perm_code);
    END IF;
  END sync_role;
BEGIN
  sync_role('TOLL_COLLECTOR', NVL(:new.collector,  'N'));
  sync_role('SUPERVISOR',     NVL(:new.supervisor, 'N'));
  sync_role('PLAZA_MANAGER',  NVL(:new.manager,    'N'));
END;
/

-- Effective permission of every active employee (with the reason)
CREATE OR REPLACE VIEW tc_v_emp_effective_perm AS
SELECT x.emp_id, x.emp_code, x.full_name, x.designation,
       x.module, x.perm_code, x.perm_name, x.sort_order,
       x.source,
       CASE WHEN x.source IN ('ADMIN','ROLE','GRANT') THEN 'Y' ELSE 'N' END AS allowed
  FROM (SELECT e.emp_id, e.emp_code, e.full_name, e.designation,
               p.module, p.perm_code, p.perm_name, p.sort_order,
               tc_access_pkg.perm_source(e.emp_id, p.perm_code) AS source
          FROM tc_employee e CROSS JOIN tc_permission p
         WHERE e.is_active = 'Y') x;

-- One row per employee for the "User Access" report
CREATE OR REPLACE VIEW tc_v_user_access AS
SELECT e.emp_id,
       e.emp_code,
       e.full_name,
       e.designation,
       e.apex_username,
       e.is_active,
       hp.plaza_code                                                     AS home_plaza,
       (SELECT LISTAGG(p.plaza_code, ', ') WITHIN GROUP (ORDER BY p.plaza_code)
          FROM tc_emp_plaza_access a JOIN tc_toll_plaza p ON p.plaza_id = a.plaza_id
         WHERE a.emp_id = e.emp_id)                                      AS extra_plazas,
       (SELECT LISTAGG(ep.perm_code, ', ') WITHIN GROUP (ORDER BY ep.perm_code)
          FROM tc_emp_permission ep
         WHERE ep.emp_id = e.emp_id AND ep.grant_type = 'GRANT')         AS extra_grants,
       (SELECT LISTAGG(ep.perm_code, ', ') WITHIN GROUP (ORDER BY ep.perm_code)
          FROM tc_emp_permission ep
         WHERE ep.emp_id = e.emp_id AND ep.grant_type = 'REVOKE')        AS revoked
  FROM tc_employee e
  LEFT JOIN tc_toll_plaza hp ON hp.plaza_id = e.plaza_id;

-- Re-create the two base report views with plaza scoping.
-- (tc_v_daily_revenue is built on tc_v_txn, so it is scoped automatically.)
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
  LEFT JOIN tc_exemption_type x  ON x.exemption_code  = t.exemption_code
 WHERE p.plaza_id IN (SELECT plaza_id FROM tc_v_my_plaza);

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
       sup.full_name                                     AS closed_by_name,
       p.plaza_id,
       s.emp_id
  FROM tc_shift s
  JOIN tc_toll_lane  l ON l.lane_id  = s.lane_id
  JOIN tc_toll_plaza p ON p.plaza_id = l.plaza_id
  JOIN tc_employee   e ON e.emp_id   = s.emp_id
  LEFT JOIN tc_employee sup ON sup.emp_id = s.closed_by
 WHERE p.plaza_id IN (SELECT plaza_id FROM tc_v_my_plaza);

-- ---------------------------------------------------------------------
-- 5. Quick check (run in SQL Commands afterwards)
--   select designation, perm_code, source, allowed
--     from tc_v_emp_effective_perm where emp_code in ('E002','E004') order by 1, 2;
-- ---------------------------------------------------------------------
