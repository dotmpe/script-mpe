import os, types, ConfigParser


config_paths = (
    ['','.'], 
    ['~', '.'],
    ['/etc/', ]
)


def get_config(name):
    """
    Yield all existing config paths. See config_paths.
    """

    paths = list(config_paths)

    for dir in paths:
        if dir and dir[-1] == '.':
            dir[-1] += name
        else:
            dir.append(name)
        path = os.path.expanduser(os.path.join(*dir))
        if os.path.exists(path):
            yield path


class Value(object):    

    def __init__(self, section, name):
        self.section = section
        self.name = name

    def __get__(self, values, type=types.StringType):
        if not values:
            return self
        if type == 'str':
            return values[self.section +'.'+ name]
        elif type == 'size':
            return values[self.section +'.'+ name].getsize()

    def __set__(self, values, value):
        raise AttributeError

    def __delete__(self, values):
        raise AttributeError


class Values(object):

    def __init__(self, parentvalues=None, section='default'):
        if parentvalues:
            self.parent = parentvalues
            self.section = section

#            for name in parentvalues.options(section):
#                self._init_option(name)
#

    def _init_option(self, name):
        assert '.' not in name
        self[name] = Value(self.section, name)

    def __setitem__(self, name, value):
        setattr(type(self), name, Values(self, name))

    def __getitem__(self, name):
        mod = self
        if '.' in name:
            path = name.split('.')
            while path:
                mod = getattr(self, path.pop(0))
                if len(path)==1:
                    name = path.pop(0)
        if not hasattr(self, name):
            raise AttributeError, name
        else:
            return getattr(self, name)
                    
    def __getattr__(self, section):
        return self[section]


    def __get__(self, values, type='str'):
        print 'Values.__get__', values
        if not values:
            return self
        if type == 'str':
            return values.parser.get(self.section, name)
        elif type == 'size':
            return values.getsize(self.section, name)

#    def __repr__(self):
#        return "Values {\n  %s\n}" % '\n  '.join([
#            "%s: %s" % (c, getattr(self, c)) for c in
#                self.parser.options(self.section)])

    def get(self, default=None):
        return self.parser.get(self.section, name, default).lower()

    def getsec(self, default=None):
        vstr = self.parser.get(self.section, self.name, default).lower()\
            .replace('minutes', 'min')
        if 'min' in vstr:
            return int(vstr.replace('min', '').strip())*60
        elif 'hours' in vstr:
            return int(vstr.replace('hours', '').strip())*60*60
        elif 'days' in vstr:
            return int(vstr.replace('days', '').strip())*24*60*60
        elif 'weeks' in vstr:
            return int(vstr.replace('weeks', '').strip())*7*24*60*60

    def getsize(self, default=None):
        """
        Translate human-readable byte-size notation to classical power-of-two
        amount. Ie. 1 KB = 1024 bytes.
        """
        vstr = self.parser.get(self.section, name, default).lower()\
                .replace('kilobyte','kb').replace('megabyte','mb')\
                .replace('gigabyte','gb').replace('terrabyte','tb')\
                .replace('petabyte','pb')
        if 'kb' in vstr:
            return int(vstr.replace('kb', '').strip())*1024
        elif 'mb' in vstr:
            return int(vstr.replace('mb', '').strip())*(1024**2)
        elif 'gb' in vstr:
            return int(vstr.replace('gb', '').strip())*(1024**3)
        elif 'tb' in vstr:
            return int(vstr.replace('tb', '').strip())*(1024**4)
        elif 'pb' in vstr:
            return int(vstr.replace('pb', '').strip())*(1024**5)

    def getint(self, default=None):
        return self.parser.getint(self.section, name, default).lower()

    def getlist(self, default=None):
        return [ item.strip() for item in self.parser.get(self.section,
            self.name, default).split(',') ]


class Settings(Values):

    """
    Attribute access for configuration files/values.
    
    Requested values are lazily retrieved from configparser struct.
    """

    def __init__(self, configparser=None):
        if configparser:
            self.parser = configparser
            for c in configparser.sections():
                self.add_section(c)
        else:
            self.parser = ConfigParser.ConfigParser()

#     def __setitem__(self, section):
        #        if section in self.parser.sections():
            

    def _init_section(self, section):
        for o in self.parser.options(c):
            self._init_option()

    def add_section(self, section, **defaults):
        self.__dict__[section] = Values(self.parser, section)

    def __str__(self):
        return "Settings {\n  %s\n}" % '\n  '.join([
            "%s: %s" % (c, getattr(self, c)) for c in
                self.parser.sections()])

def ini(*files):
    cp = ConfigParser.ConfigParser()
    cp.read(*files)
    return Settings(cp)


if __name__ == '__main__':

    print list(get_config('confparse.test.ini'))
    dlcsrc = get_config('dlcs-rc').next()
    print 'dlcsrc', dlcsrc

    dlcs_settings = ini(dlcsrc)

    print 'dlcs_settings', dlcs_settings

    print dlcs_settings.dlcs
    print dlcs_settings.dlcs.username
#    print dlcs_settings.dlcs.username.get()
    print dir(dlcs_settings.dlcs.username)


