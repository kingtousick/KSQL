/* 테이블 검색 */
SELECT
n.nspname AS "Owner",
c.relname AS "테이블ID",
obj_description(c.oid) AS "테이블명",
a.attname AS "컬럼ID",
col_description(c.oid, a.attnum) AS "컬럼명",
CASE WHEN EXISTS (
SELECT 1
FROM pg_constraint con
JOIN pg_attribute pa ON pa.attrelid = con.conrelid AND pa.attnum = ANY(con.conkey)
WHERE con.contype = 'p'
AND con.conrelid = c.oid
AND pa.attname = a.attname
) THEN 'Y' ELSE 'N' END AS "PK여부"
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE a.attnum > 0
AND NOT a.attisdropped
AND c.relkind = 'r'
AND c.relname = ''         -- 테이블ID
-- AND obj_description(c.oid) = ''          -- 테이블명
-- AND a.attname = ''                       -- 컬럼ID
-- AND col_description(c.oid, a.attnum) = '' -- 컬럼명
ORDER BY a.attnum, n.nspname, c.relname;

/* DB LINK 조회 */
-- PostgreSQL은 pg_foreign_server (FDW) 방식 사용
SELECT
fs.srvname AS "서버명",
um.usename AS "사용자",
fs.srvoptions AS "옵션(HOST 등)",
fs.srvtype AS "타입"
FROM pg_foreign_server fs
LEFT JOIN pg_user_mappings um ON um.srvid = fs.oid
WHERE fs.srvname = '';  -- 서버명

/* 최근 변경 함수/프로시저 조회 */
-- PostgreSQL은 PROCEDURE/FUNCTION 구분, LAST_DDL_TIME 없음 → pg_stat_user_functions 또는 정보스키마 활용
SELECT
routine_schema AS "Owner",
routine_name || '(' || routine_type || ')' AS "프로시저/함수명",
routine_type AS "타입",
external_language AS "언어"
FROM information_schema.routines
WHERE routine_schema = 'public'   -- Oracle의 OWNER에 해당
AND routine_type IN ('PROCEDURE', 'FUNCTION')
ORDER BY routine_name;

-- ※ DDL 변경 이력은 PostgreSQL 기본 기능으로 제공 안됨 (audit 로그 또는 pg_audit 확장 필요)

/* 프로시저 단순 조회 */
SELECT
routine_schema,
routine_name,
routine_type
FROM information_schema.routines
WHERE routine_type = 'PROCEDURE'
AND routine_name = lower('프로시저명');  -- PostgreSQL은 소문자 기준

/* 프로시저 실행 */
CALL 프로시저명('202303,5,,,,,,,,', 'TEST_MAN');

/* DB 파일 PATH (데이터 디렉토리) */
-- Oracle DBA_DIRECTORIES 대응: PostgreSQL은 서버 경로 직접 조회
SHOW data_directory;

-- pg_ls_dir로 특정 경로 내 목록 확인 (superuser 필요)
SELECT pg_ls_dir('경로');

/* 소스(함수/프로시저 본문) 조회 */
SELECT
n.nspname AS "Owner",
p.proname AS "Name",
CASE p.prokind
WHEN 'f' THEN 'FUNCTION'
WHEN 'p' THEN 'PROCEDURE'
END AS "Type",
pg_get_functiondef(p.oid) AS "소스"
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname != 'pg_catalog'
AND pg_get_functiondef(p.oid) ILIKE '%검색키워드%'  -- Oracle의 TEXT LIKE 대응
AND p.prokind = 'f';  -- 'f'=FUNCTION, 'p'=PROCEDURE

/* 과거 데이터 조회 */
-- ※ Oracle AS OF TIMESTAMP는 PostgreSQL 기본 기능 없음
-- 방법 1: pg_audit 또는 WAL 기반 복구 (운영환경 제약)
-- 방법 2: 테이블에 created_at/updated_at 컬럼이 있는 경우
-- 하루 전 데이터
SELECT *
FROM 테이블명
WHERE updated_at >= NOW() - INTERVAL '1 day'
AND 조건;

-- 14시간 전 데이터
SELECT *
FROM 테이블명
WHERE updated_at >= NOW() - INTERVAL '14 hours'
AND 조건;

-- 방법 3: pgaudit 또는 timescaledb 사용 환경이라면 별도 이력 테이블 조회 필요