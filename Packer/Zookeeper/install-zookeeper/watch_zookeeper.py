from kazoo.client import KazooClient
import logging

logging.basicConfig()


zk = KazooClient(hosts='localhost:2181')
zk.start()

@zk.ChildrenWatch("/my/favorite/node")
def watch_children(children):
    print("Children are now: %s" % children)
    # Above function called immediately, and from then on