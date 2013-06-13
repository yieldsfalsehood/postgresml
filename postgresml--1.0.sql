
CREATE OR REPLACE FUNCTION ts_lexemes(IN tsvector)
    RETURNS SETOF text
    AS 'postgresml', 'ts_lexemes'
    LANGUAGE C IMMUTABLE STRICT;
