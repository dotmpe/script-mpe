import sys

import re

TSV_HEAD1_RE = re.compile(r'([A-Z_][A-Z0-9_-]+,\ *)*[A-Z_][A-Z0-9_-]+', re.I)
TSV_HEAD2_RE = re.compile(r'([A-Z_][A-Z0-9_-]+\ *)*[A-Z_][A-Z0-9_-]+', re.I)
TSV_HEADPREF_RE = re.compile(r'(.*(COL(UMN)?S|FIELDS: )).*', re.I)
TSV_EXTCOL_RE = re.compile(r'([A-Z_][A-Z0-9_]+):(.*)', re.I)


class TSVFile:
  """
  Context for reading tab-separated data from disk. See TSVRecords
  """
  def __init__(self, tabfile):
    self.tabfile = tabfile

  def read(self, **list_params):
    lines = open(self.tabfile).readlines()

    prolog = []
    while len(lines) > 0 and lines[0][0] == '#':
      prolog.append(lines[0].strip('# '))
      del lines[0]
    if not len(lines):
      print('No data in table!', file=sys.stderr)
      return False

    if not list_params['field_ids']:
      # Look for line with declaration of field keys
      fields = []
      for pl in prolog:
        m = TSV_HEADPREF_RE.match(pl)
        if m:
          g1 = m.group(1)
          pl = pl[len(g1):].strip()

        m = TSV_HEAD1_RE.match(pl)
        if m:
          fields = [ f.strip() for f in pl.split(',') ]
          break
        else:
          m = TSV_HEAD2_RE.match(pl)
          if m:
            fields = pl.split(' ')
          break

      if not len(fields):
        print('Warning: no field keys, index operations only', file=sys.stderr)
    else:
      fields = list(list_params['field_ids'])

    if fields[-1].endswith('...'):
      fields[-1] = fields[-1][:-3]
      list_params['ext'] = len(fields)-1

    # TODO: read modeline as well, and change tab or line sep

    #epilog = []

    print('Fields:', ", ".join(fields), file=sys.stderr)
    records = [ l.strip('\n\r').split('\t') for l in lines
        if len(l) > 0 and l[0] not in ('#', ' ') ]
    list_params['field_ids'] = fields
    return TSVRecords(**list_params).parse(records)

  def commit(self, records, **list_params):
    pass

  # Static
  def read_file(tabfile, **list_params):
    return TSVFile(tabfile).read(**list_params)

  def commit_file(tabfile, records, **list_params):
    return TSVFile(tabfile).commit(records, **list_params)


class TSVRecords:
  """
  Model for parsed tab-separated fields (TSVRecord).
  """
  def __init__(self, records=[], field_ids=[], index_fields=[], ext=False):
    self.records = records
    self.field_ids = field_ids
    self.index_fields = index_fields
    self.ext = ext
    self.init()
    # Track changes to commit
    self._deleted = []
    self._updated = []
    self._new = []

  def init(self):
    # Track column index, data lookups, records marked closed and extension
    # columns
    self._key = {}
    self._index = {}
    self._closed = []
    self._ext = []
    # Populate indices
    if len(self.records):
      self.pre_parse()

  def parse(self, data):
    self.records.extend(data)
    self.init()
    return self

  def pre_parse(self):
    """
    Parse '-' to None, track records marked closed and build indices.
    """

    index = False
    if len(self.field_ids):
      if len(self.index_fields):
        index = True
        for fid in self.index_fields:
          self._index[fid] = {}
          if fid in self.field_ids:
            self._key[fid] = self.field_ids.index(fid)

    for i, r in enumerate(self.records):
      for fi, f in enumerate(r):
        if not f.isdigit():
          r[fi] = f.replace('\\t', '\t').replace('\\n', '\n')
      if r[0][0] == 'x':
        self._closed.add(i)
      while '-' in r:
        fi = r.index('-')
        r[fi] = None
      if self.ext and len(r) > self.ext:
        #if not isinstance(r[self.ext], tuple):
        extl = []
        for ci, f in enumerate(r[self.ext:]):
          m = TSV_EXTCOL_RE.match(f)
          assert m, "Failed matching extcol value %r: '%s'" % (f, f)
          field_id, field_value = m.group(1), m.group(2)
          if field_id not in self._ext:
            self._ext.append(field_id)
          fi = self._ext.index(field_id)
          extl.append(( fi, field_value ))
        r = r[:self.ext] + extl
        self.records[i] = r
      if index:
        for fid in self.index_fields:
          field_value = None
          if fid in self._key:
            ii = self._key[fid]
            field_value = r[ii]
          else:
            ei = self._ext.index(fid)
            for ef in r[self.ext:]:
              if ef[0] == ei:
                field_value = ef[1]
                break
          if field_value:
            self._index[fid][field_value] = i

  def __iter__(self):
    for i, record in enumerate(self.records):
      if i in self._closed: continue
      yield TSVRecord(record, self)

  def __str__(self):
    l = []
    for i, record in enumerate(self.records):
      l.append(str(TSVRecord(record, self)))
    return "\n".join(l)

  def add(self, record):
    if isinstance(record, list):
      fields = record
    else:
      try:
        fields = list(iter(record))
      except TypeError:
        assert len(self.field_ids), "Cannot pick fields without col def"
        fields = []
        for field_id in self.field_ids:
          fields.append(getattr(record, field_id))
    self.records.append(fields)

  def closed(self, field_id, field_value):
    assert field_id in self._index, "No index for %r" % field_id
    ri = self._index[field_id][field_value]
    return ri in self._closed

  def get(self, field_id, field_value, default_value=None, default=True):
    if not len(self.field_ids) or field_id not in self.field_ids:
      raise Exception('No columns or no such field id found %r' % field_id)
    if default:
      if field_value not in self._index[field_id]:
        return default_value
    ri = self._index[field_id][field_value]
    return TSVRecord(self.records[ri], self)

  def col(self, field_id):
    ii = self._key[field_id]
    for i, r in enumerate(self.records):
      yield r[ii]

  def prefix(self, field_id, field_key, value):
    ri = self._index[field_id][field_key]
    self.records[ri][0] = value+self.records[ri][0]

class TSVRecord:
  """
  Model for fields of TSVRecords row.
  """
  def __init__(self, row, ctx):
    self.data = row
    self.tab = ctx

  def __iter__(self):
    return iter(self.data)

  def __eq__(self, other):
    #assert set(other.tab.field_ids) == set(self.tab.field_ids)
    if isinstance(other, type(None)):
      return False
    for fi, field_id in enumerate(self.tab.field_ids):
      if fi == self.tab.ext:
        v = getattr(other, field_id)
        matched = []
        for ef, ev in self[field_id]:
          ov = getattr(v, ef)
          if isinstance(ov, list) and ev in ov:
            matched.append((ef, ev))
          elif ev == ov:
            matched.append((ef, ev))
          else:
            #print('Unmatched %r != %r' % (ev, ov))
            return False
        for ot in v:
          if ot not in matched:
            #print('Missing', ot, v, self[field_id])
            return False
      else:
        v = getattr(other, field_id)
        if v and self[field_id] != v:
          #print("%r != %r" % ( self[field_id], getattr(other, field_id) ))
          return False

  def __getitem__(self, key):
    if self.tab.ext and self.tab.ext == self.tab.field_ids.index(key):
      ext = []
      for fi, fv in self.data[self.tab.ext:]:
        ext.append((self.tab._ext[fi], fv))
      return ext
    elif key in self.tab.field_ids:
      idx = self.tab.field_ids.index(key)
      return self.data[idx]
    elif key in self.tab._ext:
      idx = len(self.tab.field_ids) + self.tab._ext.index(key)
      return self.data[idx][1]
    else:
      raise KeyError(key)

  def __str__(self):
    l = []
    for c, d in enumerate(self.data):
      if c >= self.tab.ext:
        f = self.tab._ext[d[0]]
        l.append( "%s:%s" % (f, tsv_str(d[1])) )
      else:
        if not d: d = '-'
        l.append( tsv_str(d) )
    return '\t'.join(l)

def tsv_str(s):
  return str(s).replace('\t', '\\t').replace('\n', '\\n')

#
