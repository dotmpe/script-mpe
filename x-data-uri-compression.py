"""
:created: 2008-08-31

Try compressing more into an data: uri using a non-standardized method:
gzip before b64 encoding.

The data: URI scheme is defined in RFC 2397
"""
import os
from StringIO import StringIO
import base64
import gzip


data = open(__file__).read()
mediatype = 'application/python'
print len(data)

params  = 'base64'
data_b64 = base64.b64encode(data)
b64_data_uri = "data:%s;%s,%s" % (mediatype, params, data_b64)


params  = 'encoding=gz;base64'
"""
XXX: how to indicate gzip compressionin the the parameters?
RFC-2397 allows for a "charset=..." parameter.
RFC-2616 (HTTP) defines Accept-{Charset,Encoding} and Content-Encoding (the
charset is embedded into the Content-Type for response messages).
So analogous to this, encoding=gz is used here.
"""
gzf = gzip.GzipFile(__file__+'.gz', mode='ab')
gzf.write(data)
gzf.close()

data_gz = open(__file__+'.gz', mode='rb').read()
data_gz_b64 = base64.b64encode(data_gz)

b64_gz_data_uri = "data:%s;%s,%s" % (mediatype, params, data_gz_b64)


"""
     1    |  x-factor
----------x-----------
orig-data | compressed
"""
print b64_data_uri
print 'b64 x:', float(len(data_b64)) / len(data), '/1', len(data_b64), 'chars'
print
print b64_gz_data_uri
print 'gz x:', float(len(data_gz)) / len(data), '/1', len(data_gz)
print 'gz+base64 x:', float(len(data_gz_b64)) / len(data), '/1', len(data_gz_b64)
print

#print gzip.GzipFile(__file__+'.gz', mode='rb').read()
#print


data_gz = StringIO(base64.b64decode(data_gz_b64))
assert data == gzip.GzipFile(fileobj=data_gz).read()

os.unlink(__file__+'.gz')

"""
The results are good, while base64 encoded data gains about 33%,
gzipping loses more than half, b64-encoding the gz data then gains about 15%.

Base64 compression factor: ~0.75
Gz compression factor: ~2.4
Gz+Base64 compression factor: ~1.667

The big problem with this approach is ofcourse that this is a non-standard way
of handing data-uris. Browsers don't support this, and while they usually can
handle gzipped data, there is no Javascript API to access this functionality
(AFAIK). Mozilla could do it with XPCOM however.

Moreover, gzipping is already used as a compression method in HTTP message transfer,
in those cases, compressing the URI seems ugly and unnecessary.

Still, while encoding data into URI's, it would be nice to avoid the ~2000 char URI
limit just a bit longer. (this script: 82 lines, 2375 characters)
"""
