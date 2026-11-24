# BD-TCS: Bangladesh Toll Collection System
## Oracle APEX দিয়ে অ্যাপ বানানোর সম্পূর্ণ গাইড (apex.oracle.com)

এই গাইড ধাপে ধাপে মেনে চললে ডাটাবেস, বিজনেস লজিক আর ডেমো ডাটাসহ একটা পূর্ণাঙ্গ টোল কালেকশন অ্যাপ তৈরি হবে। পুরো ডাটাবেস অংশ (টেবিল, PL/SQL প্যাকেজ, ভিউ, ডাটা) রেডিমেড স্ক্রিপ্ট হিসেবে দেওয়া আছে। আপনাকে শুধু APEX-এ পেজগুলো বানাতে হবে, আর তার সব কোড এই গাইডে দেওয়া আছে।

---

## ০. প্যাকেজে যা আছে

| ফাইল | কাজ |
|---|---|
| `sql/BD_TCS_install_all.sql` | **একটাই ফাইল**: 01 থেকে 04 পর্যন্ত সব একসাথে (সবচেয়ে সহজ উপায়) |
| `sql/00_drop_all.sql` | সব অবজেক্ট মুছে ফেলে, আবার শুরু থেকে ইনস্টল করতে চাইলে |
| `sql/01_tables.sql` | ১৭টি টেবিল, PK/FK/UK/CHECK constraint, index |
| `sql/02_package.sql` | `TC_TOLL_PKG`: টোল হিসাব, শিফট, ETC, রিচার্জ, ভয়েড ইত্যাদি |
| `sql/03_views.sql` | রিপোর্ট আর ড্যাশবোর্ডের ভিউ |
| `sql/04_seed_data.sql` | ৮ বিভাগ, ৬৪ জেলা, ৫টি টোল প্লাজা, রেট, কর্মী, যানবাহন, ১৪ দিনের ডেমো লেনদেন |
| `ERD/BD_TCS_ERD.png / .svg / .pdf` | পূর্ণাঙ্গ Crow's Foot ERD (সব কলাম সহ) |
| `ERD/BD_TCS_ERD_overview.png / .pdf` | শুধু entity আর relationship, প্রেজেন্টেশন স্লাইডের জন্য |

---

## ১. বাংলাদেশ-মানের যা যা আছে (Viva / প্রেজেন্টেশনে বলার পয়েন্ট)

- **টাকা (BDT) আর লাখ-কোটি ফরম্যাট**: `tc_toll_pkg.fmt_bdt(1234567)` থেকে আসে `৳12,34,567.00`
- **বাংলা সংখ্যা**: রসিদে `bn_digits()` দিয়ে ৳৭৫০ আকারে দেখায়
- **BRTA নম্বর প্লেট ফরম্যাট**: `DHAKA METRO-GA 12-3456` (এলাকা-শ্রেণি সিরিজ-নম্বর)। চারটা আলাদা কলামে রাখা হয় আর `reg_no` একটা *virtual column*। ভুল ফরম্যাট দিলে CHECK constraint আটকে দেয়।
- **জাতীয় পরিচয়পত্র (NID)**: শুধু ১০, ১৩ বা ১৭ ডিজিট গ্রহণ করে
- **মোবাইল নম্বর**: BTRC ফরম্যাট `01[3-9]XXXXXXXX`
- **৮ বিভাগ আর ৬৪ জেলা**, ইংরেজি ও বাংলা নামসহ
- **বাস্তব টোল প্লাজা আর রেট**: পদ্মা সেতু (মাওয়া ও জাজিরা), যমুনা সেতু, কর্ণফুলী টানেল, ঢাকা এলিভেটেড এক্সপ্রেসওয়ে (BBA পরিচালিত)
- **যানবাহনের শ্রেণি**: মোটরসাইকেল থেকে ৫+ এক্সেল ট্রেইলার পর্যন্ত ১৩টি, অতিরিক্ত এক্সেলের জন্য বাড়তি চার্জ। টানেল আর এক্সপ্রেসওয়েতে মোটরসাইকেলের রেট নেই, তাই সেখানে মোটরসাইকেল ঢুকতে চাইলে সিস্টেম আটকে দেয়।
- **পেমেন্ট**: নগদ টাকা, **ETC (RFID ট্যাগ)**, **bKash, Nagad, Rocket**, কার্ড। MFS আর কার্ডে TrxID বাধ্যতামূলক।
- **টোল মওকুফ**: অ্যাম্বুলেন্স, ফায়ার সার্ভিস, দায়িত্বরত আইনশৃঙ্খলা বাহিনী ইত্যাদি। এগুলো টেবিলে রাখা, তাই প্রয়োজনমতো বদলানো যায়।
- **৩-শিফট রোস্টার**: A (০৬–১৪), B (১৪–২২), C (২২–০৬), বাংলাদেশ সময় (`Asia/Dhaka`)। প্রতিটি শিফট শেষে ক্যাশ মিলিয়ে দেখা হয় আর পার্থক্য (variance) রেকর্ড হয়।
- **লঙ্ঘন (violation) শনাক্তকরণ**: ETC-তে ব্যালেন্স কম, যানবাহনের শ্রেণি না মেলা, কালো তালিকাভুক্ত গাড়ি, টোল ফাঁকি
- **রোল-ভিত্তিক অ্যাক্সেস**: Toll Collector < Supervisor < Plaza Manager < Admin

> রেট সম্পর্কে নোট: রেটগুলো প্রকাশিত সংবাদ ও পাবলিক গাইড থেকে নেওয়া (Dhaka Tribune ২০২২, Prothom Alo/BSS ২০২৩, TollGuru ২০২৬)। প্রতিটা রেটের সূত্র `tc_toll_rate.reference_note` কলামে লেখা আছে। কোর্সওয়ার্কের বাইরে ব্যবহার করতে হলে BBA-র সর্বশেষ গেজেটের সাথে মিলিয়ে নিন। সব মানুষের নাম, NID আর ফোন নম্বর কাল্পনিক।

---

## ২. Workspace তৈরি (একবারই করতে হবে)

1. **https://apex.oracle.com** এ যান, তারপর **Get Started for Free** → **Request a Free Workspace**।
2. Workspace name দিন (যেমন `BDTOLL_RAFI`), schema name নিজে থেকেই আসবে। Email দিয়ে request করুন।
3. ইমেইলে আসা লিংক থেকে workspace activate করে পাসওয়ার্ড সেট করুন।
4. লগইন: Workspace = `BDTOLL_RAFI`, Username = আপনার ইমেইল/ইউজারনেম।

---

## ৩. ডাটাবেস ইনস্টল (৫ মিনিট)

1. **SQL Workshop → SQL Scripts → Upload**
2. ফাইল: `BD_TCS_install_all.sql`
   - **File Character Set: `Unicode UTF-8`** বেছে নিন। এটা না করলে বাংলা লেখা ভেঙে যাবে।
3. Upload হলে স্ক্রিপ্টের পাশের **▶ Run** চাপুন, তারপর আবার **Run Now**।
4. ফলাফলে **Errors = 0** আসা উচিত (প্রায় ১০০টির মতো statement সফল হবে)। ডেমো ডাটা তৈরিতে ১০–৩০ সেকেন্ড লাগতে পারে।
5. যাচাই করতে **SQL Workshop → SQL Commands**-এ চালান:

```sql
select (select count(*) from tc_district)  districts,     -- 64
       (select count(*) from tc_toll_plaza) plazas,       -- 5
       (select count(*) from tc_toll_txn)   transactions, -- ~8000-9000
       (select count(*) from tc_shift where status='OPEN') open_shifts -- 10
  from dual;
```

6. **নিজেকে Admin বানান**। এটা জরুরি, না করলে অ্যাপের মেনু দেখা যাবে না। নিচে আপনার APEX লগইন নাম বসান:

```sql
update tc_employee set apex_username = upper('your_apex_login') where emp_code = 'E001';
commit;
```

7. (ঐচ্ছিক, ডেমোর জন্য ভালো) **Administration (ডানে উপরে ব্যক্তি আইকন) → Manage Users and Groups → Create User** দিয়ে তিনজন ইউজার বানান: `COLLECTOR1`, `SUPERVISOR1`, `MANAGER1`। এরা আগে থেকেই কর্মী টেবিলে ম্যাপ করা আছে (সুমন মিয়া, আব্দুল করিম, শাহানা আক্তার; সবাই পদ্মা মাওয়া প্লাজার)। প্রেজেন্টেশনে আলাদা লগইন দিয়ে রোল-ভিত্তিক মেনু দেখাতে পারবেন।

> আবার শুরু থেকে করতে চাইলে প্রথমে `00_drop_all.sql` রান করুন, তারপর আবার install।

---

## ৪. অ্যাপ্লিকেশন তৈরি (Create App Wizard)

**App Builder → Create → New Application**

- **Name:** `BD Toll Collection System`
- **Appearance:** Theme Style **Vita**, Navigation **Side Menu**
- **Pages → Add Page**, নিচের পেজগুলো যোগ করুন:

| # | Page type | Page name | Source |
|---|---|---|---|
| 1 | Dashboard | Dashboard | (পরে কাস্টমাইজ করব) |
| 2 | Blank | Toll Booth | – |
| 3 | Blank | Toll Receipt | – |
| 4 | Interactive Report | Shifts | View `TC_V_SHIFT_SUMMARY` |
| 7 | Interactive Report | Transactions | View `TC_V_TXN` |
| – | Interactive Report + **Include Form** | Vehicles | Table `TC_VEHICLE` |
| – | Interactive Report + **Include Form** | Vehicle Owners | Table `TC_OWNER` |
| – | Interactive Report + **Include Form** | RFID Tags | Table `TC_ETC_TAG` |
| – | Interactive Report + **Include Form** | Violations | Table `TC_VIOLATION` |
| – | Interactive Report + **Include Form** | Employees | Table `TC_EMPLOYEE` |
| – | Interactive Grid (editable) | Toll Plazas | `TC_TOLL_PLAZA` |
| – | Interactive Grid (editable) | Toll Lanes | `TC_TOLL_LANE` |
| – | Interactive Grid (editable) | Vehicle Classes | `TC_VEHICLE_CLASS` |
| – | Interactive Grid (editable) | Toll Rates | `TC_TOLL_RATE` |
| – | Interactive Grid (editable) | Payment Methods | `TC_PAYMENT_METHOD` |
| – | Interactive Grid (editable) | Exemption Types | `TC_EXEMPTION_TYPE` |
| – | Interactive Report | Daily Revenue | View `TC_V_DAILY_REVENUE` |
| – | Classic Report | Tariff Board | View `TC_V_CURRENT_TARIFF` |

- **Features:** ✔ About Page, ✔ Theme Style Selection। (*Access Control* টিক দেবেন **না**, কারণ আমরা নিজস্ব রোল ব্যবহার করছি)
- **Settings → Authentication:** Oracle APEX Accounts
- **Create Application** চাপুন।

> পেজ নম্বর উইজার্ড নিজে দেবে। এই গাইডে Toll Booth = Page 2, Receipt = Page 3 ধরা হয়েছে। আপনার নম্বর আলাদা হলে কোডে `P2_`/`P3_` সেই অনুযায়ী বদলে নিন।

---

## ৫. Shared Components

### ৫.১ Application Item আর লগইনের সময় কর্মী শনাক্ত করা
**Shared Components → Application Items → Create:** Name `G_EMP_ID`, Session State Protection: *Restricted - May not be set from browser*

**Shared Components → Application Processes → Create:**
- Name: `Set Employee`, Point: **On New Instance (new session)**
- Code:
```sql
:G_EMP_ID := tc_toll_pkg.current_emp_id;
```

### ৫.২ Authorization Schemes (৪টি)
**Shared Components → Authorization Schemes → Create → From Scratch**, Type: **PL/SQL Function Returning Boolean**, Validate: *Once per session*

| Name | Code | Error message |
|---|---|---|
| `IS_COLLECTOR` | `return tc_toll_pkg.has_role('TOLL_COLLECTOR');` | Toll collectors only |
| `IS_SUPERVISOR` | `return tc_toll_pkg.has_role('SUPERVISOR');` | Supervisor or above only |
| `IS_MANAGER` | `return tc_toll_pkg.has_role('PLAZA_MANAGER');` | Plaza manager or above only |
| `IS_ADMIN` | `return tc_toll_pkg.has_role('ADMIN');` | Administrators only |

### ৫.৩ List of Values (LOV)
**Shared Components → List of Values → Create → From Scratch → Dynamic (SQL Query)**

`LOV_VEHICLE_CLASS`
```sql
select class_name || ' / ' || class_name_bn d, class_id r
  from tc_vehicle_class order by sort_order
```
`LOV_PAYMENT_METHOD`
```sql
select method_name || ' (' || method_name_bn || ')' d, method_code r
  from tc_payment_method where is_active = 'Y'
 order by decode(method_code,'CASH',1,'ETC',2,'BKASH',3,'NAGAD',4,'ROCKET',5,6)
```
`LOV_EXEMPTION`
```sql
select description || ' / ' || description_bn d, exemption_code r
  from tc_exemption_type where is_active = 'Y' order by 1
```
`LOV_PLAZA`
```sql
select plaza_name || ' (' || plaza_code || ')' d, plaza_id r from tc_toll_plaza order by 1
```
`LOV_LANE`
```sql
select p.plaza_code || ' - Lane ' || l.lane_no || ' (' || l.lane_type || ', ' || l.direction || ')' d, l.lane_id r
  from tc_toll_lane l join tc_toll_plaza p on p.plaza_id = l.plaza_id
 where l.is_active = 'Y' order by p.plaza_code, l.lane_no
```
`LOV_DISTRICT`
```sql
select d.district_name || ' / ' || d.district_name_bn || ' (' || v.division_name || ')' d, d.district_id r
  from tc_district d join tc_division v on v.division_id = d.division_id order by d.district_name
```
`LOV_OWNER`
```sql
select full_name || ' - ' || mobile d, owner_id r from tc_owner order by full_name
```
`LOV_EMPLOYEE`
```sql
select e.emp_code || ' - ' || e.full_name || ' (' || initcap(replace(e.designation,'_',' ')) || ')' d, e.emp_id r
  from tc_employee e where e.is_active = 'Y' order by e.emp_code
```
`LOV_VEHICLE`
```sql
select reg_no d, vehicle_id r from tc_vehicle order by reg_no
```

---

## ৬. Page 1: Dashboard

Wizard যে ডিফল্ট চার্টগুলো দিয়েছে সেগুলো মুছে দিয়ে নিচের region-গুলো যোগ করুন (Page Designer → Body → Create Region)।

### ৬.১ KPI Cards
- Region type **Cards**, Source SQL:
```sql
select 'Today''s Revenue / আজকের আদায়' title,
       tc_toll_pkg.fmt_bdt(nvl(sum(case when status = 'PAID' then toll_amount end), 0)) value,
       'fa-money' icon, 1 seq
  from tc_v_txn where txn_date = trunc(tc_toll_pkg.bd_now)
union all
select 'Vehicles Today / আজকের যানবাহন', to_char(count(*)), 'fa-car', 2
  from tc_v_txn where txn_date = trunc(tc_toll_pkg.bd_now) and status <> 'VOID'
union all
select 'Open Shifts / চলমান শিফট', to_char(count(*)), 'fa-clock-o', 3
  from tc_shift where status = 'OPEN'
union all
select 'Open Violations / অমীমাংসিত লঙ্ঘন', to_char(count(*)), 'fa-exclamation-triangle', 4
  from tc_violation where status = 'OPEN'
order by seq
```
- Attributes: Title column = `TITLE`, Body = `VALUE` (Advanced Formatting চালু করে `<span style="font-size:1.8rem;font-weight:700">&VALUE.</span>` দিন), Icon = `ICON`, Layout = 4 columns।

### ৬.২ Line chart: গত ১৪ দিনের আয়
- Region type **Chart**, Type **Line**। Series SQL:
```sql
select txn_date, plaza_code, sum(revenue) revenue
  from tc_v_daily_revenue
 where txn_date >= trunc(tc_toll_pkg.bd_now) - 14
 group by txn_date, plaza_code
 order by txn_date
```
- Column Mapping: **Series Name** = `PLAZA_CODE`, Label = `TXN_DATE`, Value = `REVENUE`
- Y-Axis Title: `Revenue (BDT)`, Format: Decimal

### ৬.৩ Donut chart: পেমেন্ট পদ্ধতি অনুযায়ী আয় (৩০ দিন)
```sql
select nvl(method_name, 'Exempt') label, sum(toll_amount) value
  from tc_v_txn
 where txn_date >= trunc(tc_toll_pkg.bd_now) - 30 and status = 'PAID'
 group by method_name order by 2 desc
```

### ৬.৪ Bar chart: যানবাহনের শ্রেণি অনুযায়ী সংখ্যা (৭ দিন)
```sql
select class_name label, sum(vehicle_count) value
  from tc_v_daily_revenue
 where txn_date >= trunc(tc_toll_pkg.bd_now) - 7
 group by class_name order by 2 desc
```
Orientation: Horizontal।

### ৬.৫ Bar chart: প্লাজা অনুযায়ী আয় (৭ দিন)
```sql
select plaza_name label, sum(revenue) value
  from tc_v_daily_revenue
 where txn_date >= trunc(tc_toll_pkg.bd_now) - 7
 group by plaza_name order by 2 desc
```

---

## ৭. Page 2: Toll Booth (অ্যাপের মূল পেজ)

Page properties: **Authorization Scheme = `IS_COLLECTOR`**, Title `Toll Booth / টোল বুথ`।

### ৭.১ Region আর Items
একটা **Static Content** region বানান, নাম দিন `Collect Toll`। তার ভেতরে এই items:

| Item | Type | সেটিংস |
|---|---|---|
| `P2_SHIFT_ID` | Select List | Label *Shift / Lane*; LOV SQL নিচে দেওয়া; Display Null = No |
| `P2_REG_NO` | Text Field | Label *Number Plate*; Placeholder `DHAKA METRO-GA 12-3456`; Text Case **Upper**; Value Required **Yes** |
| `P2_VEHICLE_INFO` | Display Only | Label *Vehicle Info* |
| `P2_CLASS_ID` | Select List | LOV `LOV_VEHICLE_CLASS`; Value Required **Yes** |
| `P2_AXLE_COUNT` | Number Field | Label *Axles (trailer only)*; Min 2, Max 12 |
| `P2_EXEMPTION_CODE` | Select List | LOV `LOV_EXEMPTION`; Null Display `-- No exemption --` |
| `P2_EXEMPTION_DOC` | Text Field | Label *Exemption Doc / ID* |
| `P2_METHOD_CODE` | Radio Group | LOV `LOV_PAYMENT_METHOD`; Default **CASH**; Columns 3 |
| `P2_PAYMENT_REF` | Text Field | Label *TrxID (bKash/Nagad/Rocket/Card)* |
| `P2_TOLL_DISPLAY` | Display Only | Label *Toll Payable*; Template *Optional - Above*; Custom Attributes: `style="font-size:2rem;font-weight:700;color:#2F855A"` |
| `P2_TXN_ID`, `P2_RECEIPT_NO` | Hidden | Value Protected = No |

`P2_SHIFT_ID` LOV (SQL Query). কালেক্টর শুধু নিজের শিফট দেখবে, সুপারভাইজার আর তার উপরের সবাই সব শিফট দেখবে:
```sql
select p.plaza_code || ' | Lane ' || l.lane_no || ' (' || l.lane_type || ') | '
       || e.full_name || ' | Shift ' || s.shift_code d,
       s.shift_id r
  from tc_shift s
  join tc_toll_lane  l on l.lane_id  = s.lane_id
  join tc_toll_plaza p on p.plaza_id = l.plaza_id
  join tc_employee   e on e.emp_id   = s.emp_id
 where s.status = 'OPEN'
   and (s.emp_id = :G_EMP_ID or tc_toll_pkg.has_role_yn('SUPERVISOR') = 'Y')
 order by 1
```

### ৭.২ Dynamic Actions

**DA-1 "Look up vehicle"**: Event *Change*, Item `P2_REG_NO`
- True Action 1: **Execute Server-side Code**. Items to Submit `P2_REG_NO`, Items to Return `P2_REG_NO,P2_VEHICLE_INFO,P2_CLASS_ID`
```sql
declare
  l_reg varchar2(100) := tc_toll_pkg.normalize_reg_no(:P2_REG_NO);
begin
  :P2_REG_NO := l_reg;
  select v.reg_no || ' | ' || c.class_name || ' | Owner: ' || o.full_name
         || ' | Status: ' || v.status
         || nvl((select ' | RFID balance: ' || tc_toll_pkg.fmt_bdt(g.balance)
                   from tc_etc_tag g
                  where g.vehicle_id = v.vehicle_id and g.status = 'ACTIVE'), ' | No RFID tag'),
         v.class_id
    into :P2_VEHICLE_INFO, :P2_CLASS_ID
    from tc_vehicle v
    join tc_vehicle_class c on c.class_id = v.class_id
    join tc_owner o on o.owner_id = v.owner_id
   where v.reg_no = l_reg;
exception
  when no_data_found then
    :P2_VEHICLE_INFO := 'Not registered in BD-TCS - cash / MFS only';
end;
```
- True Action 2: **Execute JavaScript Code**: `apex.event.trigger('#P2_CLASS_ID', 'change');`

**DA-2 "Calculate toll"**: Event *Change*, Items `P2_SHIFT_ID,P2_CLASS_ID,P2_AXLE_COUNT,P2_EXEMPTION_CODE`
- True Action: **Execute Server-side Code**. Items to Submit: ওই ৪টি item, Items to Return `P2_TOLL_DISPLAY`
```sql
begin
  if :P2_EXEMPTION_CODE is not null then
    :P2_TOLL_DISPLAY := tc_toll_pkg.fmt_bdt(0) || '  (EXEMPT / মওকুফ)';
  elsif :P2_SHIFT_ID is not null and :P2_CLASS_ID is not null then
    :P2_TOLL_DISPLAY := tc_toll_pkg.fmt_bdt(
        tc_toll_pkg.calc_toll(tc_toll_pkg.shift_plaza_id(:P2_SHIFT_ID),
                              :P2_CLASS_ID, :P2_AXLE_COUNT));
  else
    :P2_TOLL_DISPLAY := null;
  end if;
exception
  when others then
    :P2_TOLL_DISPLAY := 'Not permitted: ' || regexp_replace(sqlerrm, '^ORA-[0-9]+: ');
end;
```

**DA-3 "Show TrxID"**: Event *Change*, Item `P2_METHOD_CODE`, Client-side Condition *Item is in list* `BKASH,NAGAD,ROCKET,CARD`
- True: **Show** `P2_PAYMENT_REF`; False: **Hide** `P2_PAYMENT_REF`. দুটোতেই *Fire on Initialization* = Yes।

**DA-4 "Exemption toggles payment"**: Event *Change*, Item `P2_EXEMPTION_CODE`, Client-side Condition *Item is not null*
- True: **Show** `P2_EXEMPTION_DOC`, **Hide** `P2_METHOD_CODE,P2_PAYMENT_REF`
- False: **Hide** `P2_EXEMPTION_DOC`, **Show** `P2_METHOD_CODE`। দুটোতেই *Fire on Initialization* = Yes।

### ৭.৩ Button, Process, Branch
- Button **`COLLECT`**: Label `Collect Toll / টোল আদায়`, Hot, Size Large, Action *Submit Page*
- **Processing → Process** `Collect toll`, Type *Execute Code*, When Button Pressed `COLLECT`:
```sql
declare
  l_txn  number;
  l_rcpt varchar2(40);
  l_amt  number;
begin
  tc_toll_pkg.collect_toll(
      p_shift_id       => :P2_SHIFT_ID,
      p_reg_no         => :P2_REG_NO,
      p_class_id       => :P2_CLASS_ID,
      p_axle_count     => :P2_AXLE_COUNT,
      p_method_code    => case when :P2_EXEMPTION_CODE is null then :P2_METHOD_CODE end,
      p_payment_ref    => :P2_PAYMENT_REF,
      p_exemption_code => :P2_EXEMPTION_CODE,
      p_exemption_doc  => :P2_EXEMPTION_DOC,
      p_txn_id         => l_txn,
      p_receipt_no     => l_rcpt,
      p_amount         => l_amt);
  :P2_TXN_ID     := l_txn;
  :P2_RECEIPT_NO := l_rcpt;
end;
```
  - Success Message: `Toll collected. Receipt: &P2_RECEIPT_NO.`
- **After Processing → Branch** to Page **3**। Set Items: `P3_TXN_ID` = `&P2_TXN_ID.`, Clear Cache: `3`

> Validation আলাদা করে লাগবে না। সব নিয়ম (শিফট খোলা কিনা, ETC ব্যালেন্স, TrxID, মোটরসাইকেলের অনুমতি ইত্যাদি) প্যাকেজ চেক করে, আর `raise_application_error` এর মেসেজ APEX নিজেই পেজে দেখায়।

---

## ৮. Page 3: Toll Receipt (টোল রসিদ)

Items: `P3_TXN_ID` (Hidden), `P3_SHIFT_ID` (Hidden)।
- **Pre-Rendering → Computation** `P3_SHIFT_ID`, Type SQL Query: `select shift_id from tc_toll_txn where txn_id = :P3_TXN_ID`

Region type **Dynamic Content** (APEX 22.2+। পুরনো ভার্সনে *PL/SQL Dynamic Content*), Language PL/SQL, *Function Body returning CLOB*:
```sql
declare
  r tc_v_txn%rowtype;
  function row_ (p_label varchar2, p_value varchar2) return varchar2 is
  begin
    return '<tr><td>' || p_label || '</td><td><b>' || apex_escape.html(p_value) || '</b></td></tr>';
  end;
begin
  select * into r from tc_v_txn where txn_id = :P3_TXN_ID;
  return '<div class="tc-receipt">'
      || '<div class="tc-head">' || apex_escape.html(r.authority_code) || ' | '
      ||   apex_escape.html(r.plaza_name_bn) || '<br><small>' || apex_escape.html(r.plaza_name) || '</small></div>'
      || '<h3>টোল রসিদ / TOLL RECEIPT</h3><table>'
      || row_('Receipt No',            r.receipt_no)
      || row_('তারিখ ও সময় / Date',     to_char(r.txn_time, 'DD-Mon-YYYY HH:MI AM'))
      || row_('লেন / Lane',             r.lane_no || ' (' || r.lane_type || ')')
      || row_('গাড়ির নম্বর / Plate',     r.captured_reg_no)
      || row_('শ্রেণি / Class',          r.class_name_bn || ' - ' || r.class_name)
      || row_('এক্সেল / Axles',          r.axle_count)
      || row_('পরিশোধ / Payment',       nvl(r.method_name, 'EXEMPT: ' || r.exemption_desc)
                                        || case when r.payment_ref is not null then ' (' || r.payment_ref || ')' end)
      || row_('আদায়কারী / Collector',   r.collector_name)
      || '</table><div class="tc-amount">'
      || tc_toll_pkg.bn_digits(tc_toll_pkg.fmt_bdt(r.toll_amount))
      || '<br><small>' || r.toll_amount_bdt || '</small></div>'
      || '<p class="tc-foot">শুভ যাত্রা! Have a safe journey.</p></div>';
end;
```

Page → **CSS → Inline**:
```css
.tc-receipt{max-width:380px;margin:auto;border:2px dashed #555;padding:16px;font-family:monospace;background:#fff}
.tc-head{text-align:center;font-weight:700;font-size:1.1rem}
.tc-receipt h3{text-align:center;margin:8px 0;border-top:1px solid #999;border-bottom:1px solid #999}
.tc-receipt table{width:100%}.tc-receipt td{padding:3px 0;vertical-align:top}
.tc-amount{text-align:center;font-size:2.2rem;font-weight:800;margin:10px 0}
.tc-foot{text-align:center}
@media print{.t-Header,.t-Body-nav,.t-Footer,.t-Button,.t-Breadcrumb{display:none!important}}
```
Buttons:
- `PRINT`: Action *Defined by Dynamic Action*, DA → Execute JavaScript `window.print();`
- `NEXT`: Label `Next Vehicle / পরের গাড়ি`, Action *Redirect to Page 2*, Set Items `P2_SHIFT_ID` = `&P3_SHIFT_ID.`, Clear Cache `2`

---

## ৯. Shift Management (Page 4, 5, 6)

**Page 4 – Shifts (IR on `TC_V_SHIFT_SUMMARY`)**: Authorization `IS_COLLECTOR`
- Default sort: `OPENED_AT desc`। Actions → Format → Highlight দিয়ে `CASH_VARIANCE < 0` row লাল করুন।
- Button `OPEN_SHIFT`, Redirect to Page 5।
- নতুন column link: Link text `Close`, Target Page 6, `P6_SHIFT_ID = #SHIFT_ID#`। এটা শুধু `STATUS = 'OPEN'` row-তে দেখাতে চাইলে HTML Expression ব্যবহার করুন।

**Page 5 – Open Shift (Modal Dialog)**
- Items: `P5_LANE_ID` (Select List, `LOV_LANE`), `P5_EMP_ID` (Select List, `LOV_EMPLOYEE`, Default PL/SQL Expression `:G_EMP_ID`), `P5_OPENING_FLOAT` (Number, Default `2000`)
- Button `OPEN` (Submit), Process:
```sql
declare l_id number;
begin
  tc_toll_pkg.open_shift(:P5_LANE_ID, :P5_EMP_ID, :P5_OPENING_FLOAT, l_id);
end;
```
- Process **Close Dialog** (After Submit)

**Page 6 – Close Shift (Modal Dialog)**: Authorization `IS_SUPERVISOR`
- Items: `P6_SHIFT_ID` (Hidden), `P6_EXPECTED` (Display Only), `P6_DECLARED_CASH` (Number, Required), `P6_REMARKS` (Textarea)
- `P6_EXPECTED` Source, SQL Query:
```sql
select 'Opening float ' || tc_toll_pkg.fmt_bdt(s.opening_float)
       || ' + cash collected ' || tc_toll_pkg.fmt_bdt(nvl(sum(t.toll_amount),0))
       || ' = expected in drawer ' || tc_toll_pkg.fmt_bdt(s.opening_float + nvl(sum(t.toll_amount),0))
  from tc_shift s
  left join tc_toll_txn t on t.shift_id = s.shift_id and t.method_code = 'CASH' and t.status = 'PAID'
 where s.shift_id = :P6_SHIFT_ID
 group by s.opening_float
```
- Button `CLOSE_SHIFT` (Submit), Process:
```sql
tc_toll_pkg.close_shift(:P6_SHIFT_ID, :P6_DECLARED_CASH, :G_EMP_ID, :P6_REMARKS);
```
- Process **Close Dialog**

---

## ১০. Transactions (Page 7) আর Void (Page 8)

**Page 7 – IR on `TC_V_TXN`**
- যে কলামগুলো দেখাবেন: `RECEIPT_NO, TXN_TIME, PLAZA_CODE, LANE_NO, CAPTURED_REG_NO, CLASS_NAME, TOLL_AMOUNT_BDT, METHOD_NAME, PAYMENT_REF, EXEMPTION_DESC, STATUS, COLLECTOR_NAME`। বাকিগুলো hide করুন।
- Highlight: `STATUS = 'VOID'` হলে লাল, `'EXEMPT'` হলে হলুদ।
- `RECEIPT_NO` column-কে Link বানান: Page 3, `P3_TXN_ID = #TXN_ID#` (রসিদ আবার প্রিন্ট করা যাবে)।
- আরেকটা link column `Void`, Target Page 8, `P8_TXN_ID = #TXN_ID#`, Authorization `IS_SUPERVISOR`।

**Page 8 – Void Receipt (Modal)**: Authorization `IS_SUPERVISOR`
- Items `P8_TXN_ID` (Display Only), `P8_REASON` (Textarea, Required)
- Process:
```sql
tc_toll_pkg.void_txn(:P8_TXN_ID, :P8_REASON, :G_EMP_ID);
```
  তারপর Close Dialog। ETC ট্রানজেকশন void করলে ট্যাগে টাকা নিজে থেকেই ফেরত যায়।

---

## ১১. Vehicles, Owners, RFID Tags (Wizard-এর Form পেজ ঠিক করা)

**Vehicle Form**
- `Pxx_REG_NO`: **Query Only = Yes**, Read Only (এটা virtual column)
- `Pxx_REG_AREA`: Help text `e.g. DHAKA METRO, CHATTO METRO, MUNSHIGANJ`। Text Case Upper।
- `Pxx_REG_LETTER`: Select List, Static Values: `KA,KHA,GA,GHA,CHA,JA,TA,NA,BA,HA,LA,DA,MA`
- `Pxx_CLASS_ID`: Select List, `LOV_VEHICLE_CLASS`। `Pxx_OWNER_ID`: Popup LOV, `LOV_OWNER`
- `Pxx_STATUS`: Select List, Static Values `ACTIVE,BLACKLISTED,INACTIVE`

**Owner Form**: `DISTRICT_ID` হবে Popup LOV (`LOV_DISTRICT`), `OWNER_TYPE` Select List (`INDIVIDUAL,COMPANY,GOVERNMENT`)। NID বা মোবাইল ভুল ফরম্যাটে দিলে CHECK constraint error দেখাবে। চাইলে item-এ Validation যোগ করুন: *Item matches Regular Expression* `^01[3-9][0-9]{8}$`।

**RFID Tags**: Wizard যে Report বানিয়েছে, তার Source বদলে `TC_V_TAG_BALANCE` view দিন (ব্যালেন্স, মালিক, Low-balance flag দেখাবে)। Form-এ `VEHICLE_ID` Popup LOV (`LOV_VEHICLE`), `STATUS` Select List (`ACTIVE,BLOCKED,LOST,EXPIRED`)।

**Recharge পেজ (নতুন Modal Page)**: Items `P_TAG_ID` (Popup LOV: `select reg_no || ' - ' || tag_uid d, tag_id r from tc_v_tag_balance where status='ACTIVE'`), `P_AMOUNT`, `P_METHOD` (Select List, SQL: `select method_name d, method_code r from tc_payment_method where is_active='Y' and method_code <> 'ETC'`), `P_REF`। Process:
```sql
declare l_id number;
begin
  tc_toll_pkg.recharge_tag(:P_TAG_ID, :P_AMOUNT, :P_METHOD, :P_REF, l_id);
end;
```
(`P_`-এর জায়গায় আপনার পেজ নম্বর বসান, যেমন `P20_TAG_ID`)

---

## ১২. Admin পেজ আর Navigation

- Interactive Grid পেজগুলোতে (Plazas, Lanes, Classes, Rates, Payment Methods, Exemptions) FK column-গুলো Select List/Popup LOV বানান: Rate grid-এ `PLAZA_ID` → `LOV_PLAZA`, `CLASS_ID` → `LOV_VEHICLE_CLASS`; Lane grid-এ `PLAZA_ID` → `LOV_PLAZA`; Plaza grid-এ `DISTRICT_ID` → `LOV_DISTRICT`।
- Authorization: Rates, Classes, Plazas, Lanes → `IS_MANAGER`; Employees, Payment Methods, Exemptions → `IS_ADMIN`; Violations → `IS_SUPERVISOR`
- **Shared Components → Navigation Menu**-এ মেনু সাজান। প্রতিটা entry-তে একই Authorization দিন, তাহলে যার অনুমতি নেই সে মেনু দেখবেই না:

```
Dashboard
Toll Booth               (IS_COLLECTOR)
Shifts                   (IS_COLLECTOR)
Transactions             (IS_COLLECTOR)
Vehicles & ETC
   ├ Vehicles            (IS_COLLECTOR)
   ├ Owners              (IS_SUPERVISOR)
   └ RFID Tags & Recharge(IS_SUPERVISOR)
Violations               (IS_SUPERVISOR)
Reports
   ├ Daily Revenue       (IS_MANAGER)
   └ Tariff Board        (everyone)
Administration
   ├ Toll Plazas / Lanes (IS_MANAGER)
   ├ Toll Rates          (IS_MANAGER)
   ├ Vehicle Classes     (IS_MANAGER)
   ├ Employees           (IS_ADMIN)
   └ Payment / Exemption (IS_ADMIN)
```

**Daily Revenue IR**: Actions → **Group By**: `PLAZA_NAME`, Function Sum on `REVENUE, VEHICLE_COUNT`। আরেকটা saved report বানান **Pivot** দিয়ে: Pivot column `CLASS_CODE`, row `TXN_DATE`, value `SUM(REVENUE)`। Save as Public report।

---

## ১৩. ডেমো স্ক্রিপ্ট (প্রেজেন্টেশনে লাইভ দেখানোর জন্য)

Toll Booth পেজে `PDM-MAWA | Lane 1 (MTC)` বা `PDM-MAWA | Lane 2 (HYBRID)` শিফট বেছে নিন:

| # | কী করবেন | যা হবে |
|---|---|---|
| 1 | Plate `dhaka metro-ga-15-4521` লিখে Tab চাপুন | প্লেট নিজে থেকে `DHAKA METRO-GA 15-4521` হয়ে যায়; গাড়ির তথ্য, শ্রেণি আর RFID ব্যালেন্স আসে; টোল ৳750.00 |
| 2 | Cash দিয়ে Collect করুন | রসিদ পেজ খোলে, বাংলা সংখ্যায় ৳৭৫০.০০ |
| 3 | bKash বেছে TrxID ফাঁকা রেখে Collect করুন | Error: *Transaction ID (TrxID) ... is required* |
| 4 | Lane 2-তে `DHAKA METRO-KHA 21-0876`, ETC দিয়ে Collect করুন | Error: *Insufficient ETC balance (৳380.00)*। Violations পেজে `LOW_ETC_BALANCE` রেকর্ড তৈরি হয় |
| 5 | Lane 1-এ (MTC) যেকোনো গাড়ি ETC দিয়ে চেষ্টা করুন | Error: *ETC not available in a manual lane* |
| 6 | KFT (টানেল) শিফটে Motorcycle বেছে নিন | Toll Payable ঘরে *Not permitted* দেখায় |
| 7 | Trailer (5+ axles), Axles = 7, পদ্মা প্লাজায় | ৳7,500 + 2×৳1,500 = **৳10,500.00** |
| 8 | `DHAKA METRO-GA 19-8888` (কালো তালিকাভুক্ত) | টোল আদায় হয়, সাথে `BLACKLISTED` violation |
| 9 | `TANGAIL-KA 11-3012` (রেজিস্টার্ড Car) কিন্তু শ্রেণি দিন Pickup | `CLASS_MISMATCH` violation |
| 10 | Exemption: Ambulance | ৳0, স্ট্যাটাস EXEMPT |
| 11 | SUPERVISOR1 হিসেবে লগইন করে একটা ETC রসিদ Void করুন | ট্যাগের ব্যালেন্স ফেরত আসে |
| 12 | Shifts পেজ → Close, declared cash একটু কম দিন | `CASH_VARIANCE` নেগেটিভ দেখায় (লাল) |
| 13 | COLLECTOR1 হিসেবে লগইন করুন | Admin/Rates মেনু দেখা যায় না (role-based security) |

---

## ১৪. ডাটাবেস ডিজাইনের ব্যাখ্যা (রিপোর্ট/ভাইভার জন্য)

- **১৭টি entity, ৪টি ভাগে**: Location (Division, District), Infrastructure & Tariff (Authority, Toll Plaza, Lane, Vehicle Class, Toll Rate), Vehicles & ETC (Owner, Vehicle, ETC Tag, Tag Recharge), Operations (Employee, Shift, Toll Transaction, Violation, Payment Method, Exemption Type)
- **Normalization (3NF)**:
  - District → Division আলাদা টেবিলে রাখা, তাই division নাম বারবার লেখা হয় না।
  - Transaction টেবিলে plaza বা lane কলাম রাখা হয়নি, কারণ ওগুলো `shift → lane → plaza` থেকে পাওয়া যায় (transitive dependency এড়ানো)।
  - Transaction-এ vehicle class কলামও নেই, কারণ `rate_id → class_id`।
  - `toll_amount` ইচ্ছা করে রাখা হয়েছে, পেমেন্টের মুহূর্তের **ঐতিহাসিক স্ন্যাপশট** হিসেবে। পরে রেট বদলালেও পুরনো রসিদ বদলাবে না।
  - `reg_no` একটা virtual (derived) column, কোথাও আলাদা করে সংরক্ষণ হয় না।
- **রেটের ইতিহাস**: `effective_from / effective_to` দিয়ে রেট বদলালেও পুরনো রেকর্ড থেকে যায় (temporal design)।
- **Business rules যেভাবে DB-তে enforce হয়**:
  - CHECK constraint: NID, মোবাইল, প্লেট ফরম্যাট, ব্যালেন্স ≥ 0, axles
  - Function-based UNIQUE index: একটা লেনে আর একজন কর্মীর একবারে একটাই OPEN শিফট; একটা গাড়িতে একটাই ACTIVE RFID ট্যাগ
  - CHECK: হয় পেমেন্ট পদ্ধতি থাকবে, নয়তো মওকুফ; দুটো একসাথে নয়
  - `SELECT ... FOR UPDATE` দিয়ে ETC ব্যালেন্স কাটা, যাতে একসাথে দুটো লেনদেনে ব্যালেন্স ভুল না হয়
  - `PRAGMA AUTONOMOUS_TRANSACTION`: লেনদেন ব্যর্থ হলেও low-balance violation-এর রেকর্ড থেকে যায়

**কিছু উদাহরণ SQL কোয়েরি (রিপোর্টে দেওয়ার মতো):**
```sql
-- গতকাল কোন প্লাজায় কত আয় (লাখ-কোটি ফরম্যাটে)
select plaza_name, tc_toll_pkg.fmt_bdt(sum(revenue)) revenue, sum(vehicle_count) vehicles
  from tc_v_daily_revenue
 where txn_date = trunc(tc_toll_pkg.bd_now) - 1
 group by plaza_name order by sum(revenue) desc;

-- ডিজিটাল পেমেন্টের অংশ (%)
select round(100 * sum(case when method_code <> 'CASH' then toll_amount end) / sum(toll_amount), 1) digital_pct
  from tc_toll_txn where status = 'PAID';

-- সবচেয়ে বেশি ক্যাশ ঘাটতি থাকা কালেক্টর
select collector_name, count(*) shifts, sum(cash_variance) total_variance
  from tc_v_shift_summary where status = 'CLOSED'
 group by collector_name having sum(cash_variance) < 0 order by 3;

-- যেসব RFID ট্যাগে ব্যালেন্স কম (SMS পাঠানোর তালিকা)
select reg_no, owner_name, owner_mobile, balance_bdt from tc_v_tag_balance where low_balance = 'Y';
```

---

## ১৫. জমা দেওয়ার আগে

1. **App Builder → আপনার App → Export / Import → Export** করে `.sql` ফাইল নিন। এটাই অ্যাপের ব্যাকআপ আর জমা দেওয়ার ফাইল।
2. **Supporting Objects** (ঐচ্ছিক): App → Supporting Objects → Installation Scripts-এ `BD_TCS_install_all.sql` যোগ করুন। তাহলে অন্য workspace-এ import করলে ডাটাবেসসহ পুরো অ্যাপ একবারে চলে আসবে।
3. ERD PNG/PDF রিপোর্ট আর স্লাইডে দিন।

## ১৬. সমস্যা হলে

| সমস্যা | সমাধান |
|---|---|
| মেনু বা পেজ দেখা যাচ্ছে না / "Toll collectors only" | ধাপ ৩.৬ এর `UPDATE` চালান, তারপর **লগআউট করে আবার লগইন** করুন |
| বাংলা লেখা `???` আসছে | স্ক্রিপ্ট আপলোডের সময় UTF-8 বেছে নেওয়া হয়নি। `00_drop_all.sql` চালিয়ে আবার install করুন |
| Toll Booth-এ কোনো শিফট নেই | Shifts → Open Shift দিয়ে নিজের নামে শিফট খুলুন (Admin যেকোনো লেনে খুলতে পারে) |
| "already has an OPEN shift" | ওই লেন বা কর্মীর আগের শিফট আগে Close করুন |
| Vehicle form-এ REG_NO নিয়ে error | `REG_NO` item-এ Query Only = Yes দিন |
