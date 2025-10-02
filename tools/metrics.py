import csv,statistics
rows=[]
with open('decisions.csv') as f:
    r=csv.reader(f)
    for event_time,received_time,action,confidence in r:
        try:
            rows.append((float(event_time), float(received_time), action, float(confidence)))
        except:
            pass
mtta = statistics.mean([r[1]-r[0] for r in rows])
print("MTTA", mtta)
