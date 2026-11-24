-- =====================================================================
--  Bangladesh Toll Collection System (BD-TCS)
--  00_drop_all.sql  -  OPTIONAL: removes every BD-TCS object so the
--  install scripts can be run again from scratch.
--  (Errors such as "table does not exist" are ignored.)
-- =====================================================================
BEGIN
  FOR r IN (SELECT object_name, object_type
              FROM user_objects
             WHERE object_name LIKE 'TC\_%' ESCAPE '\'
               AND object_type IN ('VIEW','PACKAGE','TABLE','SEQUENCE')
             ORDER BY DECODE(object_type,'VIEW',1,'PACKAGE',2,'TABLE',3,4))
  LOOP
    BEGIN
      IF r.object_type = 'TABLE' THEN
        EXECUTE IMMEDIATE 'DROP TABLE "' || r.object_name || '" CASCADE CONSTRAINTS PURGE';
      ELSE
        EXECUTE IMMEDIATE 'DROP ' || r.object_type || ' "' || r.object_name || '"';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/
