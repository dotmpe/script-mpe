import sys
import csv

INFILE = sys.argv[1]
Reader = csv.reader(open(INFILE), delimiter=',')

for row in Reader:
	if row == ['\x1a']:
		break
	#print row
	date = row[2][:4] +'-'+ row[2][4:6] +'-'+ row[2][6:8]
	mut = row[4]
	debet = row[3] == "D"
	debiteur_acc, debiteur_name = row[5:7]
	tcat = row[8]
	out = date, debet and mut or "", not debet and mut or "", debiteur_acc, debiteur_name, tcat
	print ",".join( map(lambda x: '"%s"' % x, out) )
