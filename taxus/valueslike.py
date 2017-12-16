
class OptparseValues:

    hidden_attr = '__cmp__ __doc__ __init__ __module__ __repr__ __str__ '\
            +'_update _update_careful _update_loose ensure_value read_file '\
            +'read_module'

class OptparseValuesDictAdapter:

    def update(self, *args, **kwds):
        pass
