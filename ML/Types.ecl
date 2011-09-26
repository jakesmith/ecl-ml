﻿EXPORT Types := MODULE

EXPORT t_RecordID := UNSIGNED;
EXPORT t_FieldNumber := UNSIGNED2;
EXPORT t_FieldReal := REAL8;

EXPORT NumericField := RECORD
  t_RecordID id;
	t_FieldNumber number;
	t_FieldReal value;
  END;
	
END;