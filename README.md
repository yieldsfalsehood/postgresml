
Overview
--------

This is a naive implementation of a binary naive Bayes text classifier
in postgresql. The data set was downloaded from
http://archive.ics.uci.edu/ml/datasets/SMS+Spam+Collection.

ts_stat is used to extract counts of each word by class (spam or
ham). crosstab is used as a convenience to pivot the spam and ham
counts in to adjacent columns. then the frequency distributions of
words by class are used to classify documents.

Usage
-----

To train on 30% of the data set (and test on the remaining 70%), run

```
select test_naive_bayes(0.3);
```

Sources
-------

Almeida, T.A., GÃ³mez Hidalgo, J.M., Yamakami, A. Contributions to the Study of SMS Spam Filtering: New Collection and Results. Proceedings of the 2011 ACM Symposium on Document Engineering (DOCENG'11), Mountain View, CA, USA, 2011.
