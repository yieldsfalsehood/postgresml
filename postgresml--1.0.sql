
CREATE OR REPLACE FUNCTION ts_lexemes(IN tsvector, out lexeme text, out n int)
    RETURNS SETOF record
    AS 'postgresml', 'ts_lexemes'
    LANGUAGE C IMMUTABLE STRICT;
