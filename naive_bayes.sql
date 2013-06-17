
-- create extension tablefunc;

create table "SMSSpamCollection"
(
  category text,
  message text,
  message_id serial,
  for_training bool
)
;

\copy "SMSSpamCollection" (category, message) from 'SMSSpamCollection'

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
                      from "SMSSpamCollection" c) + sum(ln(coalesce(b.p_spam, 0) + 1 / coalesce(b.p_ham, 0) + 1)) > 0 then 'spam' else 'ham' end as predicted
    from "SMSSpamCollection" a
           join word_probs b
             on to_tsquery('english', b.lexeme) @@ to_tsvector('english', a.message)
    where not a.for_training
    group by a.message_id,
             a.category
  ) t
  ;

$body$
language sql
volatile
;

-- ---------------------------------------------------------------- --

create or replace function test_naive_bayes2()
returns table (correct bigint, incorrect bigint)
as
$body$

  with
  scores
  as
  (
    select a.message_id,
	   a.category as original_category,
	   c.category as predictor_category,
	   row_number() over (partition by message_id order by ln(c.n::decimal/c."N") + sum(a.n::decimal * ln(b.n::decimal/b."N")) desc) as rank
    from document_words a
	   join word_probs b
	     on a.word = b.word
	   join class_probs c
	     on b.category = c.category
    where not a.for_training
    group by a.message_id,
	     a.category,
	     c.category,
	     c.n,
	     c."N"
  )
  select count(case when original_category = predictor_category then 1 end) as correct,
	 count(case when original_category != predictor_category then 1 end) as incorrect
  from scores
  where rank = 1
  ;

$body$
language sql
volatile
;

-- ---------------------------------------------------------------- --

create table document_words
as
    select for_training,
	   category,
	   message_id,
	   (ts_lexemes(to_tsvector('english', message))).lexeme as word,
	   (ts_lexemes(to_tsvector('english', message))).n
    from "SMSSpamCollection"
;

create table vocabulary
as
    select distinct
           word
    from document_words
;

create table class_probs
as
    select category,
	   count(*) as n,
	   sum(count(*)) over () as "N"
    from "SMSSpamCollection"
    where for_training
    group by category
;

create table word_probs
as
    select c.category,
           b.word,
	   (coalesce(sum(a.n), 0) + 1)::decimal as n,
	   c.n as "N"
    from vocabulary b
           cross join (select category,
	                     sum(n + 1) as n
		      from document_words
		      where for_training
		      group by category) c
	   left join document_words a
	     on a.word = b.word
             and a.category = c.category
	     and a.for_training
    group by c.category,
             b.word,
	     c.n
;

create index idx_document_words_message_id_testing
on document_words (message_id)
where not for_training
;

create index idx_document_words_word_id_testing
on document_words (word)
where not for_training
;

create index idx_document_words_for_training
on document_words (for_training)
;

create index idx_word_probs_word
on word_probs (word)
;

update "SMSSpamCollection"
set for_training = (random() < 0.30)
;

truncate table class_probs;
insert into class_probs
    select category,
     count(*) as n,
     sum(count(*)) over () as "N"
    from "SMSSpamCollection"
    where for_training
    group by category
;

truncate table word_probs;
insert into word_probs
    select c.category,
           b.word,
           coalesce(sum(a.n), 0)::decimal + 0.10 as n,
           c.n as "N"
    from vocabulary b
           cross join (select category,
                              sum(n + 0.10) as n
                       from document_words
                       where for_training
                       group by category) c
         left join document_words a
           on a.word = b.word
           and a.category = c.category
           and a.for_training
    group by c.category,
             b.word,
             c.n
;
