# Instance summary

Checked means regular=true with neither timeout nor crash. Discarded counts every regular=false record; status counts may overlap (in particular, crashes can also be discarded). Failures and slack statistics use checked records only. Empty slack statistics mean no checked records.

Equal means slack == 0 (identical Betti tables); strict means slack > 0. Negative slack contributes to the statistics but neither count.

cds_violated marks failure of a_i >= sum_{j<i}(a_j - 1) for any i >= 3; tuples of length below three satisfy the condition. The overall marker is not applicable.

| n | a | cds_violated | total | discarded | timeouts | crashes | checked | A_fail | B_fail | C_fail | equal | strict | slack_mean | slack_median | slack_max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 3 | [2] | false | 25 | 0 | 0 | 0 | 25 | 0 | 0 | 0 | 13 | 12 | 2.32 | 0.0 | 8.0 |
| 3 | [2,2] | false | 25 | 2 | 0 | 0 | 23 | 0 | 0 | 0 | 10 | 13 | 3.3043478260869565 | 4.0 | 10.0 |
| 3 | [2,3] | false | 25 | 1 | 0 | 0 | 24 | 0 | 0 | 0 | 2 | 22 | 6.75 | 6.0 | 10.0 |
| 3 | [2,4] | false | 25 | 3 | 0 | 0 | 22 | 0 | 0 | 0 | 0 | 22 | 9.181818181818182 | 8.0 | 18.0 |
| 3 | [2,5] | false | 25 | 0 | 0 | 0 | 25 | 0 | 0 | 0 | 2 | 23 | 10.56 | 10.0 | 26.0 |
| 3 | [3] | false | 25 | 0 | 0 | 0 | 25 | 0 | 0 | 0 | 0 | 25 | 16.48 | 16.0 | 24.0 |
| 3 | [3,3] | false | 25 | 2 | 0 | 0 | 23 | 0 | 0 | 0 | 0 | 23 | 15.304347826086957 | 12.0 | 30.0 |
| 3 | [3,4] | false | 25 | 2 | 0 | 0 | 23 | 0 | 0 | 0 | 0 | 23 | 20.17391304347826 | 18.0 | 42.0 |
| 3 | [3,5] | false | 25 | 1 | 0 | 0 | 24 | 0 | 0 | 0 | 0 | 24 | 27.666666666666668 | 27.0 | 42.0 |
| 3 | [4] | false | 25 | 0 | 0 | 0 | 25 | 0 | 0 | 0 | 1 | 24 | 34.32 | 36.0 | 46.0 |
| 3 | [4,4] | false | 25 | 2 | 0 | 0 | 23 | 0 | 0 | 0 | 0 | 23 | 32.869565217391305 | 30.0 | 58.0 |
| 3 | [4,5] | false | 25 | 0 | 2 | 0 | 23 | 0 | 0 | 0 | 0 | 23 | 46.95652173913044 | 46.0 | 70.0 |
| 3 | [5] | false | 25 | 0 | 0 | 0 | 25 | 0 | 0 | 0 | 0 | 25 | 64.56 | 64.0 | 108.0 |
| 3 | [5,5] | false | 25 | 2 | 2 | 0 | 21 | 0 | 0 | 0 | 0 | 21 | 54.19047619047619 | 54.0 | 80.0 |
| 4 | [2] | false | 25 | 0 | 0 | 0 | 25 | 0 | 0 | 0 | 0 | 25 | 32.16 | 26.0 | 70.0 |
| 4 | [2,2] | false | 25 | 0 | 1 | 0 | 24 | 0 | 0 | 0 | 0 | 24 | 28.333333333333332 | 24.0 | 58.0 |
| 4 | [2,3] | false | 25 | 0 | 2 | 0 | 23 | 0 | 0 | 0 | 0 | 23 | 59.04347826086956 | 50.0 | 118.0 |
| 4 | [2,4] | false | 25 | 0 | 13 | 0 | 12 | 0 | 0 | 0 | 0 | 12 | 98.33333333333333 | 82.0 | 230.0 |
| 4 | [2,5] | false | 25 | 0 | 14 | 0 | 11 | 0 | 0 | 0 | 0 | 11 | 176.9090909090909 | 168.0 | 306.0 |
| 4 | [3] | false | 25 | 0 | 1 | 0 | 24 | 0 | 0 | 0 | 0 | 24 | 144.83333333333334 | 126.0 | 240.0 |
| 4 | [3,3] | false | 25 | 1 | 13 | 0 | 11 | 0 | 0 | 0 | 0 | 11 | 176.0 | 178.0 | 244.0 |
| 4 | [3,4] | false | 25 | 1 | 22 | 0 | 2 | 0 | 0 | 0 | 0 | 2 | 280.0 | 280.0 | 306.0 |
| 4 | [3,5] | false | 8 | 0 | 5 | 0 | 3 | 0 | 0 | 0 | 0 | 3 | 555.3333333333334 | 522.0 | 690.0 |
| 4 | [4] | false | 25 | 0 | 13 | 0 | 12 | 0 | 0 | 0 | 0 | 12 | 358.5 | 376.0 | 578.0 |
| 4 | [5] | false | 25 | 0 | 20 | 0 | 5 | 0 | 0 | 0 | 0 | 5 | 595.6 | 662.0 | 754.0 |
| Overall | — | — | 608 | 17 | 108 | 0 | 483 | 0 | 0 | 0 | 28 | 455 | 60.01242236024845 | 28.0 | 754.0 |
