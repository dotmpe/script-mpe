

class AbstractTxtLineParser(object):
    fields = ()
    def __init__(self, raw, parser=None, **attrs):
        super(AbstractTxtLineParser, self).__init__()
        self._raw = t = raw.strip()
        self.attrs = attrs
        # Access to parent parser, if needed to bring session onto instance
        self.parser = parser
        # Parse fields
        for f in self.fields:
            t = self.run_field_parse(t, *f.split(':'))
        self.text = t
    def run_field_parse(self, text, method, attr=None):
        if not attr:
            attr = method
        text = getattr(self, 'parse_'+method)( text, attr )
        #if not getattr(self, attr, None):
        #    setattr(self, attr, None)
        return text
    def list_fields(self):
        return [
            f.split(':')[-1] for f in self.fields
        ]
    def todict(self):
        d = dict(
                attrs=self.attrs,
                text=self.text,
                _raw=self._raw
            )
        for f in self.fields:
            d[f] = getattr(self, f)
        return d
    def __str__(self):
        return self.text
    def __repr__(self):
        return "%s(%r)" % ( self.__class__.__name__, self.text )


class AbstractTxtLineParser(object):

    def parse_spans(self, text, attr):
        pass

    def parse_attrs(self, regex, text, attr):
        c = []
        cl = []
        for m in regex.finditer(t):
            if not m or not m.group(2): continue
            project = self.parser.handle_project(m.group(2))
            self.projects.append(project)
            cl.append(m.span())
        cl.sort()
        cl.reverse()
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        self.projects = c
        return t

    def parse_span(self, text, attr):
        pass

    def parse_attr(self, text, attr):
        pass





