
-- create extension tablefun;

create table "SMSSpamCollection"
(
  category text,
  message text,
  message_id serial,
  for_training bool
)
;

\copy "SMSSpamCollection" from 'SMSSpamCollection'

create index "idx_SMSSpamCollection_message"
on "SMSSpamCollection"
using gin(to_tsvector('english', message))
;

-- ---------------------------------------------------------------- --

create or replace function test_naive_bayes(decimal)
returns table (correct bigint, incorrect bigint)
as
$body$

  update "SMSSpamCollection"
  set for_training = case when random() < $1 then true else false end
  ;

  with word_probs
  as
  (
    select lexeme,
           p_ham,
           p_spam
    from crosstab($$

      select a.row_name,
             a.category,
             a.ndoc::decimal / b.nlex as value
      from
      (
        select word as row_name,
               'spam' as category,
               ndoc,
               nentry
        from ts_stat('select to_tsvector(''english'', message) from "SMSSpamCollection" where category = ''spam'' and for_training')

        union all

        select word,
               'ham',
               ndoc,
               nentry
        from ts_stat('select to_tsvector(''english'', message) from "SMSSpamCollection" where category = ''ham'' and for_training')
      ) a,
      (
        select category,
               sum(length(to_tsvector('english', message))) as nlex
        from "SMSSpamCollection"
        where for_training
        group by category
      ) b
      where a.category = b.category
      order by a.row_name,
               a.category

    $$) as t (lexeme text, p_ham decimal, p_spam decimal)
    where p_ham is not null
      and p_spam is not null
  )
  select count(case when category = predicted then 1 end) as correct,
         count(case when category != predicted then 1 end) as incorrect
  from
  (
    select a.message_id,
           a.category,
           case when (select ln(count(case when c.category = 'spam' then 1 end)::decimal/count(case when c.category = 'ham' then 1 end))
                      from "SMSSpamCollection" c) + sum(ln(b.p_spam / b.p_ham)) > 0 then 'spam' else 'ham' end as predicted
    from "SMSSpamCollection" a
           join word_probs b
             on to_tsquery('english', b.lexeme) @@ to_tsvector('english', a.message)
    where b.p_ham > 0.0
      and b.p_spam > 0.0
      and not a.for_training
    group by a.message_id,
             a.category
  ) t
  ;

$body$
language sql
volatile
;

-- ---------------------------------------------------------------- --
