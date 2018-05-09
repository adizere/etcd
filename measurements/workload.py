import etcd, threading, sys, time, os, multiprocessing, ctypes
import numpy as np
from multiprocessing import Pool, Manager

current_milli_time = lambda: int(round(time.time() * 1000))

# How many seconds should the execution last?
EXECUTION_DURATION=10

# How many seconds should we wait for connections initialization
CONNNECTION_SLACK=2

# How many seconds should we wait for outlying executors
EXECUTION_SLACK=2

class EtcdBCFabric(object):
    def __init__(self, dirName, ip, port):
        self.directoryName = "/" + dirName + "/tx/"
        print "Executor about to connect -- " + str(os.getpid())
        self.handle = etcd.Client(host=ip,port=port)
        print "... connected"

    # Does a mock transaction
    def tx(self,tx_payload):
        self.handle.write(self.directoryName, tx_payload, append=True)

class WorkloadResults(object):
    def __init__(self, contactNodeIP="", counter = 0, latencies = []):
        self.opCounter = counter
        self.opLatencies = latencies
        self.runtime = 0
        self.contactIP = contactNodeIP

    def getCounter(self):
        return self.opCounter

    def getLatencies(self):
        return self.opLatencies

    def merge(self, anotherWorkloadRes):
        self.opCounter += anotherWorkloadRes.getCounter()
        self.opLatencies += anotherWorkloadRes.getLatencies()

    def setRuntime(self, time):
        self.runtime = time

    def printStatistics(self):
        if (self.opCounter > 0):
            # avoid division by 0
            throughput = self.opCounter / (float(delta) / 1000)
        else:
            # print 0 if the counter is 0..
            throughput = 0
        print("%10dops\t%10dms\t%8.2f\t%8.2f\t%8.2f\t%8.2f\t%8.2f\t%s" % (
            self.opCounter,
            delta,
            throughput,
            np.mean(self.opLatencies),
            np.std(self.opLatencies),
            np.percentile(self.opLatencies, 95),
            np.percentile(self.opLatencies, 99),
            self.contactIP))


def execute_workload(ip, port, blockSize, startEv, stopEv, pLock, pCounter, pStartTime):
    zk = EtcdBCFabric("stressor", ip, port)
    print "Executor waiting -- " + str(os.getpid())
    startEv.wait()
    print "Executor running -- " + str(os.getpid())
    ## TODO: Perhaps use a random string instead of hardcoded 'x'
    item = "x" * blockSize
    cnt = 0
    lats = []
    while stopEv.is_set() == False:
        startt = current_milli_time()
        zk.tx(item)
        lats.append(current_milli_time() - startt)
        cnt += 1
	#if cnt >= 1000:
	#	stopEv.set()
        pLock.acquire()
        pCounter.value += 1
        pRuntime = current_milli_time() - pStartTime.value
        if pRuntime > 1000:     # if a second passed, ...
            print "> " + str(pCounter.value)
            pCounter.value = 0
            pStartTime.value = current_milli_time()
        pLock.release()
    print "Executor finished " + str(cnt) + " -- " + str(os.getpid())
    return WorkloadResults(counter=cnt, latencies=lats)


if __name__ == '__main__':
    with Manager() as manager:
        startEvent = manager.Event()
        stopEvent = manager.Event()
        pLock = manager.RLock()
        pCounter = manager.Value('i', 0)
        pStartTime = manager.Value('i', 0)
        executorsCount=int(sys.argv[4])
        print "Using a pool of " + str(executorsCount) + " executors"
        pool = Pool(processes=executorsCount)
        executors = [
            pool.apply_async(
                    execute_workload,
                    [sys.argv[1],               # IP
                    int(sys.argv[2]),           # port
                    int(sys.argv[3]),           # block size
                    startEvent, stopEvent, pLock, pCounter, pStartTime])
            for x in xrange(executorsCount)]
        # Allow executors to establish their connections
        print "Sleeping for " + str(CONNNECTION_SLACK) + " second(s) to establish connections.."
        time.sleep(CONNNECTION_SLACK)
        start_time = current_milli_time()
        startEvent.set()    # start executors
        time.sleep(EXECUTION_DURATION)
        stopEvent.set()     # stop executors
        wkResult = WorkloadResults(contactNodeIP=sys.argv[1])
        delta = current_milli_time() - start_time
        time.sleep(EXECUTION_SLACK)
        for t in executors:
            wr = None
            try:
                wr = t.get(None)
            except:
                print "--Caught it!!"
            if wr is not None:
                print "wr: " + str(wr.getCounter())
                wkResult.merge(wr)
        print " --> total: " + str(wkResult.getCounter())
        wkResult.setRuntime(delta)
        wkResult.printStatistics()

