-- =====================================================================
--  Bangladesh Toll Collection System (BD-TCS)
--  02_package.sql  -  Business logic (PL/SQL package TC_TOLL_PKG)
--  Error codes:
--    -20001 rate not found          -20010..-20019 toll collection
--    -20020..-20029 shift handling  -20030..-20039 ETC tag / recharge
--    -20040..-20049 void            -20050 general validation
-- =====================================================================
CREATE OR REPLACE PACKAGE tc_toll_pkg AS

  -- ---------- helpers ----------
  FUNCTION bd_now RETURN DATE;                                  -- current date-time in Asia/Dhaka
  FUNCTION fmt_bdt (p_amount IN NUMBER) RETURN VARCHAR2;        -- 1234567.5 -> ৳12,34,567.50 (lakh/crore grouping)
  FUNCTION bn_digits (p_text IN VARCHAR2) RETURN VARCHAR2;      -- 2026 -> ২০২৬
  FUNCTION normalize_reg_no (p_reg_no IN VARCHAR2) RETURN VARCHAR2;

  -- ---------- tariff ----------
  FUNCTION get_rate_id (p_plaza_id IN NUMBER,
                        p_class_id IN NUMBER,
                        p_on       IN DATE DEFAULT NULL) RETURN NUMBER;
  FUNCTION calc_toll   (p_plaza_id   IN NUMBER,
                        p_class_id   IN NUMBER,
                        p_axle_count IN NUMBER DEFAULT NULL,
                        p_on         IN DATE   DEFAULT NULL) RETURN NUMBER;
  FUNCTION shift_plaza_id (p_shift_id IN NUMBER) RETURN NUMBER;

  -- ---------- security (used by APEX authorization schemes) ----------
  FUNCTION current_emp_id (p_username IN VARCHAR2 DEFAULT NULL) RETURN NUMBER;
  FUNCTION has_role (p_role IN VARCHAR2, p_username IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
  FUNCTION has_role_yn (p_role IN VARCHAR2, p_username IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2; -- 'Y'/'N' for use in SQL

  -- ---------- operations ----------
  PROCEDURE open_shift (p_lane_id       IN  NUMBER,
                        p_emp_id        IN  NUMBER,
                        p_opening_float IN  NUMBER DEFAULT 0,
                        p_shift_id      OUT NUMBER);

  PROCEDURE collect_toll (p_shift_id       IN  NUMBER,
                          p_reg_no         IN  VARCHAR2,
                          p_class_id       IN  NUMBER,
                          p_axle_count     IN  NUMBER   DEFAULT NULL,
                          p_method_code    IN  VARCHAR2 DEFAULT 'CASH',
                          p_payment_ref    IN  VARCHAR2 DEFAULT NULL,
                          p_exemption_code IN  VARCHAR2 DEFAULT NULL,
                          p_exemption_doc  IN  VARCHAR2 DEFAULT NULL,
                          p_txn_id         OUT NUMBER,
                          p_receipt_no     OUT VARCHAR2,
                          p_amount         OUT NUMBER);

  PROCEDURE close_shift (p_shift_id      IN NUMBER,
                         p_declared_cash IN NUMBER,
                         p_closed_by     IN NUMBER   DEFAULT NULL,
                         p_remarks       IN VARCHAR2 DEFAULT NULL);

  PROCEDURE recharge_tag (p_tag_id      IN  NUMBER,
                          p_amount      IN  NUMBER,
                          p_method_code IN  VARCHAR2,
                          p_ref         IN  VARCHAR2 DEFAULT NULL,
                          p_recharge_id OUT NUMBER);

  PROCEDURE void_txn (p_txn_id    IN NUMBER,
                      p_reason    IN VARCHAR2,
                      p_voided_by IN NUMBER);

END tc_toll_pkg;
/

CREATE OR REPLACE PACKAGE BODY tc_toll_pkg AS

  -- ===================================================================
  -- HELPERS
  -- ===================================================================
  FUNCTION bd_now RETURN DATE IS
  BEGIN
    RETURN CAST(SYSTIMESTAMP AT TIME ZONE 'Asia/Dhaka' AS DATE);
  END bd_now;

  FUNCTION fmt_bdt (p_amount IN NUMBER) RETURN VARCHAR2 IS
    l_abs NUMBER;
    l_int VARCHAR2(40);
    l_dec VARCHAR2(2);
    l_res VARCHAR2(80);
  BEGIN
    IF p_amount IS NULL THEN
      RETURN NULL;
    END IF;
    l_abs := ROUND(ABS(p_amount), 2);
    l_int := TO_CHAR(TRUNC(l_abs));
    l_dec := LPAD(TO_CHAR(ROUND((l_abs - TRUNC(l_abs)) * 100)), 2, '0');
    IF LENGTH(l_int) > 3 THEN
      -- Bangladeshi grouping: last 3 digits, then groups of 2 (lakh, crore)
      l_res := ',' || SUBSTR(l_int, -3);
      l_int := SUBSTR(l_int, 1, LENGTH(l_int) - 3);
      WHILE LENGTH(l_int) > 2 LOOP
        l_res := ',' || SUBSTR(l_int, -2) || l_res;
        l_int := SUBSTR(l_int, 1, LENGTH(l_int) - 2);
      END LOOP;
      l_res := l_int || l_res;
    ELSE
      l_res := l_int;
    END IF;
    RETURN CASE WHEN p_amount < 0 THEN '-' END
           || TO_CHAR(UNISTR('\09F3'))          -- ৳ Bengali Taka sign
           || l_res || '.' || l_dec;
  END fmt_bdt;

  FUNCTION bn_digits (p_text IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN TRANSLATE(p_text, '0123456789',
                     TO_CHAR(UNISTR('\09E6\09E7\09E8\09E9\09EA\09EB\09EC\09ED\09EE\09EF')));
  END bn_digits;

  FUNCTION normalize_reg_no (p_reg_no IN VARCHAR2) RETURN VARCHAR2 IS
    l VARCHAR2(200);
  BEGIN
    l := UPPER(TRIM(p_reg_no));
    l := REGEXP_REPLACE(l, '\s+', ' ');               -- collapse spaces
    l := REGEXP_REPLACE(l, '\s*-\s*', '-');           -- no spaces around "-"
    -- accept "DHAKA METRO-GA-12-3456" as well as "DHAKA METRO-GA 12-3456"
    l := REGEXP_REPLACE(l, '-([A-Z]{1,4})-([0-9]{2})-([0-9]{4})$', '-\1 \2-\3');
    RETURN l;
  END normalize_reg_no;

  PROCEDURE fail (p_code IN PLS_INTEGER, p_msg IN VARCHAR2) IS
  BEGIN
    raise_application_error(p_code, p_msg);
  END fail;

  -- violations that must survive even if the toll transaction fails
  PROCEDURE log_violation_autonomous (p_shift_id   IN NUMBER,
                                      p_vehicle_id IN NUMBER,
                                      p_reg_no     IN VARCHAR2,
                                      p_type       IN VARCHAR2,
                                      p_remarks    IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO tc_violation (shift_id, vehicle_id, captured_reg_no, violation_type, detected_at, remarks)
    VALUES (p_shift_id, p_vehicle_id, p_reg_no, p_type, bd_now, p_remarks);
    COMMIT;
  END log_violation_autonomous;

  -- ===================================================================
  -- TARIFF
  -- ===================================================================
  FUNCTION get_rate_id (p_plaza_id IN NUMBER,
                        p_class_id IN NUMBER,
                        p_on       IN DATE DEFAULT NULL) RETURN NUMBER IS
    l_on      DATE := NVL(p_on, bd_now);
    l_rate_id tc_toll_rate.rate_id%TYPE;
  BEGIN
    SELECT rate_id
      INTO l_rate_id
      FROM tc_toll_rate
     WHERE plaza_id = p_plaza_id
       AND class_id = p_class_id
       AND effective_from <= l_on
       AND (effective_to IS NULL OR effective_to > l_on)
     ORDER BY effective_from DESC
     FETCH FIRST 1 ROWS ONLY;
    RETURN l_rate_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error(-20001,
        'No toll rate is defined for this vehicle class at this plaza - the vehicle class may not be permitted here.');
  END get_rate_id;

  FUNCTION calc_toll (p_plaza_id   IN NUMBER,
                      p_class_id   IN NUMBER,
                      p_axle_count IN NUMBER DEFAULT NULL,
                      p_on         IN DATE   DEFAULT NULL) RETURN NUMBER IS
    l_rate_id NUMBER;
    l_amount  tc_toll_rate.toll_amount%TYPE;
    l_extra   tc_toll_rate.extra_axle_amount%TYPE;
    l_min     tc_vehicle_class.min_axles%TYPE;
    l_max     tc_vehicle_class.max_axles%TYPE;
    l_axles   NUMBER;
  BEGIN
    l_rate_id := get_rate_id(p_plaza_id, p_class_id, p_on);

    SELECT r.toll_amount, r.extra_axle_amount, c.min_axles, c.max_axles
      INTO l_amount, l_extra, l_min, l_max
      FROM tc_toll_rate r
      JOIN tc_vehicle_class c ON c.class_id = r.class_id
     WHERE r.rate_id = l_rate_id;

    l_axles := NVL(p_axle_count, l_min);
    IF l_axles < l_min OR l_axles > l_max THEN
      raise_application_error(-20050,
        'Axle count must be between ' || l_min || ' and ' || l_max || ' for this vehicle class.');
    END IF;

    RETURN l_amount + (l_axles - l_min) * l_extra;
  END calc_toll;

  FUNCTION shift_plaza_id (p_shift_id IN NUMBER) RETURN NUMBER IS
    l_plaza_id NUMBER;
  BEGIN
    SELECT l.plaza_id
      INTO l_plaza_id
      FROM tc_shift s
      JOIN tc_toll_lane l ON l.lane_id = s.lane_id
     WHERE s.shift_id = p_shift_id;
    RETURN l_plaza_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END shift_plaza_id;

  -- ===================================================================
  -- SECURITY
  -- ===================================================================
  FUNCTION current_emp_id (p_username IN VARCHAR2 DEFAULT NULL) RETURN NUMBER IS
    l_user   VARCHAR2(255) := UPPER(COALESCE(p_username, SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER));
    l_emp_id NUMBER;
  BEGIN
    SELECT emp_id
      INTO l_emp_id
      FROM tc_employee
     WHERE UPPER(apex_username) = l_user
       AND is_active = 'Y';
    RETURN l_emp_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END current_emp_id;

  FUNCTION role_rank (p_role IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    RETURN CASE UPPER(p_role)
             WHEN 'TOLL_COLLECTOR' THEN 1
             WHEN 'SUPERVISOR'     THEN 2
             WHEN 'PLAZA_MANAGER'  THEN 3
             WHEN 'ADMIN'          THEN 4
             ELSE 99
           END;
  END role_rank;

  -- role hierarchy: ADMIN > PLAZA_MANAGER > SUPERVISOR > TOLL_COLLECTOR
  FUNCTION has_role (p_role IN VARCHAR2, p_username IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    l_emp_id NUMBER := current_emp_id(p_username);
    l_desig  tc_employee.designation%TYPE;
  BEGIN
    IF l_emp_id IS NULL THEN
      RETURN FALSE;
    END IF;
    SELECT designation INTO l_desig FROM tc_employee WHERE emp_id = l_emp_id;
    RETURN role_rank(l_desig) >= role_rank(p_role);
  END has_role;

  FUNCTION has_role_yn (p_role IN VARCHAR2, p_username IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN has_role(p_role, p_username) THEN 'Y' ELSE 'N' END;
  END has_role_yn;

  -- ===================================================================
  -- SHIFTS
  -- ===================================================================
  PROCEDURE open_shift (p_lane_id       IN  NUMBER,
                        p_emp_id        IN  NUMBER,
                        p_opening_float IN  NUMBER DEFAULT 0,
                        p_shift_id      OUT NUMBER) IS
    l_now        DATE := bd_now;
    l_hour       PLS_INTEGER := TO_NUMBER(TO_CHAR(l_now, 'HH24'));
    l_code       CHAR(1);
    l_date       DATE;
    l_lane_plaza NUMBER;
    l_lane_act   CHAR(1);
    l_emp_plaza  NUMBER;
    l_emp_act    CHAR(1);
    l_desig      tc_employee.designation%TYPE;
  BEGIN
    BEGIN
      SELECT plaza_id, is_active INTO l_lane_plaza, l_lane_act FROM tc_toll_lane WHERE lane_id = p_lane_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN fail(-20021, 'Lane not found.');
    END;
    IF l_lane_act <> 'Y' THEN
      fail(-20022, 'This lane is closed / inactive.');
    END IF;

    BEGIN
      SELECT plaza_id, is_active, designation INTO l_emp_plaza, l_emp_act, l_desig
        FROM tc_employee WHERE emp_id = p_emp_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN fail(-20023, 'Employee not found.');
    END;
    IF l_emp_act <> 'Y' THEN
      fail(-20024, 'Employee is inactive.');
    END IF;
    IF l_desig <> 'ADMIN' AND l_emp_plaza <> l_lane_plaza THEN
      fail(-20025, 'Employee is not posted at the plaza of this lane.');
    END IF;

    -- Bangladesh 3-shift roster (A 06-14, B 14-22, C 22-06)
    l_code := CASE WHEN l_hour BETWEEN 6 AND 13 THEN 'A'
                   WHEN l_hour BETWEEN 14 AND 21 THEN 'B'
                   ELSE 'C' END;
    l_date := CASE WHEN l_hour < 6 THEN TRUNC(l_now) - 1 ELSE TRUNC(l_now) END;

    INSERT INTO tc_shift (lane_id, emp_id, shift_code, shift_date, opened_at, opening_float, status)
    VALUES (p_lane_id, p_emp_id, l_code, l_date, l_now, NVL(p_opening_float, 0), 'OPEN')
    RETURNING shift_id INTO p_shift_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      raise_application_error(-20020, 'This lane or this employee already has an OPEN shift. Close it first.');
  END open_shift;

  PROCEDURE close_shift (p_shift_id      IN NUMBER,
                         p_declared_cash IN NUMBER,
                         p_closed_by     IN NUMBER   DEFAULT NULL,
                         p_remarks       IN VARCHAR2 DEFAULT NULL) IS
    l_status tc_shift.status%TYPE;
    l_float  tc_shift.opening_float%TYPE;
    l_cash   NUMBER;
  BEGIN
    IF p_declared_cash IS NULL OR p_declared_cash < 0 THEN
      fail(-20026, 'Declared cash amount is required.');
    END IF;
    BEGIN
      SELECT status, opening_float INTO l_status, l_float
        FROM tc_shift WHERE shift_id = p_shift_id FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN fail(-20027, 'Shift not found.');
    END;
    IF l_status <> 'OPEN' THEN
      fail(-20028, 'Shift is already closed.');
    END IF;

    SELECT NVL(SUM(toll_amount), 0)
      INTO l_cash
      FROM tc_toll_txn
     WHERE shift_id = p_shift_id
       AND method_code = 'CASH'
       AND status = 'PAID';

    UPDATE tc_shift
       SET status        = 'CLOSED',
           closed_at     = bd_now,
           declared_cash = p_declared_cash,
           system_cash   = l_cash,
           cash_variance = p_declared_cash - (l_float + l_cash),
           closed_by     = p_closed_by,
           remarks       = p_remarks
     WHERE shift_id = p_shift_id;
  END close_shift;

  -- ===================================================================
  -- TOLL COLLECTION
  -- ===================================================================
  PROCEDURE collect_toll (p_shift_id       IN  NUMBER,
                          p_reg_no         IN  VARCHAR2,
                          p_class_id       IN  NUMBER,
                          p_axle_count     IN  NUMBER   DEFAULT NULL,
                          p_method_code    IN  VARCHAR2 DEFAULT 'CASH',
                          p_payment_ref    IN  VARCHAR2 DEFAULT NULL,
                          p_exemption_code IN  VARCHAR2 DEFAULT NULL,
                          p_exemption_doc  IN  VARCHAR2 DEFAULT NULL,
                          p_txn_id         OUT NUMBER,
                          p_receipt_no     OUT VARCHAR2,
                          p_amount         OUT NUMBER) IS
    l_now         DATE := bd_now;
    l_shift_stat  tc_shift.status%TYPE;
    l_lane_id     tc_toll_lane.lane_id%TYPE;
    l_lane_no     tc_toll_lane.lane_no%TYPE;
    l_lane_type   tc_toll_lane.lane_type%TYPE;
    l_plaza_id    tc_toll_plaza.plaza_id%TYPE;
    l_plaza_code  tc_toll_plaza.plaza_code%TYPE;
    l_reg_no      VARCHAR2(200);
    l_vehicle_id  tc_vehicle.vehicle_id%TYPE;
    l_veh_class   tc_vehicle.class_id%TYPE;
    l_veh_status  tc_vehicle.status%TYPE;
    l_min_axles   tc_vehicle_class.min_axles%TYPE;
    l_axles       NUMBER;
    l_rate_id     NUMBER;
    l_amount      NUMBER;
    l_method      tc_payment_method.method_code%TYPE;
    l_is_mfs      tc_payment_method.is_mfs%TYPE;
    l_m_active    tc_payment_method.is_active%TYPE;
    l_doc_req     tc_exemption_type.doc_required%TYPE;
    l_x_active    tc_exemption_type.is_active%TYPE;
    l_tag_id      tc_etc_tag.tag_id%TYPE;
    l_balance     tc_etc_tag.balance%TYPE;
    l_status      tc_toll_txn.status%TYPE;
  BEGIN
    -- 1. shift / lane / plaza --------------------------------------------
    BEGIN
      SELECT s.status, l.lane_id, l.lane_no, l.lane_type, p.plaza_id, p.plaza_code
        INTO l_shift_stat, l_lane_id, l_lane_no, l_lane_type, l_plaza_id, l_plaza_code
        FROM tc_shift s
        JOIN tc_toll_lane  l ON l.lane_id  = s.lane_id
        JOIN tc_toll_plaza p ON p.plaza_id = l.plaza_id
       WHERE s.shift_id = p_shift_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN fail(-20010, 'Shift not found. Please open a shift first.');
    END;
    IF l_shift_stat <> 'OPEN' THEN
      fail(-20011, 'This shift is already CLOSED. Open a new shift to collect toll.');
    END IF;

    -- 2. vehicle -------------------------------------------------------
    l_reg_no := normalize_reg_no(p_reg_no);
    IF l_reg_no IS NULL THEN
      fail(-20012, 'Vehicle registration (number plate) is required.');
    END IF;
    IF p_class_id IS NULL THEN
      fail(-20013, 'Vehicle class is required.');
    END IF;

    BEGIN
      SELECT vehicle_id, class_id, status
        INTO l_vehicle_id, l_veh_class, l_veh_status
        FROM tc_vehicle
       WHERE reg_no = l_reg_no;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN l_vehicle_id := NULL;   -- unregistered vehicles may still pay cash / MFS
    END;

    -- 3. tariff --------------------------------------------------------
    SELECT min_axles INTO l_min_axles FROM tc_vehicle_class WHERE class_id = p_class_id;
    l_axles   := NVL(p_axle_count, l_min_axles);
    l_rate_id := get_rate_id(l_plaza_id, p_class_id, l_now);
    l_amount  := calc_toll(l_plaza_id, p_class_id, l_axles, l_now);

    -- 4. payment / exemption --------------------------------------------
    IF p_exemption_code IS NOT NULL THEN
      BEGIN
        SELECT doc_required, is_active INTO l_doc_req, l_x_active
          FROM tc_exemption_type WHERE exemption_code = p_exemption_code;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN fail(-20014, 'Unknown exemption category.');
      END;
      IF l_x_active <> 'Y' THEN
        fail(-20014, 'This exemption category is no longer active.');
      END IF;
      IF l_doc_req = 'Y' AND p_exemption_doc IS NULL THEN
        fail(-20015, 'Exemption document / ID reference is required for this category.');
      END IF;
      l_status := 'EXEMPT';
      l_method := NULL;
      l_amount := 0;
    ELSE
      l_method := NVL(p_method_code, 'CASH');
      BEGIN
        SELECT is_mfs, is_active INTO l_is_mfs, l_m_active
          FROM tc_payment_method WHERE method_code = l_method;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN fail(-20016, 'Unknown payment method ' || l_method);
      END;
      IF l_m_active <> 'Y' THEN
        fail(-20016, 'Payment method ' || l_method || ' is not active.');
      END IF;

      IF l_lane_type = 'ETC' AND l_method <> 'ETC' THEN
        fail(-20017, 'This is an ETC-only lane. Direct non-tag vehicles to a manual (MTC/Hybrid) lane.');
      END IF;

      IF l_method = 'ETC' THEN
        IF l_lane_type = 'MTC' THEN
          fail(-20018, 'ETC (RFID) payment is not available in a manual (MTC) lane.');
        END IF;
        IF l_vehicle_id IS NULL THEN
          fail(-20018, 'Vehicle ' || l_reg_no || ' is not registered - ETC payment needs a registered RFID tag.');
        END IF;
        BEGIN
          SELECT tag_id, balance INTO l_tag_id, l_balance
            FROM tc_etc_tag
           WHERE vehicle_id = l_vehicle_id
             AND status = 'ACTIVE'
             FOR UPDATE;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN fail(-20031, 'No ACTIVE RFID tag found for ' || l_reg_no || '.');
        END;
        IF l_balance < l_amount THEN
          log_violation_autonomous(p_shift_id, l_vehicle_id, l_reg_no, 'LOW_ETC_BALANCE',
                                   'Balance ' || fmt_bdt(l_balance) || ' < toll ' || fmt_bdt(l_amount));
          fail(-20032, 'Insufficient ETC balance (' || fmt_bdt(l_balance) || '). Toll is '
                       || fmt_bdt(l_amount) || '. Please collect by cash / MFS.');
        END IF;
        UPDATE tc_etc_tag SET balance = balance - l_amount WHERE tag_id = l_tag_id;
      ELSIF l_is_mfs = 'Y' OR l_method = 'CARD' THEN
        IF p_payment_ref IS NULL THEN
          fail(-20019, 'Transaction ID (TrxID) of the ' || l_method || ' payment is required.');
        END IF;
      END IF;
      l_status := 'PAID';
    END IF;

    -- 5. insert transaction with receipt number -------------------------
    p_txn_id     := tc_toll_txn_seq.NEXTVAL;
    p_receipt_no := l_plaza_code || '-L' || LPAD(l_lane_no, 2, '0') || '-'
                    || TO_CHAR(l_now, 'YYMMDD') || '-' || LPAD(p_txn_id, 7, '0');
    p_amount     := l_amount;

    INSERT INTO tc_toll_txn (txn_id, receipt_no, shift_id, rate_id, vehicle_id, captured_reg_no,
                             axle_count, toll_amount, method_code, tag_id, payment_ref,
                             exemption_code, exemption_doc_ref, txn_time, status)
    VALUES (p_txn_id, p_receipt_no, p_shift_id, l_rate_id, l_vehicle_id, l_reg_no,
            l_axles, l_amount, l_method, l_tag_id, p_payment_ref,
            p_exemption_code, p_exemption_doc, l_now, l_status);

    -- 6. non-blocking violations (same transaction, linked to the receipt)
    IF l_vehicle_id IS NOT NULL AND l_veh_class <> p_class_id THEN
      INSERT INTO tc_violation (shift_id, txn_id, vehicle_id, captured_reg_no, violation_type, detected_at, remarks)
      VALUES (p_shift_id, p_txn_id, l_vehicle_id, l_reg_no, 'CLASS_MISMATCH', l_now,
              'Lane classification differs from BRTA registered class');
    END IF;
    IF l_veh_status = 'BLACKLISTED' THEN
      INSERT INTO tc_violation (shift_id, txn_id, vehicle_id, captured_reg_no, violation_type, detected_at, remarks)
      VALUES (p_shift_id, p_txn_id, l_vehicle_id, l_reg_no, 'BLACKLISTED', l_now,
              'Black-listed vehicle passed the plaza - inform supervisor');
    END IF;
  END collect_toll;

  -- ===================================================================
  -- ETC TAG RECHARGE
  -- ===================================================================
  PROCEDURE recharge_tag (p_tag_id      IN  NUMBER,
                          p_amount      IN  NUMBER,
                          p_method_code IN  VARCHAR2,
                          p_ref         IN  VARCHAR2 DEFAULT NULL,
                          p_recharge_id OUT NUMBER) IS
    l_status tc_etc_tag.status%TYPE;
    l_is_mfs tc_payment_method.is_mfs%TYPE;
  BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
      fail(-20033, 'Recharge amount must be greater than zero.');
    END IF;
    IF p_method_code = 'ETC' THEN
      fail(-20034, 'A tag cannot be recharged from ETC balance.');
    END IF;
    BEGIN
      SELECT status INTO l_status FROM tc_etc_tag WHERE tag_id = p_tag_id FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN fail(-20035, 'RFID tag not found.');
    END;
    IF l_status <> 'ACTIVE' THEN
      fail(-20036, 'Only ACTIVE tags can be recharged (tag status: ' || l_status || ').');
    END IF;
    BEGIN
      SELECT is_mfs INTO l_is_mfs FROM tc_payment_method WHERE method_code = p_method_code;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN fail(-20037, 'Unknown payment method.');
    END;
    IF (l_is_mfs = 'Y' OR p_method_code = 'CARD') AND p_ref IS NULL THEN
      fail(-20038, 'Transaction ID (TrxID) is required for ' || p_method_code || ' recharge.');
    END IF;

    INSERT INTO tc_tag_recharge (tag_id, amount, method_code, provider_txn_ref, recharged_at, recharged_by)
    VALUES (p_tag_id, p_amount, p_method_code, p_ref, bd_now,
            COALESCE(SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER))
    RETURNING recharge_id INTO p_recharge_id;

    UPDATE tc_etc_tag SET balance = balance + p_amount WHERE tag_id = p_tag_id;
  END recharge_tag;

  -- ===================================================================
  -- VOID (supervisor only, open shift only)
  -- ===================================================================
  PROCEDURE void_txn (p_txn_id    IN NUMBER,
                      p_reason    IN VARCHAR2,
                      p_voided_by IN NUMBER) IS
    l_status  tc_toll_txn.status%TYPE;
    l_method  tc_toll_txn.method_code%TYPE;
    l_tag_id  tc_toll_txn.tag_id%TYPE;
    l_amount  tc_toll_txn.toll_amount%TYPE;
    l_shift_s tc_shift.status%TYPE;
    l_desig   tc_employee.designation%TYPE;
  BEGIN
    IF p_reason IS NULL THEN
      fail(-20041, 'A reason is required to void a receipt.');
    END IF;
    BEGIN
      SELECT designation INTO l_desig FROM tc_employee WHERE emp_id = p_voided_by AND is_active = 'Y';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN fail(-20042, 'Voiding employee not found.');
    END;
    IF role_rank(l_desig) < role_rank('SUPERVISOR') THEN
      fail(-20043, 'Only a Supervisor or above can void a toll receipt.');
    END IF;

    BEGIN
      SELECT t.status, t.method_code, t.tag_id, t.toll_amount, s.status
        INTO l_status, l_method, l_tag_id, l_amount, l_shift_s
        FROM tc_toll_txn t
        JOIN tc_shift s ON s.shift_id = t.shift_id
       WHERE t.txn_id = p_txn_id
         FOR UPDATE OF t.status;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN fail(-20044, 'Transaction not found.');
    END;
    IF l_status = 'VOID' THEN
      fail(-20045, 'Transaction is already void.');
    END IF;
    IF l_shift_s <> 'OPEN' THEN
      fail(-20046, 'Shift is closed and reconciled - this receipt can no longer be voided.');
    END IF;

    -- refund RFID balance
    IF l_method = 'ETC' AND l_tag_id IS NOT NULL THEN
      UPDATE tc_etc_tag SET balance = balance + l_amount WHERE tag_id = l_tag_id;
    END IF;

    UPDATE tc_toll_txn
       SET status = 'VOID', void_reason = p_reason, voided_by = p_voided_by
     WHERE txn_id = p_txn_id;
  END void_txn;

END tc_toll_pkg;
/
