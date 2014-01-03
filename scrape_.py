"""
Submodule for scraper, requires IScraperRegistry.
"""
from taxus.iface import gsm, IScraperRegistry


reg = gsm.getUtility(IScraperRegistry)

@reg.register('http://www.dd-wrt.com/wiki/index.php/Supported_Devices')
def ddwrt_hardware_support(soup):
    pass

@reg.register('http://wiki.openwrt.org/toh/start')
def openwrt_hardware_support(soup):
    pass


