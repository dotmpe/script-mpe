# PyXML 
from xml.parsers.xmlproc.dtdparser import DTDParser
# TODO: dtd parser
# XXX figure out how to get schema for given documen


class DTDHandler(object):
    def new_external_pe(self, name, pubid, sysid):
        print 'new_external_pe', name, pubid, sysid
    def new_parameter_entity(self, name, val):
        print 'new_parameter_entity', name, val
    def reset(self):
        pass
    def resolve_pe(self, name):
        pass
    def dtd_end(self):
        pass
    def dtd_start(self):
        pass
    def handle_comment(self, contents):
        pass
    def handle_pi(self, target, data):
        pass
    def new_attribute(self, elem, attr, a_type, a_decl, a_def):
        pass
    def new_element_type(self, elem_name, elem_cont):
        pass
    def new_external_entity(self, ent_name, pub_id, sys_id, ndata):
        pass
    def new_general_entity(self, name, val):
        pass
    def new_notation(self, name, pubid, sysid):
        pass


if __name__ == '__main__':
    import sys

    dh = DTDHandler()

    parser = DTDParser()
    parser.set_dtd_consumer(dh)
    print parser.feed(open('docutils.dtd').read())
    print parser
    print parser.flush()
    print parser

