import json,sys
d=json.loads(open('results/main/VIOLATIONS.jsonl').readline())
n=d['n']; v=["x%d"%i for i in range(1,n+1)]
def poly(p):
    t=[]
    for e,c in p:
        m="*".join("%s^%d"%(v[i],e[i]) for i in range(n) if e[i]>0) or "1"
        t.append("(%d)*%s"%(c,m))
    return " + ".join(t)
gens=[poly(p) for p in d['fs']+d['extras']]
open('verification/violation_n4_a3334_seed4.m2','w').write(
 "R = QQ[%s];\nI = ideal(\n  %s);\nB = betti res I;\nprint B;\nprint (\"pd S/I = \" | toString pdim(R^1/I));\nprint hilbertFunction(5,R^1/I);\nprint betti res(I, Strategy=>1);\nprint betti res(I, Strategy=>2);\n"%(",".join(v),",\n  ".join(gens)))
open('verification/violation_n4_a3334_seed4.sing','w').write(
 "ring R=0,(%s),dp;\nideal I=\n%s;\nresolution r=mres(I,0);\nprint(betti(r),\"betti\");\nresolution r2=sres(std(I),0);\nprint(betti(r2),\"betti\");\nquit;\n"%(",".join(v),",\n".join(gens)))
