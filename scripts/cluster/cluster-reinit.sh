qtools --describe "cluster-reinit" stop --wait
qtools --describe "cluster-reinit" cluster-setup --master
qtools --describe "cluster-reinit" start
qtools --describe "cluster-reinit" restart