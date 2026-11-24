-- Run ONLY if the demo-transaction block failed earlier (PLS-00425).
-- Paste into SQL Workshop > SQL Commands and click Run.
-- ---------------------------------------------------------------------
-- DEMO TRANSACTIONS: 14 days x 5 plazas x 2 lanes x 3 shifts
-- (about 8,000 rows - takes a few seconds)
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_num   IS TABLE OF NUMBER        INDEX BY PLS_INTEGER;
  TYPE t_str   IS TABLE OF VARCHAR2(60)  INDEX BY PLS_INTEGER;
  TYPE t_cls   IS RECORD (class_id NUMBER, min_axles NUMBER, max_axles NUMBER);
  TYPE t_cmap  IS TABLE OF t_cls INDEX BY VARCHAR2(10);

  c_days     CONSTANT PLS_INTEGER := 14;
  l_today    DATE := TRUNC(tc_toll_pkg.bd_now);
  l_areas    t_str;
  l_coll     t_num;
  l_sup      NUMBER;
  l_cls      t_cmap;
  l_tag_id   t_num;  l_tag_veh t_num;  l_tag_reg t_str;  l_tag_cls t_str;
  l_shift_id NUMBER;
  l_open     DATE;
  l_time     DATE;
  l_n        PLS_INTEGER;
  l_r        NUMBER;
  l_code     VARCHAR2(10);
  l_axles    NUMBER;
  l_rate_id  NUMBER;
  l_amount   NUMBER;
  l_method   VARCHAR2(10);
  l_exempt   VARCHAR2(20);
  l_status   VARCHAR2(6);
  l_veh_id   NUMBER;
  l_reg      VARCHAR2(60);
  l_tag      NUMBER;
  l_ref      VARCHAR2(40);
  l_txn_id   NUMBER;
  l_k        PLS_INTEGER;
  l_cash     NUMBER;
  l_var      NUMBER;
  l_emp      NUMBER;
  l_vreg     VARCHAR2(60);

  FUNCTION letter_for (p_class IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE p_class
             WHEN 'MC'     THEN CASE WHEN DBMS_RANDOM.VALUE < 0.5 THEN 'HA' ELSE 'LA' END
             WHEN 'CAR'    THEN CASE TRUNC(DBMS_RANDOM.VALUE(0,3)) WHEN 0 THEN 'KA' WHEN 1 THEN 'KHA' ELSE 'GA' END
             WHEN 'PICKUP' THEN 'NA'
             WHEN 'MICRO'  THEN 'CHA'
             WHEN 'BUS_S'  THEN 'JA'
             WHEN 'BUS_M'  THEN 'BA'
             WHEN 'BUS_L'  THEN 'BA'
             ELSE 'TA'
           END;
  END letter_for;
BEGIN
  DBMS_RANDOM.SEED(2026);

  l_areas(1) := 'DHAKA METRO';  l_areas(2) := 'DHAKA';       l_areas(3) := 'NARAYANGANJ';
  l_areas(4) := 'MUNSHIGANJ';   l_areas(5) := 'SHARIATPUR';  l_areas(6) := 'MADARIPUR';
  l_areas(7) := 'FARIDPUR';     l_areas(8) := 'BARISHAL';    l_areas(9) := 'KHULNA METRO';
  l_areas(10):= 'GOPALGANJ';    l_areas(11):= 'TANGAIL';     l_areas(12):= 'SIRAJGANJ';
  l_areas(13):= 'BOGURA';       l_areas(14):= 'CHATTO METRO';l_areas(15):= 'CUMILLA';
  l_areas(16):= 'GAZIPUR';      l_areas(17):= 'RAJSHAHI METRO';

  FOR c IN (SELECT class_code, class_id, min_axles, max_axles FROM tc_vehicle_class) LOOP
    l_cls(c.class_code).class_id  := c.class_id;
    l_cls(c.class_code).min_axles := c.min_axles;
    l_cls(c.class_code).max_axles := c.max_axles;
  END LOOP;

  SELECT g.tag_id, g.vehicle_id, v.reg_no, c.class_code
    BULK COLLECT INTO l_tag_id, l_tag_veh, l_tag_reg, l_tag_cls
    FROM tc_etc_tag g
    JOIN tc_vehicle v       ON v.vehicle_id = g.vehicle_id
    JOIN tc_vehicle_class c ON c.class_id   = v.class_id
   WHERE g.status = 'ACTIVE';

  FOR p IN (SELECT plaza_id, plaza_code FROM tc_toll_plaza ORDER BY plaza_id) LOOP
    SELECT emp_id BULK COLLECT INTO l_coll
      FROM tc_employee WHERE plaza_id = p.plaza_id AND designation = 'TOLL_COLLECTOR' ORDER BY emp_id;
    SELECT MIN(emp_id) INTO l_sup
      FROM tc_employee WHERE plaza_id = p.plaza_id AND designation = 'SUPERVISOR';

    FOR ln IN (SELECT lane_id, lane_no, lane_type FROM tc_toll_lane
                WHERE plaza_id = p.plaza_id AND lane_no <= 2 ORDER BY lane_no) LOOP
      FOR d IN REVERSE 1 .. c_days LOOP
        FOR s IN 1 .. 3 LOOP
          l_open := l_today - d + (CASE s WHEN 1 THEN 6 WHEN 2 THEN 14 ELSE 22 END) / 24;
          l_emp  := l_coll(MOD(s + ln.lane_no + d, l_coll.COUNT) + 1);   -- computed in PL/SQL, not inside SQL

          INSERT INTO tc_shift (lane_id, emp_id, shift_code, shift_date, opened_at, closed_at,
                                opening_float, declared_cash, status, closed_by)
          VALUES (ln.lane_id, l_emp,
                  CASE s WHEN 1 THEN 'A' WHEN 2 THEN 'B' ELSE 'C' END,
                  l_today - d, l_open, l_open + 8/24, 2000, 0, 'CLOSED', l_sup)
          RETURNING shift_id INTO l_shift_id;

          -- traffic: busier in day shifts and on Thursday / Friday (Bangladesh weekend travel)
          l_n := TRUNC(DBMS_RANDOM.VALUE(14, 30)
                       * CASE s WHEN 3 THEN 0.5 ELSE 1 END
                       * CASE WHEN TO_CHAR(l_today - d, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('THU','FRI')
                              THEN 1.4 ELSE 1 END);

          FOR i IN 1 .. l_n LOOP
            l_time   := l_open + DBMS_RANDOM.VALUE(0, 8/24 - 1/1440);
            l_r      := DBMS_RANDOM.VALUE(0, 100);
            l_veh_id := NULL;
            l_tag    := NULL;
            l_ref    := NULL;
            l_exempt := NULL;
            l_status := 'PAID';

            -- payment method
            IF l_r < 2 THEN
              l_method := NULL;
              l_status := 'EXEMPT';
              l_exempt := CASE TRUNC(DBMS_RANDOM.VALUE(0,3)) WHEN 0 THEN 'AMBULANCE'
                                                             WHEN 1 THEN 'FIRE_SERVICE' ELSE 'POLICE_DUTY' END;
            ELSIF ln.lane_type <> 'MTC' AND l_r < 30 THEN
              l_method := 'ETC';
            ELSIF l_r < 75 THEN l_method := 'CASH';
            ELSIF l_r < 87 THEN l_method := 'BKASH';
            ELSIF l_r < 95 THEN l_method := 'NAGAD';
            ELSIF l_r < 98 THEN l_method := 'ROCKET';
            ELSE                l_method := 'CARD';
            END IF;

            -- vehicle & class
            IF l_method = 'ETC' THEN
              l_k      := TRUNC(DBMS_RANDOM.VALUE(1, l_tag_id.COUNT + 1));
              l_tag    := l_tag_id(l_k);
              l_veh_id := l_tag_veh(l_k);
              l_reg    := l_tag_reg(l_k);
              l_code   := l_tag_cls(l_k);
            ELSE
              l_r := DBMS_RANDOM.VALUE(0, 100);
              l_code := CASE WHEN l_r < 16 THEN 'MC'     WHEN l_r < 44 THEN 'CAR'
                             WHEN l_r < 52 THEN 'PICKUP' WHEN l_r < 62 THEN 'MICRO'
                             WHEN l_r < 67 THEN 'BUS_S'  WHEN l_r < 73 THEN 'BUS_M'
                             WHEN l_r < 78 THEN 'BUS_L'  WHEN l_r < 84 THEN 'TRK_S'
                             WHEN l_r < 89 THEN 'TRK_M'  WHEN l_r < 93 THEN 'TRK_L'
                             WHEN l_r < 96 THEN 'TRK_3A' WHEN l_r < 99 THEN 'TRL_4A'
                             ELSE 'TRL_XA' END;
              IF l_exempt IS NOT NULL THEN
                l_code := 'MICRO';
              END IF;
              -- motorcycles are not allowed in the tunnel / elevated expressway
              IF l_code = 'MC' AND p.plaza_code IN ('KFT','DEE-AIR') THEN
                l_code := 'CAR';
              END IF;
              l_reg := l_areas(TRUNC(DBMS_RANDOM.VALUE(1, l_areas.COUNT + 1))) || '-' || letter_for(l_code) || ' '
                       || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(11, 60))) || '-'
                       || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, 10000)), 4, '0');
            END IF;

            l_axles   := l_cls(l_code).min_axles
                         + CASE WHEN l_code = 'TRL_XA' THEN TRUNC(DBMS_RANDOM.VALUE(0, 2)) ELSE 0 END;
            l_rate_id := tc_toll_pkg.get_rate_id(p.plaza_id, l_cls(l_code).class_id, l_time);
            l_amount  := CASE WHEN l_status = 'EXEMPT' THEN 0
                              ELSE tc_toll_pkg.calc_toll(p.plaza_id, l_cls(l_code).class_id, l_axles, l_time) END;

            IF l_method IN ('BKASH','NAGAD','ROCKET','CARD') THEN
              l_ref := SUBSTR(l_method, 1, 2) || DBMS_RANDOM.STRING('X', 8);
            END IF;

            l_txn_id := tc_toll_txn_seq.NEXTVAL;
            INSERT INTO tc_toll_txn (txn_id, receipt_no, shift_id, rate_id, vehicle_id, captured_reg_no, axle_count,
                                     toll_amount, method_code, tag_id, payment_ref, exemption_code,
                                     exemption_doc_ref, txn_time, status)
            VALUES (l_txn_id,
                    p.plaza_code || '-L' || LPAD(ln.lane_no, 2, '0') || '-' || TO_CHAR(l_time, 'YYMMDD')
                                 || '-' || LPAD(l_txn_id, 7, '0'),
                    l_shift_id, l_rate_id, l_veh_id, l_reg, l_axles, l_amount, l_method, l_tag, l_ref,
                    l_exempt, CASE WHEN l_exempt = 'POLICE_DUTY' THEN 'DUTY-SLIP-' || TRUNC(DBMS_RANDOM.VALUE(1000,9999)) END,
                    l_time, l_status);

            -- occasional toll evasion (barrier jump) recorded by CCTV / ANPR
            IF DBMS_RANDOM.VALUE < 0.006 THEN
              l_vreg := l_areas(TRUNC(DBMS_RANDOM.VALUE(1, l_areas.COUNT + 1))) || '-TA '
                        || TRUNC(DBMS_RANDOM.VALUE(11, 60)) || '-' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, 10000)), 4, '0');
              INSERT INTO tc_violation (shift_id, captured_reg_no, violation_type, detected_at, fine_amount, status, remarks)
              VALUES (l_shift_id, l_vreg,
                      'TOLL_EVASION', l_time + 1/1440, 5000,
                      CASE WHEN d > 7 THEN 'REFERRED' ELSE 'OPEN' END,
                      'Barrier crossed without payment - ANPR capture');
            END IF;
          END LOOP;

          -- shift reconciliation
          SELECT NVL(SUM(toll_amount), 0) INTO l_cash
            FROM tc_toll_txn WHERE shift_id = l_shift_id AND method_code = 'CASH' AND status = 'PAID';
          l_var := CASE WHEN DBMS_RANDOM.VALUE < 0.85 THEN 0 ELSE ROUND(DBMS_RANDOM.VALUE(-300, 60), -1) END;
          UPDATE tc_shift
             SET system_cash = l_cash, declared_cash = 2000 + l_cash + l_var, cash_variance = l_var,
                 remarks = CASE WHEN l_var <> 0 THEN 'Cash variance noted by supervisor' END
           WHERE shift_id = l_shift_id;
        END LOOP;
      END LOOP;
    END LOOP;
  END LOOP;
  COMMIT;
END;
/
