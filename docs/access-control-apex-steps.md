# Access control: APEX build steps

Run `database/06_access_control.sql` first, then build these Shared Components and pages in Oracle APEX.

## Step 1: Authorization schemes (Shared Components → Authorization Schemes → Create → From Scratch)
Create these 14 schemes. For each: Type = PL/SQL Function Returning Boolean,
Code = `return tc_access_pkg.has_perm('<CODE>');`,
Error Message = `You do not have permission: <CODE>`,
Validate authorization scheme = **Once per page view** (important: changes then apply without logging out).

| Scheme name | CODE |
|---|---|
| CAN_TOLL_COLLECT | TOLL_COLLECT |
| CAN_SHIFT_VIEW | SHIFT_VIEW |
| CAN_SHIFT_OPEN | SHIFT_OPEN |
| CAN_SHIFT_CLOSE | SHIFT_CLOSE |
| CAN_TXN_VIEW | TXN_VIEW |
| CAN_TXN_VOID | TXN_VOID |
| CAN_VEHICLE_VIEW | VEHICLE_VIEW |
| CAN_VEHICLE_MANAGE | VEHICLE_MANAGE |
| CAN_TAG_MANAGE | TAG_MANAGE |
| CAN_VIOLATION_MANAGE | VIOLATION_MANAGE |
| CAN_REPORT_REVENUE | REPORT_REVENUE |
| CAN_MASTER_DATA | MASTER_DATA |
| CAN_SYSTEM_SETUP | SYSTEM_SETUP |
| CAN_ACCESS_MANAGE | ACCESS_MANAGE |

## Step 2: List of Values (Shared Components → List of Values)
Edit `LOV_PLAZA`, new SQL:
```sql
select p.plaza_name || ' (' || p.plaza_code || ')' d, p.plaza_id r
  from tc_toll_plaza p
 where p.plaza_id in (select plaza_id from tc_v_my_plaza)
 order by 1
```
Edit `LOV_LANE`, new SQL:
```sql
select p.plaza_code || ' - Lane ' || l.lane_no || ' (' || l.lane_type || ', ' || l.direction || ')' d, l.lane_id r
  from tc_toll_lane l join tc_toll_plaza p on p.plaza_id = l.plaza_id
 where l.is_active = 'Y'
   and p.plaza_id in (select plaza_id from tc_v_my_plaza)
 order by p.plaza_code, l.lane_no
```
Create a new LOV `LOV_PERMISSION` (Dynamic, SQL Query, Return = R, Display = D):
```sql
select module || ' > ' || perm_name || ' (' || perm_code || ')' d, perm_code r
  from tc_permission
 order by sort_order
```

## Step 3: Replace page / component authorization
Open each page (find them by name in the page list) and set **Page → Security → Authorization Scheme**:

| Page(s) | New authorization | Also change |
|---|---|---|
| Toll Booth (2), Toll Receipt (3) | CAN_TOLL_COLLECT | |
| Shifts (4) | CAN_SHIFT_VIEW | button OPEN_SHIFT → CAN_SHIFT_OPEN; the "Close" link column → CAN_SHIFT_CLOSE |
| Open Shift (5) | CAN_SHIFT_OPEN | |
| Close Shift (6) | CAN_SHIFT_CLOSE | |
| Transactions (7) | CAN_TXN_VIEW | the "Void" link column → CAN_TXN_VOID |
| Void Receipt (8) | CAN_TXN_VOID | |
| Vehicles report, Vehicle form | CAN_VEHICLE_VIEW | on the Vehicle form: buttons CREATE, SAVE, DELETE → CAN_VEHICLE_MANAGE; on the Vehicles report: the Create button → CAN_VEHICLE_MANAGE |
| Owners report + form | CAN_VEHICLE_MANAGE | |
| RFID Tags report + form, Recharge dialog | CAN_TAG_MANAGE | |
| Violations report + form | CAN_VIOLATION_MANAGE | |
| Daily Revenue | CAN_REPORT_REVENUE | |
| Toll Plazas, Lanes, Vehicle Classes, Toll Rates | CAN_MASTER_DATA | |
| Employees, Payment Methods, Exemption Types | CAN_SYSTEM_SETUP | |
| Home/Dashboard, Tariff Board, Login | leave as is | |

## Step 4: Toll Booth page (Page 2)
4a. `P2_SHIFT_ID` → List of Values SQL Query, replace with:
```sql
select p.plaza_code || ' | Lane ' || l.lane_no || ' (' || l.lane_type || ') | '
       || e.full_name || ' | Shift ' || s.shift_code d,
       s.shift_id r
  from tc_shift s
  join tc_toll_lane  l on l.lane_id  = s.lane_id
  join tc_toll_plaza p on p.plaza_id = l.plaza_id
  join tc_employee   e on e.emp_id   = s.emp_id
 where s.status = 'OPEN'
   and p.plaza_id in (select plaza_id from tc_v_my_plaza)
   and (s.emp_id = :G_EMP_ID or tc_access_pkg.has_perm_yn('ANY_SHIFT_COLLECT') = 'Y')
 order by 1
```
4b. Validation "Own shift only" (Rows returned). Replace its SQL with:
```sql
select 1
  from tc_shift s
  join tc_toll_lane l on l.lane_id = s.lane_id
 where s.shift_id = :P2_SHIFT_ID
   and s.status = 'OPEN'
   and l.plaza_id in (select plaza_id from tc_v_my_plaza)
   and (s.emp_id = :G_EMP_ID or tc_access_pkg.has_perm_yn('ANY_SHIFT_COLLECT') = 'Y')
```
Error message: `You can collect toll only on your own open shift at your plaza.` If the validation does not exist, create it (Rows returned, Server-side condition: When button pressed = the collect button).

## Step 5: Plaza scope on remaining pages
- Toll Rates grid, Lanes grid, Toll Plazas grid: region Source → WHERE clause `plaza_id in (select plaza_id from tc_v_my_plaza)`
- Violations report (source TC_VIOLATION): WHERE clause `shift_id in (select shift_id from tc_v_shift_summary)`
- Dashboard (Page 1) Cards region: in the SQL replace
  `from tc_shift where status = 'OPEN'` with `from tc_v_shift_summary where status = 'OPEN'`, and
  `from tc_violation where status = 'OPEN'` with
  `from tc_violation where status = 'OPEN' and shift_id in (select shift_id from tc_v_shift_summary)`
(Transactions, Shifts, Daily Revenue and the charts use views that are already scoped. Nothing to do there.)

## Step 6: New page "Role Permissions" (Page 30, Normal page)
- Create Page → Interactive Grid, Name `Role Permissions`, Editing Enabled = Yes, Source = Table/View `TC_V_ROLE_PERM_MATRIX`, Primary Key column = `PERM_CODE`.
- Page Authorization: CAN_ACCESS_MANAGE.
- Region Attributes → Edit: Allowed Operations = **Update Row only** (untick Add Row and Delete Row).
- Region Source → Order By: `sort_order`.
- Columns:
  - PERM_CODE: Primary Key = Yes, Type Display Only
  - MODULE, PERM_NAME, PERM_NAME_BN, DESCRIPTION: Type Display Only (headings: Module, Permission, অনুমতি, Description)
  - SORT_ORDER: Hidden
  - COLLECTOR, SUPERVISOR, MANAGER: Type **Switch**, On Value `Y`, Off Value `N`; headings `Toll Collector`, `Supervisor`, `Plaza Manager`
  - ADMIN: Display Only, heading `Admin (always)`
- After creating, run the page → Actions → Format → Control Break on MODULE → Actions → Report → Save (Primary, as developer).
- Make sure the page has the process "Interactive Grid - Automatic Row Processing (DML)" for this region (the wizard creates it).
- Add a Static Content region above the grid with text:
  `Tick a switch and press Save. Admin always has every permission. Changes apply on the user's next page load.`

## Step 7: New page "Edit User Access" (Page 32, Modal Dialog)
Create a blank Modal Dialog page 32, Name `Edit User Access`, Authorization CAN_ACCESS_MANAGE. Region "User" (Static Content) with items:
- `P32_EMP_ID`: Hidden, Value Protected = Yes
- `P32_EMP_INFO`: Display Only, Label `Employee`, Source SQL Query:
  `select emp_code || ' - ' || full_name || ' (' || initcap(replace(designation,'_',' ')) || ', home: ' || nvl(home_plaza,'all') || ')' from tc_v_user_access where emp_id = :P32_EMP_ID`
- `P32_PLAZAS`: Shuttle, Label `Extra plazas (home plaza is always included)`, LOV `LOV_PLAZA`, Source SQL Query (return single value):
  `select listagg(plaza_id, ':') within group (order by plaza_id) from tc_emp_plaza_access where emp_id = :P32_EMP_ID`
- `P32_GRANTS`: Shuttle, Label `Extra permissions (GRANT)`, LOV `LOV_PERMISSION`, Source SQL Query:
  `select listagg(perm_code, ':') within group (order by perm_code) from tc_emp_permission where emp_id = :P32_EMP_ID and grant_type = 'GRANT'`
- `P32_REVOKES`: Shuttle, Label `Removed permissions (REVOKE)`, LOV `LOV_PERMISSION`, Source SQL Query:
  `select listagg(perm_code, ':') within group (order by perm_code) from tc_emp_permission where emp_id = :P32_EMP_ID and grant_type = 'REVOKE'`
- For the three shuttles and P32_EMP_INFO: Source → Used = "Always, replacing any existing value in session state".
- Help/inline text under P32_GRANTS: `Admin users always have everything; overrides on Admin are ignored.`

Second region "Effective permissions" (Classic Report), SQL:
```sql
select module, perm_name, perm_code,
       case source when 'ADMIN' then 'Admin (all)'
                   when 'ROLE'  then 'From role'
                   when 'GRANT' then 'Extra grant'
                   when 'REVOKE' then 'Revoked'
                   else '-' end as reason,
       allowed
  from tc_v_emp_effective_perm
 where emp_id = :P32_EMP_ID
 order by sort_order
```
Highlight: column ALLOWED, use HTML Expression `<span class="u-bold">#ALLOWED#</span>` (optional).

Buttons: `CANCEL` (Dynamic Action → Cancel Dialog), `SAVE` (Submit Page, Hot).
Process (Processing, When button pressed SAVE), Type Execute Code:
```sql
tc_access_pkg.set_user_access(p_emp_id  => :P32_EMP_ID,
                              p_grants  => :P32_GRANTS,
                              p_revokes => :P32_REVOKES,
                              p_plazas  => :P32_PLAZAS);
```
Success message `Access updated / অনুমতি হালনাগাদ হয়েছে`.
Second process: Close Dialog (When button pressed SAVE).

## Step 8: New page "User Access" (Page 31, Normal page)
- Create Page → Interactive Report, Name `User Access`, Source Table/View `TC_V_USER_ACCESS`, Authorization CAN_ACCESS_MANAGE.
- Hide EMP_ID. Headings: Code, Name, Role, APEX user, Active, Home plaza, Extra plazas, Extra grants, Revoked.
- Link Column: Link to Custom Target → Page 32, Set Items `P32_EMP_ID` = `#EMP_ID#`, Clear Cache `32`, Link Icon = edit icon.
- Dynamic Action on the IR region: Event "Dialog Closed" → Action Refresh this region.

## Step 9: Navigation Menu (Shared Components → Navigation Menu)
Set each entry's Authorization Scheme:
Toll Booth → CAN_TOLL_COLLECT; Shifts → CAN_SHIFT_VIEW; Transactions → CAN_TXN_VIEW; Vehicles → CAN_VEHICLE_VIEW;
Owners → CAN_VEHICLE_MANAGE; RFID Tags & Recharge → CAN_TAG_MANAGE; Violations → CAN_VIOLATION_MANAGE;
Daily Revenue → CAN_REPORT_REVENUE; Toll Plazas / Lanes, Toll Rates, Vehicle Classes → CAN_MASTER_DATA;
Employees, Payment / Exemption → CAN_SYSTEM_SETUP.
Under "Administration" add two entries: `Role Permissions` (Page 30) and `User Access` (Page 31), both CAN_ACCESS_MANAGE, icon fa-key / fa-user-lock.
On the parent "Administration" entry set Condition = Expression (PL/SQL):
```sql
tc_access_pkg.has_perm('MASTER_DATA') or tc_access_pkg.has_perm('SYSTEM_SETUP') or tc_access_pkg.has_perm('ACCESS_MANAGE')
```

