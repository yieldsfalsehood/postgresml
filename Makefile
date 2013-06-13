MODULES = postgresml
EXTENSION = postgresml
DATA = postgresml--1.0.sql
DOCS = README.postgresml

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
