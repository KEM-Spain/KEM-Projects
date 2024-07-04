#!/usr/bin/env python
import concurrent.futures
import time

def threaded_func(arg):
    print('running threaded_func with arg:', arg)
    time.sleep(3)
    return 'completed'

with concurrent.futures.ThreadPoolExecutor() as executor:
    print("doing stuff 1")
    future = executor.submit(threaded_func, 'start')
    print("doing stuff 2")
    return_value = future.result()
    print("return value from threaded_func:",return_value)
    print("doing stuff 3")
    print("doing stuff 4")
