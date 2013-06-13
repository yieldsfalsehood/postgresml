#include "postgres.h"

#include <string.h>

#include "catalog/pg_type.h"
#include "fmgr.h"
#include "funcapi.h"
#include "tsearch/ts_utils.h"
#include "utils/geo_decls.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

typedef struct
{
  TSVector  vector;
  int	nextelem;
  int	numelems;
  WordEntry *entries;
  char *str;
} _ts_lexemes_fctx;

PG_FUNCTION_INFO_V1(ts_lexemes);

Datum
ts_lexemes(PG_FUNCTION_ARGS)
{

  FuncCallContext     *funcctx;
  _ts_lexemes_fctx *fctx;
  MemoryContext   oldcontext;
  TSVector vector;

  int i;
  Datum result;

  TupleDesc tupdesc;
  char *values[2];
  char n[16];
  HeapTuple tuple;

  if (SRF_IS_FIRSTCALL())
    {

      funcctx = SRF_FIRSTCALL_INIT();
      oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

      vector = PG_GETARG_TSVECTOR(0);
      fctx = (_ts_lexemes_fctx *) palloc(sizeof(_ts_lexemes_fctx));
      
      fctx->vector = vector;
      fctx->nextelem = 0;
      fctx->numelems = vector->size;

      fctx->entries = ARRPTR(vector);
      fctx->str = STRPTR(vector);

      tupdesc = CreateTemplateTupleDesc(2, false);
      TupleDescInitEntry(tupdesc, (AttrNumber) 1, "lexeme",
			 TEXTOID, -1, 0);
      TupleDescInitEntry(tupdesc, (AttrNumber) 2, "n",
			 INT4OID, -1, 0);
      funcctx->tuple_desc = BlessTupleDesc(tupdesc);
      funcctx->attinmeta = TupleDescGetAttInMetadata(tupdesc);

      funcctx->user_fctx = fctx;

      MemoryContextSwitchTo(oldcontext);

    }

  funcctx = SRF_PERCALL_SETUP();
  fctx = funcctx->user_fctx;

  if (fctx->nextelem < fctx->numelems)
    {

      i = fctx->nextelem++;
      
      values[0] = palloc(fctx->entries[i].len + 1);
      memcpy(values[0], fctx->str + fctx->entries[i].pos, fctx->entries[i].len);
      (values[0])[fctx->entries[i].len] = '\0';

      sprintf(n, "%d", POSDATALEN(fctx->vector, &(fctx->entries[i])));
      values[1] = n;
      
      tuple = BuildTupleFromCStrings(funcctx->attinmeta, values);
      result = HeapTupleGetDatum(tuple);

      pfree(values[0]);

      SRF_RETURN_NEXT(funcctx, result);

    }
  else
    {
      SRF_RETURN_DONE(funcctx);
    }
}
