#!/usr/bin/env python
"""scrape - a webscraper inspired by earlier projects

while I'm rewriting libcmd taxus, I'd like to get some web content into the
database so dressed up something with BeautifulSoup.

"""
import urllib

from BeautifulSoup import BeautifulSoup
from zope.interface import Interface, implements

import log
import lib
import libcmd
from txs import TaxusFe
from taxus import iface


class Scrapers(object):
    implements(iface.IScraperRegistry)
    def __init__(self):
        self.scrapers = {}
    def register(self, url):
        def decorator(func):
            if func.__name__ not in self.scrapers:
                log.debug('scraper reg %r %r', url, func)
                self.scrapers[func.__name__] = func, url
        return decorator
    def __getitem__(self, name):
        return self.scrapers[name]
    def __iter__(self):
        return iter(self.scrapers)
    def __len__(self):
        return len(list(iter(self.scrapers)))
    def __str__(self):
        return "%i scrapers" % len(self)
    def __repr__(self):
        return "<%s at %s with %i scrapers>" % (lib.cn(self), hex(id(self)), len(self))


class Scraper(TaxusFe):

    DEFAULT_ACTION = 'scrape'
    DEPENDS = dict(
            fetch = ['cmd_options'],
            scrape = ['fetch'],
            list_scrapers = ['cmd_options']
        )
    # XXX: add listype DEPENDS to SimpleCommand
    #DEPENDS = [ 'cmd_options', 'fetch', 'scrape' ]
  
    @classmethod
    def get_optspec(Klass, inherit):
        return (
                (('--list-scrapers',), libcmd.cmddict()),
            )

    def __init__(self):
        super(Scraper, self).__init__()
        self.scrapers = Scrapers()
        iface.gsm.registerUtility( self.scrapers, iface.IScraperRegistry )
        # XXX only one pre-loaded set of scrapers
        import scrape_

    def get_scraper(self, ref):
        if not ref:
            log.err("What do you want?")
        if '-' in ref:
            ref = ref.replace('-', '_')
        assert ref in self.scrapers
        return self.scrapers[ref]

    def fetch(self, name):
        handler, href = self.get_scraper(name)
        fl = urllib.urlopen(href)
        yield dict( name=name, href=href, func=handler )
        soup = BeautifulSoup( fl )
        yield dict( soup=soup )

    def scrape(self, func, soup):
        func(soup)

    def list_scrapers(self, prog):
        scrapers = self.scrapers
        for s in scrapers:
            print s


if __name__ == '__main__':

    Scraper.main()

