# Instance summary

Checked means regular=true with neither timeout nor crash. Discarded counts every regular=false record; status counts may overlap (in particular, crashes can also be discarded). Failures and slack statistics use checked records only. Empty slack statistics mean no checked records.

Equal means slack == 0 (identical Betti tables); strict means slack > 0. Negative slack contributes to the statistics but neither count.

cds_violated marks failure of a_i >= sum_{j<i}(a_j - 1) for any i >= 3; tuples of length below three satisfy the condition. The overall marker is not applicable.

| n | a | cds_violated | total | discarded | timeouts | crashes | checked | A_fail | B_fail | C_fail | equal | strict | slack_mean | slack_median | slack_max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 5 | [2,2,2,2,2] | true | 15 | 6 | 0 | 0 | 9 | 0 | 0 | 0 | 2 | 7 | 17.333333333333332 | 12.0 | 50.0 |
| 5 | [2,2,2,2,3] | true | 15 | 7 | 2 | 0 | 6 | 0 | 0 | 0 | 0 | 6 | 66.33333333333333 | 61.0 | 82.0 |
| 5 | [2,2,2,2,4] | true | 15 | 5 | 0 | 0 | 10 | 0 | 0 | 0 | 0 | 10 | 102.6 | 112.0 | 120.0 |
| 5 | [2,2,2,2,5] | true | 15 | 4 | 1 | 0 | 10 | 0 | 0 | 0 | 1 | 9 | 107.6 | 118.0 | 164.0 |
| 5 | [2,2,2,3,3] | true | 15 | 4 | 4 | 0 | 7 | 0 | 0 | 0 | 0 | 7 | 81.42857142857143 | 84.0 | 134.0 |
| 5 | [2,2,2,3,4] | true | 15 | 4 | 8 | 0 | 3 | 0 | 0 | 0 | 0 | 3 | 142.0 | 136.0 | 156.0 |
| 5 | [2,2,2,4,4] | true | 15 | 3 | 11 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 2.0 | 2.0 | 2.0 |
| 5 | [2,2,2,4,5] | true | 15 | 4 | 7 | 0 | 4 | 0 | 0 | 0 | 0 | 4 | 174.0 | 179.0 | 186.0 |
| 5 | [2,2,3,3,3] | true | 15 | 5 | 6 | 0 | 4 | 0 | 0 | 0 | 0 | 4 | 136.0 | 136.0 | 136.0 |
| 5 | [2,2,3,3,4] | true | 15 | 5 | 10 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |
| 5 | [2,2,3,3,5] | true | 15 | 4 | 8 | 0 | 3 | 0 | 0 | 0 | 0 | 3 | 216.0 | 206.0 | 236.0 |
| 5 | [2,2,3,4,4] | true | 14 | 6 | 5 | 0 | 3 | 0 | 0 | 0 | 0 | 3 | 206.0 | 204.0 | 212.0 |
| 5 | [2,3,3,3,3] | true | 15 | 3 | 11 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 92.0 | 92.0 | 92.0 |
| Overall | — | — | 194 | 60 | 73 | 0 | 61 | 0 | 0 | 0 | 3 | 58 | 102.49180327868852 | 110.0 | 236.0 |
