-- =====================================================================
--  Bangladesh Toll Collection System (BD-TCS)
--  04_seed_data.sql  -  Master data + 14 days of DEMO transactions
--
--  * 8 divisions and 64 districts of Bangladesh (English + Bangla)
--  * 5 toll plazas operated by Bangladesh Bridge Authority (BBA)
--  * Toll rates as published in news / public guides (see
--    tc_toll_rate.reference_note) - VERIFY with the latest BBA / RHD
--    gazette before using them for anything other than coursework.
--  * People, NIDs, phone numbers and vehicles are FICTIONAL demo data.
--  IMPORTANT: upload this file with "File Character Set = Unicode UTF-8"
-- =====================================================================

-- ---------------------------------------------------------------------
-- Divisions & districts
-- ---------------------------------------------------------------------
INSERT INTO tc_division (division_name, division_name_bn) VALUES ('Dhaka',      'ঢাকা');
INSERT INTO tc_division (division_name, division_name_bn) VALUES ('Chattogram', 'চট্টগ্রাম');
INSERT INTO tc_division (division_name, division_name_bn) VALUES ('Rajshahi',   'রাজশাহী');
INSERT INTO tc_division (division_name, division_name_bn) VALUES ('Khulna',     'খুলনা');
INSERT INTO tc_division (division_name, division_name_bn) VALUES ('Barishal',   'বরিশাল');
INSERT INTO tc_division (division_name, division_name_bn) VALUES ('Sylhet',     'সিলেট');
INSERT INTO tc_division (division_name, division_name_bn) VALUES ('Rangpur',    'রংপুর');
INSERT INTO tc_division (division_name, division_name_bn) VALUES ('Mymensingh', 'ময়মনসিংহ');

DECLARE
  PROCEDURE d (p_div IN VARCHAR2, p_name IN VARCHAR2, p_bn IN VARCHAR2) IS
  BEGIN
    INSERT INTO tc_district (division_id, district_name, district_name_bn)
    SELECT division_id, p_name, p_bn FROM tc_division WHERE division_name = p_div;
  END d;
BEGIN
  -- Dhaka division (13)
  d('Dhaka','Dhaka','ঢাকা');               d('Dhaka','Faridpur','ফরিদপুর');
  d('Dhaka','Gazipur','গাজীপুর');            d('Dhaka','Gopalganj','গোপালগঞ্জ');
  d('Dhaka','Kishoreganj','কিশোরগঞ্জ');      d('Dhaka','Madaripur','মাদারীপুর');
  d('Dhaka','Manikganj','মানিকগঞ্জ');        d('Dhaka','Munshiganj','মুন্সীগঞ্জ');
  d('Dhaka','Narayanganj','নারায়ণগঞ্জ');     d('Dhaka','Narsingdi','নরসিংদী');
  d('Dhaka','Rajbari','রাজবাড়ী');            d('Dhaka','Shariatpur','শরীয়তপুর');
  d('Dhaka','Tangail','টাঙ্গাইল');
  -- Chattogram division (11)
  d('Chattogram','Bandarban','বান্দরবান');    d('Chattogram','Brahmanbaria','ব্রাহ্মণবাড়িয়া');
  d('Chattogram','Chandpur','চাঁদপুর');       d('Chattogram','Chattogram','চট্টগ্রাম');
  d('Chattogram','Cumilla','কুমিল্লা');        d('Chattogram','Cox''s Bazar','কক্সবাজার');
  d('Chattogram','Feni','ফেনী');             d('Chattogram','Khagrachhari','খাগড়াছড়ি');
  d('Chattogram','Lakshmipur','লক্ষ্মীপুর');  d('Chattogram','Noakhali','নোয়াখালী');
  d('Chattogram','Rangamati','রাঙ্গামাটি');
  -- Rajshahi division (8)
  d('Rajshahi','Bogura','বগুড়া');            d('Rajshahi','Joypurhat','জয়পুরহাট');
  d('Rajshahi','Naogaon','নওগাঁ');           d('Rajshahi','Natore','নাটোর');
  d('Rajshahi','Chapainawabganj','চাঁপাইনবাবগঞ্জ'); d('Rajshahi','Pabna','পাবনা');
  d('Rajshahi','Rajshahi','রাজশাহী');        d('Rajshahi','Sirajganj','সিরাজগঞ্জ');
  -- Khulna division (10)
  d('Khulna','Bagerhat','বাগেরহাট');         d('Khulna','Chuadanga','চুয়াডাঙ্গা');
  d('Khulna','Jashore','যশোর');              d('Khulna','Jhenaidah','ঝিনাইদহ');
  d('Khulna','Khulna','খুলনা');              d('Khulna','Kushtia','কুষ্টিয়া');
  d('Khulna','Magura','মাগুরা');             d('Khulna','Meherpur','মেহেরপুর');
  d('Khulna','Narail','নড়াইল');              d('Khulna','Satkhira','সাতক্ষীরা');
  -- Barishal division (6)
  d('Barishal','Barguna','বরগুনা');          d('Barishal','Barishal','বরিশাল');
  d('Barishal','Bhola','ভোলা');              d('Barishal','Jhalokati','ঝালকাঠি');
  d('Barishal','Patuakhali','পটুয়াখালী');     d('Barishal','Pirojpur','পিরোজপুর');
  -- Sylhet division (4)
  d('Sylhet','Habiganj','হবিগঞ্জ');           d('Sylhet','Moulvibazar','মৌলভীবাজার');
  d('Sylhet','Sunamganj','সুনামগঞ্জ');        d('Sylhet','Sylhet','সিলেট');
  -- Rangpur division (8)
  d('Rangpur','Dinajpur','দিনাজপুর');        d('Rangpur','Gaibandha','গাইবান্ধা');
  d('Rangpur','Kurigram','কুড়িগ্রাম');        d('Rangpur','Lalmonirhat','লালমনিরহাট');
  d('Rangpur','Nilphamari','নীলফামারী');      d('Rangpur','Panchagarh','পঞ্চগড়');
  d('Rangpur','Rangpur','রংপুর');            d('Rangpur','Thakurgaon','ঠাকুরগাঁও');
  -- Mymensingh division (4)
  d('Mymensingh','Jamalpur','জামালপুর');      d('Mymensingh','Mymensingh','ময়মনসিংহ');
  d('Mymensingh','Netrokona','নেত্রকোনা');    d('Mymensingh','Sherpur','শেরপুর');
END;
/

-- ---------------------------------------------------------------------
-- Authorities
-- ---------------------------------------------------------------------
INSERT INTO tc_authority (authority_code, authority_name, authority_name_bn, website)
VALUES ('BBA', 'Bangladesh Bridge Authority', 'বাংলাদেশ সেতু কর্তৃপক্ষ', 'https://www.bba.gov.bd');
INSERT INTO tc_authority (authority_code, authority_name, authority_name_bn, website)
VALUES ('RHD', 'Roads and Highways Department', 'সড়ক ও জনপথ অধিদপ্তর', 'https://www.rhd.gov.bd');

-- ---------------------------------------------------------------------
-- Toll plazas
-- ---------------------------------------------------------------------
DECLARE
  PROCEDURE p (p_code IN VARCHAR2, p_name IN VARCHAR2, p_bn IN VARCHAR2, p_type IN VARCHAR2,
               p_loc IN VARCHAR2, p_district IN VARCHAR2, p_auth IN VARCHAR2, p_opened IN DATE) IS
  BEGIN
    INSERT INTO tc_toll_plaza (plaza_code, plaza_name, plaza_name_bn, facility_type, location_desc,
                               district_id, authority_id, opened_on)
    SELECT p_code, p_name, p_bn, p_type, p_loc, d.district_id, a.authority_id, p_opened
      FROM tc_district d, tc_authority a
     WHERE d.district_name = p_district AND a.authority_code = p_auth;
  END p;
BEGIN
  p('PDM-MAWA', 'Padma Bridge Toll Plaza (Mawa)',    'পদ্মা সেতু টোল প্লাজা (মাওয়া)',   'BRIDGE',
    'Mawa, Louhajang', 'Munshiganj', 'BBA', DATE '2022-06-25');
  p('PDM-JANJ', 'Padma Bridge Toll Plaza (Janjira)', 'পদ্মা সেতু টোল প্লাজা (জাজিরা)',  'BRIDGE',
    'Janjira', 'Shariatpur', 'BBA', DATE '2022-06-25');
  p('JMN-EAST', 'Jamuna Bridge Toll Plaza (East)',   'যমুনা সেতু টোল প্লাজা (পূর্ব)',    'BRIDGE',
    'Bhuapur', 'Tangail', 'BBA', DATE '1998-06-23');
  p('KFT',      'Karnaphuli Tunnel Toll Plaza',      'কর্ণফুলী টানেল টোল প্লাজা',        'TUNNEL',
    'Chattogram', 'Chattogram', 'BBA', DATE '2023-10-28');
  p('DEE-AIR',  'Dhaka Elevated Expressway (Airport Entry)', 'ঢাকা এলিভেটেড এক্সপ্রেসওয়ে (বিমানবন্দর প্রবেশ)', 'EXPRESSWAY',
    'Kawla, Airport', 'Dhaka', 'BBA', DATE '2023-09-02');
END;
/

-- ---------------------------------------------------------------------
-- Lanes: 4 per plaza  (1 = MTC, 2 = HYBRID, 3 = ETC, 4 = MTC)
-- ---------------------------------------------------------------------
INSERT INTO tc_toll_lane (plaza_id, lane_no, direction, lane_type)
SELECT pl.plaza_id, ln.lane_no,
       CASE pl.plaza_code
         WHEN 'PDM-MAWA' THEN 'Southbound (Mawa to Janjira)'
         WHEN 'PDM-JANJ' THEN 'Northbound (Janjira to Mawa / Dhaka)'
         WHEN 'JMN-EAST' THEN CASE WHEN ln.lane_no <= 2 THEN 'Westbound (to Sirajganj)' ELSE 'Eastbound (to Tangail / Dhaka)' END
         WHEN 'KFT'      THEN CASE WHEN ln.lane_no <= 2 THEN 'Patenga to Anwara' ELSE 'Anwara to Patenga' END
         ELSE 'Southbound (Airport to Farmgate)'
       END,
       ln.lane_type
  FROM tc_toll_plaza pl
 CROSS JOIN (SELECT 1 lane_no, 'MTC' lane_type FROM dual UNION ALL
             SELECT 2, 'HYBRID' FROM dual UNION ALL
             SELECT 3, 'ETC'    FROM dual UNION ALL
             SELECT 4, 'MTC'    FROM dual) ln;

-- ---------------------------------------------------------------------
-- Vehicle classes (unified list used by BBA plazas)
-- ---------------------------------------------------------------------
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('MC',     'Motorcycle',                         'মোটরসাইকেল',                    'Two-wheeler',                                  2, 2, 1);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('CAR',    'Car / Jeep / SUV',                   'কার / জিপ',                       'Private car, taxi, jeep, SUV',                 2, 2, 2);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('PICKUP', 'Pickup / Light truck',               'পিকআপ',                          'Pickup van, light truck under 1.5 tonnes',    2, 2, 3);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('MICRO',  'Microbus',                           'মাইক্রোবাস',                      'Microbus / ambulance-size vehicle',            2, 2, 4);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('BUS_S',  'Minibus / Coaster (up to 31 seats)', 'মিনিবাস / কোস্টার (৩১ আসন পর্যন্ত)', 'Small bus up to 31 seats',                 2, 2, 5);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('BUS_M',  'Medium bus (32+ seats)',             'মাঝারি বাস (৩২+ আসন)',             'Two-axle bus with 32 or more seats',          2, 2, 6);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('BUS_L',  'Large bus (3-axle)',                 'বড় বাস (৩ এক্সেল)',                'Three-axle coach',                            3, 3, 7);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('TRK_S',  'Small truck (up to 5 tonnes)',       'ছোট ট্রাক (৫ টন পর্যন্ত)',           'Truck with load capacity up to 5 tonnes',     2, 2, 8);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('TRK_M',  'Medium truck (5-8 tonnes)',          'মাঝারি ট্রাক (৫-৮ টন)',              'Truck 5 to 8 tonnes',                         2, 2, 9);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('TRK_L',  'Truck (8-11 tonnes)',                'ট্রাক (৮-১১ টন)',                   'Two-axle truck 8 to 11 tonnes',               2, 2, 10);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('TRK_3A', 'Heavy truck (3-axle)',               'ভারী ট্রাক (৩ এক্সেল)',             'Three-axle heavy truck',                      3, 3, 11);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('TRL_4A', 'Trailer (4-axle)',                   'ট্রেইলার (৪ এক্সেল)',               'Prime mover + trailer, 4 axles',              4, 4, 12);
INSERT INTO tc_vehicle_class (class_code, class_name, class_name_bn, description, min_axles, max_axles, sort_order) VALUES
  ('TRL_XA', 'Trailer (5 or more axles)',          'ট্রেইলার (৫+ এক্সেল)',              'Charged per extra axle above 5',              5, 12, 13);

-- ---------------------------------------------------------------------
-- Toll rates (BDT)
-- ---------------------------------------------------------------------
DECLARE
  PROCEDURE r (p_plaza IN VARCHAR2, p_class IN VARCHAR2, p_amt IN NUMBER, p_extra IN NUMBER,
               p_from IN DATE, p_note IN VARCHAR2) IS
  BEGIN
    INSERT INTO tc_toll_rate (plaza_id, class_id, toll_amount, extra_axle_amount, effective_from, reference_note)
    SELECT p.plaza_id, c.class_id, p_amt, p_extra, p_from, p_note
      FROM tc_toll_plaza p, tc_vehicle_class c
     WHERE p.plaza_code = p_plaza AND c.class_code = p_class;
  END r;

  PROCEDURE padma (p_plaza IN VARCHAR2) IS
    n  VARCHAR2(200) := 'Padma Bridge toll list (Dhaka Tribune, 01-Jul-2022); verify with BBA';
    f  DATE := DATE '2022-06-26';
  BEGIN
    r(p_plaza,'MC',100,0,f,n);       r(p_plaza,'CAR',750,0,f,n);     r(p_plaza,'PICKUP',1200,0,f,n);
    r(p_plaza,'MICRO',1300,0,f,n);   r(p_plaza,'BUS_S',1400,0,f,n);  r(p_plaza,'BUS_M',2000,0,f,n);
    r(p_plaza,'BUS_L',2400,0,f,n);   r(p_plaza,'TRK_S',1600,0,f,n);  r(p_plaza,'TRK_M',2100,0,f,n);
    r(p_plaza,'TRK_L',2800,0,f,'8-11 t row from TollGuru Bangladesh guide (2026); verify with BBA');
    r(p_plaza,'TRK_3A',5500,0,f,n);  r(p_plaza,'TRL_4A',6000,0,f,n);
    r(p_plaza,'TRL_XA',7500,1500,f,'Tk 6,000 (4 axles) + Tk 1,500 per extra axle; verify with BBA');
  END padma;
BEGIN
  padma('PDM-MAWA');
  padma('PDM-JANJ');

  -- Jamuna Bridge
  FOR x IN (SELECT 'MC' c, 50 a, 0 e FROM dual UNION ALL SELECT 'CAR',550,0 FROM dual UNION ALL
            SELECT 'PICKUP',600,0 FROM dual UNION ALL SELECT 'MICRO',600,0 FROM dual UNION ALL
            SELECT 'BUS_S',750,0 FROM dual UNION ALL SELECT 'BUS_M',1000,0 FROM dual UNION ALL
            SELECT 'BUS_L',1000,0 FROM dual UNION ALL SELECT 'TRK_S',1000,0 FROM dual UNION ALL
            SELECT 'TRK_M',1250,0 FROM dual UNION ALL SELECT 'TRK_L',1600,0 FROM dual UNION ALL
            SELECT 'TRK_3A',2000,0 FROM dual UNION ALL SELECT 'TRL_4A',3000,0 FROM dual UNION ALL
            SELECT 'TRL_XA',4000,1000 FROM dual) LOOP
    r('JMN-EAST', x.c, x.a, x.e, DATE '2024-01-01',
      'TollGuru Bangladesh guide (2026); effective date is a demo value - verify with BBA');
  END LOOP;

  -- Karnaphuli Tunnel (motorcycles not permitted -> no MC rate)
  FOR x IN (SELECT 'CAR' c, 200 a, 0 e FROM dual UNION ALL SELECT 'PICKUP',200,0 FROM dual UNION ALL
            SELECT 'MICRO',250,0 FROM dual UNION ALL SELECT 'BUS_S',300,0 FROM dual UNION ALL
            SELECT 'BUS_M',400,0 FROM dual UNION ALL SELECT 'BUS_L',500,0 FROM dual UNION ALL
            SELECT 'TRK_S',400,0 FROM dual UNION ALL SELECT 'TRK_M',500,0 FROM dual UNION ALL
            SELECT 'TRK_L',600,0 FROM dual UNION ALL SELECT 'TRK_3A',800,0 FROM dual UNION ALL
            SELECT 'TRL_4A',1000,0 FROM dual UNION ALL SELECT 'TRL_XA',1200,200 FROM dual) LOOP
    r('KFT', x.c, x.a, x.e, DATE '2023-10-29', 'TollGuru Bangladesh guide (2026); verify with BBA');
  END LOOP;

  -- Dhaka Elevated Expressway: 4 categories (motorcycles / 3-wheelers barred -> no MC rate)
  FOR x IN (SELECT 'CAR' c, 80 a FROM dual UNION ALL SELECT 'PICKUP',80 FROM dual UNION ALL
            SELECT 'MICRO',80 FROM dual UNION ALL SELECT 'BUS_S',160 FROM dual UNION ALL
            SELECT 'BUS_M',160 FROM dual UNION ALL SELECT 'BUS_L',160 FROM dual UNION ALL
            SELECT 'TRK_S',320 FROM dual UNION ALL SELECT 'TRK_M',320 FROM dual UNION ALL
            SELECT 'TRK_L',400 FROM dual UNION ALL SELECT 'TRK_3A',400 FROM dual UNION ALL
            SELECT 'TRL_4A',400 FROM dual UNION ALL SELECT 'TRL_XA',400 FROM dual) LOOP
    r('DEE-AIR', x.c, x.a, 0, DATE '2023-09-03',
      'Category rates announced Aug 2023 (Prothom Alo / BSS): Tk 80 / 160 / 320 / 400');
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- Payment methods & exemption categories
-- ---------------------------------------------------------------------
INSERT INTO tc_payment_method (method_code, method_name, method_name_bn, is_mfs) VALUES ('CASH',   'Cash',                 'নগদ টাকা',           'N');
INSERT INTO tc_payment_method (method_code, method_name, method_name_bn, is_mfs) VALUES ('ETC',    'ETC (RFID tag)',       'ইটিসি (আরএফআইডি ট্যাগ)', 'N');
INSERT INTO tc_payment_method (method_code, method_name, method_name_bn, is_mfs) VALUES ('BKASH',  'bKash',                'বিকাশ',              'Y');
INSERT INTO tc_payment_method (method_code, method_name, method_name_bn, is_mfs) VALUES ('NAGAD',  'Nagad',                'নগদ (মোবাইল ওয়ালেট)',  'Y');
INSERT INTO tc_payment_method (method_code, method_name, method_name_bn, is_mfs) VALUES ('ROCKET', 'Rocket (DBBL)',        'রকেট',               'Y');
INSERT INTO tc_payment_method (method_code, method_name, method_name_bn, is_mfs) VALUES ('CARD',   'Debit / Credit card',  'ব্যাংক কার্ড',         'N');

INSERT INTO tc_exemption_type (exemption_code, description, description_bn, legal_basis, doc_required) VALUES
  ('AMBULANCE',      'Ambulance carrying patient',             'রোগীবাহী অ্যাম্বুলেন্স',              'Emergency vehicle - per plaza authority notice', 'N');
INSERT INTO tc_exemption_type (exemption_code, description, description_bn, legal_basis, doc_required) VALUES
  ('FIRE_SERVICE',   'Fire Service & Civil Defence on duty',   'দায়িত্বরত ফায়ার সার্ভিস',              'Emergency vehicle - per plaza authority notice', 'N');
INSERT INTO tc_exemption_type (exemption_code, description, description_bn, legal_basis, doc_required) VALUES
  ('POLICE_DUTY',    'Law-enforcement vehicle on duty',        'দায়িত্বরত আইনশৃঙ্খলা বাহিনীর যান',     'Emergency / operational vehicle - per plaza authority notice', 'Y');
INSERT INTO tc_exemption_type (exemption_code, description, description_bn, legal_basis, doc_required) VALUES
  ('ARMED_FORCES',   'Armed Forces vehicle on operational duty','দায়িত্বরত সশস্ত্র বাহিনীর যান',        'Operational vehicle - per plaza authority notice', 'Y');
INSERT INTO tc_exemption_type (exemption_code, description, description_bn, legal_basis, doc_required) VALUES
  ('STATE_PROTOCOL', 'State protocol / VVIP motorcade',        'রাষ্ট্রীয় প্রটোকল / ভিভিআইপি বহর',     'As notified by the Government', 'Y');

-- ---------------------------------------------------------------------
-- Employees (fictional). E001 = system ADMIN -> map to YOUR APEX login:
--   UPDATE tc_employee SET apex_username = UPPER('your_apex_login') WHERE emp_code = 'E001';
-- ---------------------------------------------------------------------
DECLARE
  l_n PLS_INTEGER := 0;
  PROCEDURE e (p_code IN VARCHAR2, p_name IN VARCHAR2, p_desig IN VARCHAR2, p_plaza IN VARCHAR2,
               p_mobile IN VARCHAR2, p_user IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    l_n := l_n + 1;
    INSERT INTO tc_employee (emp_code, full_name, nid, mobile, designation, plaza_id, apex_username, joining_date)
    VALUES (p_code, p_name, '46000000' || LPAD(l_n, 2, '0'), p_mobile, p_desig,
            (SELECT plaza_id FROM tc_toll_plaza WHERE plaza_code = p_plaza), p_user,
            ADD_MONTHS(DATE '2023-01-01', l_n));
  END e;
BEGIN
  e('E001','Md. Rafiqul Islam',     'ADMIN',          NULL,       '01711000001');
  e('E002','Shahana Akter',         'PLAZA_MANAGER',  'PDM-MAWA', '01811000002', 'MANAGER1');
  e('E003','Abdul Karim',           'SUPERVISOR',     'PDM-MAWA', '01911000003', 'SUPERVISOR1');
  e('E004','Sumon Mia',             'TOLL_COLLECTOR', 'PDM-MAWA', '01611000004', 'COLLECTOR1');
  e('E005','Nasrin Sultana',        'TOLL_COLLECTOR', 'PDM-MAWA', '01511000005');
  e('E006','Habibur Rahman',        'TOLL_COLLECTOR', 'PDM-MAWA', '01311000006');
  e('E007','Mizanur Rahman',        'SUPERVISOR',     'PDM-JANJ', '01711000007');
  e('E008','Rokeya Begum',          'TOLL_COLLECTOR', 'PDM-JANJ', '01811000008');
  e('E009','Jahid Hasan',           'TOLL_COLLECTOR', 'PDM-JANJ', '01911000009');
  e('E010','Tania Sultana',         'TOLL_COLLECTOR', 'PDM-JANJ', '01411000010');
  e('E011','Anwar Hossain',         'SUPERVISOR',     'JMN-EAST', '01711000011');
  e('E012','Shirin Akter',          'TOLL_COLLECTOR', 'JMN-EAST', '01811000012');
  e('E013','Kamrul Hasan',          'TOLL_COLLECTOR', 'JMN-EAST', '01911000013');
  e('E014','Mahmudul Haque',        'TOLL_COLLECTOR', 'JMN-EAST', '01611000014');
  e('E015','Nurul Alam Chowdhury',  'SUPERVISOR',     'KFT',      '01711000015');
  e('E016','Farzana Yasmin',        'TOLL_COLLECTOR', 'KFT',      '01811000016');
  e('E017','Rashed Khan',           'TOLL_COLLECTOR', 'KFT',      '01911000017');
  e('E018','Sajib Das',             'TOLL_COLLECTOR', 'KFT',      '01511000018');
  e('E019','Tanvir Ahmed',          'SUPERVISOR',     'DEE-AIR',  '01711000019');
  e('E020','Mitu Rani Saha',        'TOLL_COLLECTOR', 'DEE-AIR',  '01811000020');
  e('E021','Arif Hossain',          'TOLL_COLLECTOR', 'DEE-AIR',  '01911000021');
  e('E022','Sabbir Rahman',         'TOLL_COLLECTOR', 'DEE-AIR',  '01311000022');
END;
/

-- ---------------------------------------------------------------------
-- Owners & vehicles (fictional)
-- ---------------------------------------------------------------------
DECLARE
  PROCEDURE o (p_type IN VARCHAR2, p_name IN VARCHAR2, p_nid IN VARCHAR2, p_tl IN VARCHAR2,
               p_mobile IN VARCHAR2, p_addr IN VARCHAR2, p_district IN VARCHAR2) IS
  BEGIN
    INSERT INTO tc_owner (owner_type, full_name, nid, trade_license_no, mobile, address, district_id)
    VALUES (p_type, p_name, p_nid, p_tl, p_mobile, p_addr,
            (SELECT district_id FROM tc_district WHERE district_name = p_district));
  END o;

  PROCEDURE v (p_area IN VARCHAR2, p_letter IN VARCHAR2, p_series IN VARCHAR2, p_no IN VARCHAR2,
               p_class IN VARCHAR2, p_owner IN VARCHAR2, p_model IN VARCHAR2, p_color IN VARCHAR2,
               p_year IN NUMBER, p_status IN VARCHAR2 DEFAULT 'ACTIVE') IS
  BEGIN
    INSERT INTO tc_vehicle (reg_area, reg_letter, reg_series, reg_number, class_id, owner_id,
                            make_model, color, manufacture_year, fitness_expiry, tax_token_expiry, status)
    VALUES (p_area, p_letter, p_series, p_no,
            (SELECT class_id FROM tc_vehicle_class WHERE class_code = p_class),
            (SELECT owner_id FROM tc_owner WHERE full_name = p_owner),
            p_model, p_color, p_year, DATE '2027-06-30', DATE '2027-03-31', p_status);
  END v;
BEGIN
  o('INDIVIDUAL','Md. Abdur Rahim',          '5700000001', NULL, '01712345601', 'House 12, Road 5, Dhanmondi', 'Dhaka');
  o('INDIVIDUAL','Fatema Khatun',            '5700000002', NULL, '01812345602', 'Louhajang Bazar',            'Munshiganj');
  o('INDIVIDUAL','Tanjim Hasan',             '19912694012345673', NULL, '01912345603', 'Agrabad C/A',         'Chattogram');
  o('INDIVIDUAL','Sharmin Nahar',            '5700000004', NULL, '01612345604', 'Sadar Road',                 'Barishal');
  o('INDIVIDUAL','Rakibul Islam',            '5700000005', NULL, '01512345605', 'Station Road',               'Tangail');
  o('INDIVIDUAL','Ayesha Siddika',           '5700000006', NULL, '01312345606', 'Uttara Sector 7',            'Dhaka');
  o('COMPANY',   'Shapla Paribahan Ltd.',    NULL, 'TRAD/DSCC/012345/2023', '01712345607', 'Gabtoli Bus Terminal', 'Dhaka');
  o('COMPANY',   'Meghna Logistics Ltd.',    NULL, 'TRAD/CCC/045678/2022',  '01812345608', 'Port Connecting Road', 'Chattogram');
  o('COMPANY',   'Jamuna Freight Lines',     NULL, 'TRAD/BOG/007788/2021',  '01912345609', 'Banani, Bogura',       'Bogura');
  o('GOVERNMENT','Upazila Health Complex, Louhajang', NULL, NULL, '01712345610', 'Louhajang',             'Munshiganj');

  v('DHAKA METRO','GA','15','4521','CAR',    'Md. Abdur Rahim',  'Toyota Axio',          'White',  2019);
  v('DHAKA METRO','KHA','21','0876','CAR',   'Ayesha Siddika',   'Honda Vezel',          'Silver', 2020);
  v('MUNSHIGANJ','HA','11','2233','MC',      'Fatema Khatun',    'Bajaj Pulsar 150',     'Black',  2021);
  v('CHATTO METRO','GHA','11','7788','CAR',  'Tanjim Hasan',     'Mitsubishi Pajero',    'Grey',   2018);
  v('BARISHAL','CHA','11','0451','MICRO',    'Sharmin Nahar',    'Toyota Hiace',         'White',  2017);
  v('TANGAIL','KA','11','3012','CAR',        'Rakibul Islam',    'Toyota Premio',        'Blue',   2016);
  v('DHAKA METRO','BA','11','9001','BUS_M',  'Shapla Paribahan Ltd.', 'Hino AK1J',       'Green',  2019);
  v('DHAKA METRO','BA','11','9002','BUS_M',  'Shapla Paribahan Ltd.', 'Hino AK1J',       'Green',  2019);
  v('DHAKA METRO','BA','15','1203','BUS_L',  'Shapla Paribahan Ltd.', 'Scania K410',     'Green',  2022);
  v('DHAKA METRO','JA','14','5566','BUS_S',  'Shapla Paribahan Ltd.', 'Toyota Coaster',  'White',  2018);
  v('CHATTO METRO','TA','11','4410','TRK_M', 'Meghna Logistics Ltd.', 'Tata LPT 1109',   'Yellow', 2020);
  v('CHATTO METRO','TA','11','4411','TRK_3A','Meghna Logistics Ltd.', 'Ashok Leyland 2518','Red',   2021);
  v('CHATTO METRO','TA','12','0098','TRL_4A','Meghna Logistics Ltd.', 'Tata Prima 4028',  'Blue',   2022);
  v('BOGURA','TA','11','6120','TRK_S',       'Jamuna Freight Lines',  'Tata Ace',        'White',  2019);
  v('BOGURA','TA','11','6121','TRK_L',       'Jamuna Freight Lines',  'Isuzu FVR',       'Orange', 2018);
  v('BOGURA','NA','11','3344','PICKUP',      'Jamuna Freight Lines',  'Mahindra Bolero Pik-Up', 'White', 2021);
  v('MUNSHIGANJ','CHA','11','0108','MICRO',  'Upazila Health Complex, Louhajang', 'Toyota Hiace Ambulance', 'White', 2020);
  v('DHAKA METRO','GA','19','8888','CAR',    'Md. Abdur Rahim',  'Toyota Land Cruiser Prado', 'Black', 2015, 'BLACKLISTED');
END;
/

-- ---------------------------------------------------------------------
-- RFID (ETC) tags & recharges
-- ---------------------------------------------------------------------
DECLARE
  l_n PLS_INTEGER := 0;
  PROCEDURE t (p_reg IN VARCHAR2, p_bal IN NUMBER, p_status IN VARCHAR2 DEFAULT 'ACTIVE') IS
  BEGIN
    l_n := l_n + 1;
    INSERT INTO tc_etc_tag (tag_uid, vehicle_id, balance, issued_on, status)
    SELECT 'E28068940000500000000' || LPAD(l_n, 3, '0'), vehicle_id, p_bal, DATE '2025-01-15' + l_n * 7, p_status
      FROM tc_vehicle WHERE reg_no = p_reg;
  END t;
BEGIN
  t('DHAKA METRO-GA 15-4521',  4250);
  t('DHAKA METRO-KHA 21-0876', 380);      -- low balance demo
  t('CHATTO METRO-GHA 11-7788',2600);
  t('DHAKA METRO-BA 11-9001',  18500);
  t('DHAKA METRO-BA 11-9002',  1200);
  t('DHAKA METRO-BA 15-1203',  22000);
  t('CHATTO METRO-TA 11-4410', 9800);
  t('CHATTO METRO-TA 12-0098', 35000);
  t('BOGURA-TA 11-6121',       6400);
  t('BARISHAL-CHA 11-0451',    0, 'BLOCKED');
END;
/

INSERT INTO tc_tag_recharge (tag_id, amount, method_code, provider_txn_ref, recharged_at, recharged_by)
SELECT g.tag_id, x.amt, x.mth, x.ref, TRUNC(SYSDATE) - x.ago + 0.45, 'SEED'
  FROM tc_etc_tag g
  JOIN (SELECT 1 n, 5000 amt, 'BKASH' mth, 'BK7H3K2L9Q' ref, 20 ago FROM dual UNION ALL
        SELECT 1, 2000, 'NAGAD',  'NG71530044', 6  FROM dual UNION ALL
        SELECT 3, 3000, 'CASH',   NULL,         12 FROM dual UNION ALL
        SELECT 4, 20000,'CARD',   'POS-883201', 15 FROM dual UNION ALL
        SELECT 6, 25000,'ROCKET', 'RK90021733', 9  FROM dual UNION ALL
        SELECT 8, 40000,'BKASH',  'BK9P2M4X1Z', 4  FROM dual) x
    ON g.tag_uid = 'E28068940000500000000' || LPAD(x.n, 3, '0');

COMMIT;

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

-- ---------------------------------------------------------------------
-- TODAY: open live shifts (lane 1 & 2 of every plaza) and a few live
-- transactions through the real business logic (tc_toll_pkg.collect_toll)
-- ---------------------------------------------------------------------
DECLARE
  l_shift NUMBER;
  l_txn   NUMBER;
  l_rcpt  VARCHAR2(40);
  l_amt   NUMBER;
  l_emp1  NUMBER;
  l_emp2  NUMBER;

  FUNCTION cls (p_code IN VARCHAR2) RETURN NUMBER IS
    l NUMBER;
  BEGIN
    SELECT class_id INTO l FROM tc_vehicle_class WHERE class_code = p_code;
    RETURN l;
  END cls;
BEGIN
  FOR p IN (SELECT plaza_id, plaza_code FROM tc_toll_plaza ORDER BY plaza_id) LOOP
    SELECT MIN(emp_id), MAX(emp_id) INTO l_emp1, l_emp2
      FROM (SELECT emp_id FROM tc_employee
             WHERE plaza_id = p.plaza_id AND designation = 'TOLL_COLLECTOR'
             ORDER BY emp_id FETCH FIRST 2 ROWS ONLY);

    FOR ln IN (SELECT lane_id, lane_no FROM tc_toll_lane
                WHERE plaza_id = p.plaza_id AND lane_no <= 2 ORDER BY lane_no) LOOP
      tc_toll_pkg.open_shift(ln.lane_id, CASE ln.lane_no WHEN 1 THEN l_emp1 ELSE l_emp2 END, 2000, l_shift);

      IF ln.lane_no = 1 THEN
        tc_toll_pkg.collect_toll(l_shift, 'dhaka metro-ga-17-2290', cls('CAR'),   NULL, 'CASH',  NULL, NULL, NULL, l_txn, l_rcpt, l_amt);
        tc_toll_pkg.collect_toll(l_shift, 'FARIDPUR-BA 11-0331',    cls('BUS_M'), NULL, 'BKASH', 'BK8D21XQ5T', NULL, NULL, l_txn, l_rcpt, l_amt);
        tc_toll_pkg.collect_toll(l_shift, 'GAZIPUR-TA 14-7812',     cls('TRK_M'), NULL, 'NAGAD', 'NG55102931', NULL, NULL, l_txn, l_rcpt, l_amt);
        tc_toll_pkg.collect_toll(l_shift, 'MUNSHIGANJ-CHA 11-0108', cls('MICRO'), NULL, NULL,    NULL, 'AMBULANCE', NULL, l_txn, l_rcpt, l_amt);
      ELSE
        tc_toll_pkg.collect_toll(l_shift, 'DHAKA METRO-BA 11-9001', cls('BUS_M'), NULL, 'ETC',   NULL, NULL, NULL, l_txn, l_rcpt, l_amt);
        tc_toll_pkg.collect_toll(l_shift, 'CHATTO METRO-TA 11-4410',cls('TRK_M'), NULL, 'ETC',   NULL, NULL, NULL, l_txn, l_rcpt, l_amt);
        tc_toll_pkg.collect_toll(l_shift, 'TANGAIL-KA 11-3012',     cls('CAR'),   NULL, 'CASH',  NULL, NULL, NULL, l_txn, l_rcpt, l_amt);
      END IF;
    END LOOP;
  END LOOP;
  COMMIT;
END;
/
